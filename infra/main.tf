resource "random_string" "prefix" {
    length  = 5
    special = false
    upper   = false
    numeric = false
    lower   = true
}

locals {
  resource_name_prefix = "${var.environment}-${random_string.prefix.result}"
  comman_tags = merge(var.tags, {Environment = var.environment})
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.appName}-rg"
  location = var.location
  tags     = local.comman_tags
}

# Networking Module
module "networking" {
  source = "./modules/networking"
  resource_name_prefix = local.resource_name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location = var.location
  vnet_address_space = var.vnet_address_space
  public_subnet_address_prefixes = var.public_subnet_address_prefixes
  private_subnet_address_prefixes = var.private_subnet_address_prefixes
  database_subnet_address_prefixes = var.database_subnet_address_prefixes
  bastion_subnet_address_prefix = var.bastion_subnet_address_prefix
  app_gateway_subnet_address_prefix = var.app_gateway_subnet_address_prefix
  tags = local.comman_tags

  depends_on = [ azurerm_resource_group.main ]
}

# Key vault
module "key_vault" {
  source = "./modules/keyvault"
  resource_name_prefix = local.resource_name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location = var.location
  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id
  tags = local.comman_tags
  depends_on = [ module.databse ]
}