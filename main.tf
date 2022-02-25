provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "name" {
  name     = var.name
  location = var.location
}