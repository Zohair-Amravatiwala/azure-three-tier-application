variable "resource_name_prefix" {
  type        = string
  description = "Prefix for resource names."
}
variable "resource_group_name" {
  type        = string
  description = "Name of resource group."
}

variable "location" {
  type        = string
  description = "Name of location where resources will be deployed."
}

variable "tags" {
  type = map(string)
}

variable "vnet_address_space" {
  type        = string
  description = "Address space for Virtual network."
}

variable "public_subnet_address_prefixes" {
  type        = list(string)
  description = "Address prefixes for public subnets."
}

variable "private_subnet_address_prefixes" {
  type        = list(string)
  description = "Address prefixes for private subnets."
}

variable "database_subnet_address_prefixes" {
  type        = list(string)
  description = "Address prefixes for database subnets."
}

variable "bastion_subnet_address_prefix" {
  type        = string
  description = "Address prefix for bastion service."
}

variable "app_gateway_subnet_address_prefix" {
  type        = string
  description = "Address prefix for Applciation gateway subnet."
}