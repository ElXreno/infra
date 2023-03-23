terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.48.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "persist"
    storage_account_name = "sac26815"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "nixos" {
  name     = "nixos-infra"
  location = "West Europe"
}

resource "azurerm_virtual_network" "nixos" {
  name                = "nixos-network"
  resource_group_name = azurerm_resource_group.nixos.name
  location            = azurerm_resource_group.nixos.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_storage_account" "nixos" {
  name                     = "nixosstorage"
  resource_group_name      = azurerm_resource_group.nixos.name
  location                 = azurerm_resource_group.nixos.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "nixos" {
  name                  = "content"
  storage_account_name  = azurerm_storage_account.nixos.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "nixos-x86_64" {
  name                   = "nixos-x86_64.vhd"
  storage_account_name   = azurerm_storage_account.nixos.name
  storage_container_name = azurerm_storage_container.nixos.name
  type                   = "Page"
  source                 = "../result/disk.vhd"
}

resource "azurerm_image" "nixos-x86_64-image" {
  name                = "nixos-x86_64-image"
  location            = azurerm_resource_group.nixos.location
  resource_group_name = azurerm_resource_group.nixos.name
  hyper_v_generation  = "V1"

  os_disk {
    os_type  = "Linux"
    os_state = "Generalized"
    blob_uri = azurerm_storage_blob.nixos-x86_64.id
  }
}