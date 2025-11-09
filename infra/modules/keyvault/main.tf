/*
 * Key Vault Module
 * This module creates an Azure Key Vault for storing secrets used by the application,
 * such as database credentials, connection strings, and other sensitive information.
 */

# Azure Key Vault
resource "azurerm_key_vault" "key_vault" {
  name                        = "${var.resource_name_prefix}-kv"
  resource_group_name         = var.resource_group_name
  location                    = var.location
  sku_name                    = "standard"
  tenant_id                   = var.tenant_id
  enabled_for_disk_encryption = true
  rbac_authorization_enabled  = false
  purge_protection_enabled    = false

  # Common access policies
  access_policy = {
    tenant_id = var.tenant_id
    object_id = var.object_id

    key_permissions = [
      "Get", "List", "Create", "Delete", "Update", "Recover", "Backup", "Restore", "Purge"
    ]

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore", "Purge"
    ]

    certificate_permissions = [
      "Get", "List", "Create", "Delete", "Update", "Recover", "Backup", "Restore", "Import", "Purge"
    ]
  }

  # Access policy for backend VM managed identity (if provided)
  dynamic "access_policy" {
    for_each = var.backend_identity_principal_id != null ? [1] : []
    content {
      tenant_id = var.tenant_id
      object_id = var.backend_identity_principal_id

      secret_permissions = ["Get", "List"]
    }
  }

  #Network access configuration
  network_acls {
    default_action = "Allow" # Consider changing to "Deny" in production and explicitly allowing needed IPs/VNets
    bypass         = "AzureServices"
  }

}