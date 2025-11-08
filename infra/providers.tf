terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.3.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
  }
  required_version = "~> 1.12.0"
}

provider "azurerm" {
  features {
    
  }
}

provider "random" {
  
}