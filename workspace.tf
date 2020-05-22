resource "azurerm_databricks_workspace" "databricksWokspace" {
  name                = "${var.suffix}${var.workspaceName}"
  resource_group_name = azurerm_resource_group.genericRG.name
  location            = azurerm_resource_group.genericRG.location
  sku                 = "trial"

  custom_parameters {
    virtual_network_id  = azurerm_virtual_network.genericVNet.id
    private_subnet_name = azurerm_subnet.dbSubnets["privateDB"].name
    public_subnet_name  = azurerm_subnet.dbSubnets["publicDB"].name
    no_public_ip        = false
  }

  tags = var.tags
}
