# Single Kafka Node

It creates the following resources:

* A new Resource Group
* A RedHat VM
* A VNet
* A Storage Account with a container so it can be mounted in DataBricks.
* 4 subnets to host the Single Kafka VM, but in mind to create a cluster in the future.
* 2 subnets public and private dedicated to DataBricks Cluster.
* A Network Security Group with SSH, HTTP and RDP access.
* A Network Security Group dedicated to the DataBricks Cluster.
* A DataBricks Workspace with VNet injection.

## Project Structure

This project has the following files which make them easy to reuse, add or remove.

```ssh
.
├── LICENSE
├── README.md
├── main.tf
├── networking.tf
├── outputs.tf
├── security.tf
├── storage.tf
├── variables.tf
├── vm.tf
└── workspace.tf
```

Most common parameters are exposed as variables in _`variables.tf`_

## Pre-requisites

It is assumed that you have azure CLI and Terraform installed and configured.
More information on this topic [here](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/terraform-install-configure). I recommend using a Service Principal with a certificate.

### versions

This terraform script has been tested using the following versions:

* Terraform =>0.12.24
* Azure provider 2.10.0
* Azure CLI 2.6.0

## VM Authentication

It uses key based authentication and it assumes you already have a key. You can configure the path using the _sshKeyPath_ variable in _`variables.tf`_ You can create one using this command:

```ssh
ssh-keygen -t rsa -b 4096 -m PEM -C vm@mydomain.com -f ~/.ssh/vm_ssh
```

## Usage

Just run these commands to initialize terraform, get a plan and approve it to apply it.

```ssh
terraform fmt
terraform init
terraform validate
terraform plan
terraform apply
```

