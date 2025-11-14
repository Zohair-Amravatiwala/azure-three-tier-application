resource "random_string" "prefix" {
  length  = 5
  special = false
  upper   = false
  # numeric = false
  lower   = true
}

locals {
  resource_name_prefix = "${var.environment}-${random_string.prefix.result}"
  comman_tags          = merge(var.tags, { Environment = var.environment })
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.appName}-rg"
  location = var.location
  tags     = local.comman_tags
}

# Networking Module
module "networking" {
  source                            = "./modules/networking"
  resource_name_prefix              = local.resource_name_prefix
  resource_group_name               = azurerm_resource_group.main.name
  location                          = var.location
  vnet_address_space                = var.vnet_address_space
  public_subnet_address_prefixes    = var.public_subnet_address_prefixes
  private_subnet_address_prefixes   = var.private_subnet_address_prefixes
  database_subnet_address_prefixes  = var.database_subnet_address_prefixes
  bastion_subnet_address_prefix     = var.bastion_subnet_address_prefix
  app_gateway_subnet_address_prefix = var.app_gateway_subnet_address_prefix
  tags                              = local.comman_tags

  depends_on = [azurerm_resource_group.main]
}

# DNS for Private Endpoints (PostgreSQL)
module "dns" {
  source              = "./modules/dns"
  resource_group_name = azurerm_resource_group.main.name
  virtual_network_id  = module.networking.vnet_id
  tags                = local.comman_tags

  depends_on = [module.networking]
}

# Database
module "database" {
  source = "./modules/database"

  resource_group_name  = azurerm_resource_group.main.name
  location             = var.location
  resource_name_prefix = local.resource_name_prefix
  database_subnet_ids  = module.networking.database_subnet_ids
  private_dns_zone_id  = module.dns.private_dns_zone_id
  postgres_sku_name    = var.postgres_sku_name
  postgres_version     = var.postgres_version
  postgres_storage_mb  = var.postgres_storage_mb
  postgres_db_name     = var.postgres_db_name
  tags                 = local.comman_tags

  depends_on = [module.dns, module.networking]
}

# Key vault
module "key_vault" {
  source               = "./modules/keyvault"
  resource_name_prefix = local.resource_name_prefix
  resource_group_name  = azurerm_resource_group.main.name
  location             = var.location
  tenant_id            = data.azurerm_client_config.current.tenant_id
  object_id            = data.azurerm_client_config.current.object_id
  tags                 = local.comman_tags
  depends_on           = [module.database]
}

# After Key Vault is created, store database credentials as secrets

resource "azurerm_key_vault_secret" "db_host" {
  name         = "db-host"
  value        = module.database.server_fqdn
  key_vault_id = module.key_vault.key_vault_id
  depends_on   = [module.database, module.key_vault]
}

resource "azurerm_key_vault_secret" "db_username" {
  name         = "db-username"
  value        = module.database.administrator_login
  key_vault_id = module.key_vault.key_vault_id
  depends_on   = [module.key_vault, module.database]
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = module.database.administrator_password
  key_vault_id = module.key_vault.key_vault_id

  depends_on = [module.key_vault, module.database]
}

resource "azurerm_key_vault_secret" "db_name" {
  name         = "db-name"
  value        = var.postgres_db_name
  key_vault_id = module.key_vault.key_vault_id

  depends_on = [module.key_vault]
}

# Add DB port and SSL mode to Key Vault
resource "azurerm_key_vault_secret" "db_port" {
  name         = "db-port"
  value        = tostring(var.postgres_db_port)
  key_vault_id = module.key_vault.key_vault_id

  depends_on = [module.key_vault]
}

resource "azurerm_key_vault_secret" "db_sslmode" {
  name         = "db-sslmode"
  value        = var.postgres_db_sslmode
  key_vault_id = module.key_vault.key_vault_id

  depends_on = [module.key_vault]
}

# Store Docker credentials in Key Vault
resource "azurerm_key_vault_secret" "docker_username" {
  name         = "docker-username"
  value        = var.docker_username
  key_vault_id = module.key_vault.key_vault_id

  depends_on = [module.key_vault]
}

resource "azurerm_key_vault_secret" "docker_password" {
  name         = "docker-password"
  value        = var.docker_password
  key_vault_id = module.key_vault.key_vault_id

  depends_on = [module.key_vault]
}

# Compute - Frontend VMSS
module "frontend" {
  count  = var.deploy_compute ? 1 : 0
  source = "./modules/compute"

  resource_group_name  = azurerm_resource_group.main.name
  resource_name_prefix = local.resource_name_prefix
  location             = var.location
  subnet_id            = module.networking.public_subnet_ids[0]
  appgw_subnet_id      = module.networking.appgw_subnet_id
  vm_size              = var.frontend_vm_size
  instance_count       = var.frontend_instances
  admin_username       = var.admin_username
  docker_username      = var.docker_username
  docker_password      = var.docker_password
  docker_image         = var.frontend_image
  is_frontend          = true
  application_port     = 3000
  health_probe_path    = "/"
  key_vault_id         = module.key_vault.key_vault_id
  # Pass the backend load balancer IP if the backend module has been created
  backend_load_balancer_ip = var.deploy_compute ? module.backend[0].load_balancer_private_ip : null
  tags                     = local.comman_tags

  depends_on = [
    module.key_vault,
    module.backend # We can not use conditionals in depends_on, so we will rely on the backend modules count to handle this dependency
  ]

}

# Compute - Backend VMSS
module "backend" {
  count  = var.deploy_compute ? 1 : 0
  source = "./modules/compute"

  resource_group_name  = azurerm_resource_group.main.name
  location             = var.location
  resource_name_prefix = local.resource_name_prefix
  subnet_id            = module.networking.private_subnet_ids[0]
  vm_size              = var.backend_vm_size
  instance_count       = var.backend_instances
  admin_username       = var.admin_username
  docker_username      = var.docker_username
  docker_password      = var.docker_password
  docker_image         = var.backend_image
  is_frontend          = false
  application_port     = 8080
  health_probe_path    = "/health"
  key_vault_id         = module.key_vault.key_vault_id
  tags                 = var.tags

  database_connection = {
    host     = module.database.server_fqdn
    port     = var.postgres_db_port
    username = module.database.administrator_login
    password = module.database.administrator_password
    dbname   = var.postgres_db_name
    sslmode  = var.postgres_db_sslmode
  }

  depends_on = [module.key_vault,
  module.database]
}

# Update Key Vault with backend identity
resource "azurerm_key_vault_access_policy" "backend_policy" {
  count        = var.deploy_compute ? 1 : 0
  key_vault_id = module.key_vault.key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = module.backend[0].identity_principal_id

  secret_permissions = [
    "Get", "List"
  ]

  depends_on = [
    module.key_vault,
    module.backend
  ]
}
