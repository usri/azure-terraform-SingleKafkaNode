resource "azurerm_storage_account" "genericSA" {
  name                     = var.storageAccountName
  resource_group_name      = azurerm_resource_group.genericRG.name
  location                 = azurerm_resource_group.genericRG.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "GRS"
  # enable_advanced_threat_protection = true

  /* TODO create proper network rules for all subnets
  network_rules {
    default_action             = "Allow"
    ip_rules                   = ["138.88.132.45"]
    virtual_network_subnet_ids = ["${azurerm_subnet.frontEndLayer.id}", "${azurerm_subnet.appLayer.id}", "${azurerm_subnet.backEndLayer.id}"]
  }
*/
  tags = var.tags
}

resource "azurerm_storage_container" "container" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.genericSA.name
  container_access_type = "private"
}

resource "azurerm_storage_account" "ADLS" {
  name                     = "${var.storageAccountName}adsl"
  resource_group_name      = azurerm_resource_group.genericRG.name
  location                 = azurerm_resource_group.genericRG.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = "true"

  tags = var.tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "ADLSFileSystemTFMS" {
  name               = "tfms"
  storage_account_id = azurerm_storage_account.ADLS.id
}
