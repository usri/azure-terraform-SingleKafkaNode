resource "azurerm_public_ip" "kafkaPublicIP" {
  name                = "${var.suffix}-KafkaPublicIP"
  location            = azurerm_resource_group.genericRG.location
  resource_group_name = azurerm_resource_group.genericRG.name
  allocation_method   = "Static"

  tags = var.tags
}

resource "azurerm_network_interface" "kafkaNIC" {
  name                      = "${var.suffix}-KafkaNIC"
  location                  = azurerm_resource_group.genericRG.location
  resource_group_name       = azurerm_resource_group.genericRG.name
  network_security_group_id = azurerm_network_security_group.genericNSG.id

  ip_configuration {
    name                          = "kafkaServer"
    subnet_id                     = azurerm_subnet.subnets["headnodes"].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.kafkaPublicIP.id
  }

  tags = var.tags
}

resource "azurerm_virtual_machine" "kafkaServer" {
  name                  = "${var.suffix}-KafkaServer"
  location              = azurerm_resource_group.genericRG.location
  resource_group_name   = azurerm_resource_group.genericRG.name
  network_interface_ids = ["${azurerm_network_interface.kafkaNIC.id}"]
  vm_size               = "Standard_DS3_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "7-RAW-CI"
    version   = "latest"
  }
  storage_os_disk {
    name              = "${var.suffix}-kafkaServerosDisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "kafkaServer"
    admin_username = var.vmUserName
    custom_data    = <<-EOF
    #cloud-config
    package_upgrade: true
    packages:
      - httpd
      - java-1.8.0-openjdk-devel
      - tmux
      - git
    write_files:
      - content: <!doctype html><html><body><h1>Hello kafkaAdmin 2019 from Azure!</h1></body></html>
        path: /var/www/html/index.html
    runcmd:
      - [ systemctl, enable, httpd.service ]
      - [ systemctl, start, httpd.service ]
    EOF

  }
  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/${var.vmUserName}/.ssh/authorized_keys"
      key_data = file(var.sshKeyPath)
    }
  }
  tags = var.tags
}
