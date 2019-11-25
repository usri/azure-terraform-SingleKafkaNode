terraform {
  backend "remote" {
    organization = "zambrana"

    workspaces {
      name = "work-BTS-SWIM-DataIngestion-SingleNode"
    }
  }
  required_version = ">= 0.12.12"
}

provider "azurerm" {
  version = "=1.36.1"
}
resource "azurerm_resource_group" "genericRG" {
  name     = "${var.suffix}${var.rgName}"
  location = var.location
  tags     = var.tags
}
