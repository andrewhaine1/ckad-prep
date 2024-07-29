terraform {
  backend "azurerm" {
    subscription_id      = "28e78168-29b4-47ef-bb00-5063d324d6c6"
    resource_group_name  = "rg-andrew-haine"
    storage_account_name = "iacconfigstore"
    container_name       = "terraform"
    key                  = "key=terraform.tfstate"
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

