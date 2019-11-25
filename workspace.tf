resource "azurerm_template_deployment" "databricksWokspace" {
  name                = "${var.suffix}${var.workspaceName}"
  resource_group_name = azurerm_resource_group.genericRG.name

  template_body = file("workspace.json")

  # these key-value pairs are passed into the ARM Template's `parameters` block
  parameters = {
    "workspaceName"     = "${var.workspaceName}",
    "vnetName"          = "${azurerm_virtual_network.genericVNet.name}",
    "privateSubnetName" = "${azurerm_subnet.dbSubnets["privateDB"].name}",
    "publicSubnetName"  = "${azurerm_subnet.dbSubnets["publicDB"].name}"
  }

  deployment_mode = "Incremental"
}
