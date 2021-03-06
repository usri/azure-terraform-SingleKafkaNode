output "generic_RG" {
  value = azurerm_resource_group.genericRG.name
}

output "kafkaPublicIP" {
  value = azurerm_public_ip.kafkaPublicIP.ip_address
}

output "kafkaPrivateIP" {
  value = azurerm_network_interface.kafkaNIC.private_ip_address
}

output "sshAccess" {
  description = "Command to ssh into the VM."
  value       = <<SSHCONFIG
  ssh ${var.vmUserName}@${azurerm_public_ip.kafkaPublicIP.ip_address} -i ${trimsuffix(var.sshKeyPath, ".pub")}
  SSHCONFIG
}

output "storageAccountID" {
  description = "The storage account Resource ID."
  value       = azurerm_storage_account.genericSA.id
}

output "storageAccountKey" {
  description = " Access Key to access the SA."
  value       = azurerm_storage_account.genericSA.primary_access_key
}

output "adlsFyleSytemID" {
  value = azurerm_storage_data_lake_gen2_filesystem.ADLSFileSystemTFMS.id
}

output "vNetID" {
  value = azurerm_virtual_network.genericVNet.id
}

output "subnets" {
  value = {
    for subnet in azurerm_subnet.subnets :
    subnet.name => subnet.address_prefix
  }
}

output "dataBricksSubnets" {
  value = {
    for subnet in azurerm_subnet.dbSubnets :
    subnet.name => subnet.address_prefix
  }
}
