terraform {
  required_version = ">= 1.3"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_resource_group" "lab_rg" {
  name = var.resource_group
}

data "azurerm_dev_test_lab" "lab" {
  name                = var.lab_name
  resource_group_name = data.azurerm_resource_group.lab_rg.name
}

resource "azurerm_dev_test_linux_virtual_machine" "kubequest_vm" {
  name                   = var.vm_name
  lab_name               = data.azurerm_dev_test_lab.lab.name
  resource_group_name    = data.azurerm_resource_group.lab_rg.name
  location               = data.azurerm_resource_group.lab_rg.location
  size                   = var.vm_size
  username               = var.vm_username
  password               = var.vm_password
  lab_virtual_network_id = var.lab_virtual_network_id
  lab_subnet_name        = var.lab_subnet_name
  storage_type           = "Standard"
  notes                  = "KubeQuest bootstrap VM"

  gallery_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}
