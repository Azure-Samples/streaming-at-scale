#Set the terraform required version

terraform {
  required_version = ">= 0.12.6"

  required_providers {
    # It is recommended to pin to a given version of the Azure provider
    azurerm = "=2.41.0"
  }
}

# Configure the Azure Provider

provider "azurerm" {
  skip_provider_registration = true
  features {}
}
