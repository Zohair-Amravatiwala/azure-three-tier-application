variable "environment" {
  type = string
  default = "dev"
}

variable "tags" {
  type = map(string)
  default = {
    owner   = "Zohair"
    purpose = "demo"
  }
}

variable "appName" {
  type = string
  default = "three-tier-app"
}

variable "location" {
  type = string
  default = "westus"
}

variable "vnet_address_space" {
  type = string
  description = "Address space for Virtual network."
}

variable "public_subnet_address_prefixes" {
  type = list(string)
  description = "Address prefixes for public subnets."
}

variable "private_subnet_address_prefixes" {
  type = list(string)
  description = "Address prefixes for private subnets."
}

variable "database_subnet_address_prefixes" {
  type = list(string)
  description = "Address prefixes for database subnets."
}

variable "bastion_subnet_address_prefix" {
  type = string
  description = "Address prefix for bastion service."
}

variable "app_gateway_subnet_address_prefix" {
  type = string
  description = "Address prefix for Applciation gateway subnet."
}