terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
  }

  required_version = ">= 1.0.0"
}

provider "azurerm" {
  features {}

  skip_provider_registration = true
}

variable "resource_group_name" {}

variable "name" {}

variable "teamname" {}

variable "repourl" {}

variable "repopath" {}

# ade env deployer ID
variable "ade_userid" {}