I also recommend using a remote state instead of a local one. You can change this configuration in _`main.tf`_
You can create a free Terraform Cloud account [here](https://app.terraform.io).

The terraform script installs the following extra packages on the VM:

* java-1.8.0-openjdk-devel (**Required**)
* tmux (Optional)
* git (**Required**)

Optional: It is recommended to install `jq` to parse JSON requests in the future

```ssh
wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
chmod +x ./jq
sudo cp jq /usr/bin
```

> [!IMPORTANT]
> Kafka and the Solace Connector do need Java 8 in order to run and Git is needed in order to clone and build the Solace connector. This terraform script takes care of these requirements, but if you are going to configure Kafka on an existing VM, please make sure Java and Git are installed.

## Kafka Installation and Configuration

ssh into the new VM once it is ready

```ssh
ssh kafkaAdmin@IP -i {{PATH/TO/SSHKEY}}
```

_`kafkaAdmin`_ is the user name that can be customized using the variable _`vmUserName`_ in _`variables.tf`_ file. Also remember to whitelist your source IP or IPs in the variable _`sourceIPs`_. Otherwise you might not be able to ssh into the VM.

Get Apache Kafka version 2.3.0

```ssh
sudo wget https://www-eu.apache.org/dist/kafka/2.3.0/kafka_2.12-2.3.0.tgz -O /opt/kafka_2.12-2.3.0.tgz
cd /opt
sudo tar -xvf kafka_2.12-2.3.0.tgz
sudo ln -s /opt/kafka_2.12-2.3.0 /opt/kafka
sudo chown -R kafkaAdmin:kafkaAdmin /opt/kafka*
sudo rm *.tgz
cd
```

We create the init file for Zookeeper service in */etc/systemd/system/zookeeper.service* with the following content:

```ssh
sudo vi /etc/systemd/system/zookeeper.service
[Unit]
Description=zookeeper
After=syslog.target network.target

[Service]
Type=simple

User=kafkaAdmin
Group=kafkaAdmin

ExecStart=/opt/kafka/bin/zookeeper-server-start.sh /opt/kafka/config/zookeeper.properties
ExecStop=/opt/kafka/bin/zookeeper-server-stop.sh

[Install]
WantedBy=multi-user.target
```

The same applies to the next init file for Kafka, */etc/systemd/system/kafka.service*, that contains the following lines of configuration:

```ssh
sudo vi /etc/systemd/system/kafka.service
[Unit]
Description=Apache Kafka
Requires=zookeeper.service
After=zookeeper.service

[Service]
Type=simple

User=kafkaAdmin
Group=kafkaAdmin

ExecStart=/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties
ExecStop=/opt/kafka/bin/kafka-server-stop.sh

[Install]
WantedBy=multi-user.target
```

We need to reload *systemd* to get it read the new init files:

```ssh
sudo systemctl daemon-reload
```

Now we can start our new services (in this order):

```ssh
sudo systemctl start zookeeper
sudo systemctl start kafka
```

If all goes well, *systemd* should report running state on both service's status

```ssh
sudo systemctl status zookeeper.service
sudo systemctl status kafka.service
```

If needed, we can enable automatic start on boot for both services

```ssh
sudo systemctl enable zookeeper.service
sudo systemctl enable kafka.service
```

Open Kafka port in firewall. 9092 is the default port.

```ssh
sudo firewall-cmd --zone=public --add-port=9092/tcp --permanent
sudo firewall-cmd --reload
```

Add kafka tools to path

```ssh
export KAFKA_HOME=/opt/kafka
export PATH=$KAFKA_HOME/bin:$PATH
```

## Get Solace Connector and its Dependencies

You can get the current Solace Connector version which is 2.0.1 and its dependencies using the following command

```ssh
wget https://solaceproducts.github.io/pubsubplus-connector-kafka-source/downloads/pubsubplus-connector-kafka-source-2.0.1.zip
```

unpack and copy the connector and its dependencies to ~/kafka_2.12-2.3.0/libs/

```ssh
unzip pubsubplus-connector-kafka-source-2.0.1.zip
cp -v pubsubplus-connector-kafka-source-2.0.1/lib/*.jar /opt/kafka/libs/
```

This new version packages everything together so you do not need to build and get the dependencies from maven or somewhere else.
In case you want build it yourself you can find more information on their [README](https://github.com/SolaceProducts/pubsubplus-connector-kafka-source).

## Manage Apache Kafka topics

Create a topic

```ssh
# stdds
kafka-topics.sh --create --replication-factor 3 --partitions 1 --topic stdds --zookeeper localhost:9092

#tfms
kafka-topics.sh --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 1 --topic tfms
```

List topics

```ssh
kafka-topics.sh --list --bootstrap-server localhost:9092
```

Delete topics

```ssh
# stdds
kafka-topics.sh --delete --topic stdds --bootstrap-server localhost:9092

# tfms
kafka-topics.sh --delete --topic tfms --bootstrap-server localhost:9092
```

Describe topics

```ssh
# stdds
kafka-topics.sh --describe --topic tfms --bootstrap-server localhost:9092

# tfms
kafka-topics.sh --describe --topic tfms --bootstrap-server localhost:9092
```

## Configure Solace Connector to connect to SWIM Data Source

Update `/opt/kafka/config/connect-standalone.properties`
set:

```vi
bootstrap.servers= localhost:9092

key.converter=org.apache.kafka.connect.storage.StringConverter
value.converter=org.apache.kafka.connect.storage.StringConverter
```

```ssh
vi /opt/kafka/config/connect-standalone.properties
```

This is the final content of the file

```ssh
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# These are defaults. This file just demonstrates how to override some settings.
bootstrap.servers=localhost:9092

# The converters specify the format of data in Kafka and how to translate it into Connect data. Every Connect user will
# need to configure these based on the format they want their data in when loaded from or stored into Kafka
key.converter=org.apache.kafka.connect.storage.StringConverter
value.converter=org.apache.kafka.connect.storage.StringConverter
# Converter-specific settings can be passed in by prefixing the Converter's setting with the converter we want to apply
# it to
key.converter.schemas.enable=true
value.converter.schemas.enable=true

offset.storage.file.filename=/tmp/connect.offsets
# Flush much faster than normal, which is useful for testing/debugging
offset.flush.interval.ms=10000

# Set to a list of filesystem paths separated by commas (,) to enable class loading isolation for plugins
# (connectors, converters, transformations). The list should consist of top level directories that include
# any combination of:
# a) directories immediately containing jars with plugins and their dependencies
# b) uber-jars with plugins and their dependencies
# c) directories immediately containing the package directory structure of classes of plugins and their dependencies
# Note: symlinks will be followed to discover dependencies or plugins.
# Examples:
# plugin.path=/usr/local/share/java,/usr/local/share/kafka/plugins,/opt/connectors,
#plugin.path=
```

Create stdds and/or tfms config connectors

```ssh
# stdds
sudo vi /opt/kafka/config/connect-solace-stdds-source.properties

# tfms
sudo vi /opt/kafka/config/connect-solace-tfms-source.properties
```

> These values are mandatory and you need provide them:

```vi
name
kafka.topic
sol.host
sol.username
sol.password
sol.vpn_name
sol.queue
```

The values that need to be replaced are between {{ }}.

This is the final content of the file

```ssh
# PubSub+ Kafka Source Connector parameters
# GitHub project https://github.com/SolaceProducts/pubsubplus-connector-kafka-source
#######################################################################################

# Kafka connect params
# Refer to https://kafka.apache.org/documentation/#connect_configuring
name={{ connectorName }}
connector.class=com.solace.connector.kafka.connect.source.SolaceSourceConnector
tasks.max=1
value.converter=org.apache.kafka.connect.converters.ByteArrayConverter
key.converter=org.apache.kafka.connect.storage.StringConverter

# Destination Kafka topic the connector will write to
kafka.topic={{ kafkaTopic }}

# PubSub+ connection information
sol.host={{ SWIMEndpoint }}:{{ SWIMEndpointPort }}
sol.username={{ SWIMUserNaMe }}
sol.password={{ Password }}
sol.vpn_name={{ SWIMVPN }}

# Comma separated list of PubSub+ topics to subscribe to
# If tasks.max>1, use shared subscriptions otherwise each task's subscription will receive same message
# Refer to https://docs.solace.com/PubSub-Basics/Direct-Messages.htm#Shared
# example shared subscription to "topic": "#share/group1/topic"
sol.topics=sourcetest

# PubSub+ queue name to consume from, must exist on event broker
sol.queue={{ SWIMQueue }}

# PubSub+ Kafka Source connector message processor
# Refer to https://github.com/SolaceProducts/pubsubplus-connector-kafka-source
sol.message_processor_class=com.solace.connector.kafka.connect.source.msgprocessors.SolaceSampleKeyedMessageProcessor

# When using SolaceSampleKeyedMessageProcessor, defines which part of a
# PubSub+ message shall be converted to a Kafka record key
# Allowable values include: NONE, DESTINATION, CORRELATION_ID, CORRELATION_ID_AS_BYTES
#sol.kafka_message_key=NONE

# Connector TLS session to PubSub+ message broker properties
# Specify if required when using TLS / Client certificate authentication
# May require setup of keystore and truststore on each host where the connector is deployed
# Refer to https://docs.solace.com/Overviews/TLS-SSL-Message-Encryption-Overview.htm
# and https://docs.solace.com/Overviews/Client-Authentication-Overview.htm#Client-Certificate
#sol.authentication_scheme=
#sol.ssl_connection_downgrade_to=
#sol.ssl_excluded_protocols=
#sol.ssl_cipher_suites=
sol.ssl_validate_certificate=false
#sol.ssl_validate_certicate_date=
#sol.ssl_trust_store=
#sol.ssl_trust_store_password=
#sol.ssl_trust_store_format=
#sol.ssl_trusted_common_name_list=
#sol.ssl_key_store=
#sol.ssl_key_store_password=
#sol.ssl_key_store_format=
#sol.ssl_key_store_normalized_format=
#sol.ssl_private_key_alias=
#sol.ssl_private_key_password=

# Connector Kerberos authentication of PubSub+ message broker properties
# Specify if required when using Kerberos authentication
# Refer to https://docs.solace.com/Overviews/Client-Authentication-Overview.htm#Kerberos
# Example:
#sol.authentication_scheme=AUTHENTICATION_SCHEME_GSS_KRB
#sol.kerberos.login.conf=/opt/kerberos/login.conf
#sol.kerberos.krb5.conf=/opt/kerberos/krb5.conf
#sol.krb_service_name=

# Solace Java properties to tune for creating a channel connection
# Leave at default unless required
# Look up meaning at https://docs.solace.com/API-Developer-Online-Ref-Documentation/java/com/solacesystems/jcsmp/JCSMPChannelProperties.html
#sol.channel_properties.connect_timout_in_millis=
#sol.channel_properties.read_timeout_in_millis=
#sol.channel_properties.connect_retries=
#sol.channel_properties.reconnect_retries=
#sol.channnel_properties.connect_retries_per_host=
#sol.channel_properties.reconnect_retry_wait_in_millis=
#sol.channel_properties.keep_alive_interval_in_millis=
#sol.channel_properties.keep_alive_limit=
#sol.channel_properties.send_buffer=
#sol.channel_properties.receive_buffer=
#sol.channel_properties.tcp_no_delay=
#sol.channel_properties.compression_level=

# Solace Java tuning properties
# Leave at default unless required
# Look up meaning at https://docs.solace.com/API-Developer-Online-Ref-Documentation/java/com/solacesystems/jcsmp/JCSMPProperties.html
#sol.message_ack_mode=
#sol.session_name=
#sol.localhost=
#sol.client_name=
#sol.generate_sender_id=
#sol.generate_rcv_timestamps=
#sol.generate_send_timestamps=
#sol.generate_sequence_numbers=
#sol.calculate_message_expiration=
#sol.reapply_subscriptions=
#sol.pub_multi_thread=
#sol.pub_use_immediate_direct_pub=
#sol.message_callback_on_reactor=
#sol.ignore_duplicate_subscription_error=
#sol.ignore_subscription_not_found_error=
#sol.no_local=
#sol.ack_event_mode=
#sol.sub_ack_window_size=
#sol.pub_ack_window_size=
#sol.sub_ack_time=
#sol.pub_ack_time=
#sol.sub_ack_window_threshold=
#sol.max_resends=
#sol.gd_reconnect_fail_action=
#sol.susbcriber_local_priority=
#sol.susbcriber_network_priority=
#sol.subscriber_dto_override=


```

restart kafka service

```ssh
sudo systemctl restart kafka.service
```

Start standalone connection

```ssh
# stdds
connect-standalone.sh /opt/kafka/config/connect-standalone.properties /opt/kafka/config/connect-solace-stdds-source.properties

# tfms
connect-standalone.sh /opt/kafka/config/connect-standalone.properties /opt/kafka/config/connect-solace-tfms-source.properties
```

Check incoming messages. This command will display all the messages from the beginning and might take some time if you have lots of messages.

```ssh
# stdds
kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic stdds --from-beginning

# tfms
kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic tfms --from-beginning
```

If you just want to check specific messages and not display all of them, you can use the `--max-messages` option.
The following comand will display the first message.

```ssh
# stdds
kafka-console-consumer.sh --from-beginning --max-messages 1 --topic stdds --bootstrap-server localhost:9092

# tfms
kafka-console-consumer.sh --from-beginning --max-messages 1 --topic tfms --bootstrap-server localhost:9092
```

if you want to see all available options, just run the `kafka-console-consumer.sh` without any options

```ssh
kafka-console-consumer.sh
```

## Clean resources

It will destroy everything that was created.

```ssh
terraform destroy --force
```

## Caution

Be aware that by running this script your account might get billed.

## Authors

* Marcelo Zambrana
