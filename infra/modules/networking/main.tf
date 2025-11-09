/*
 * Network Module
 * This module creates all networking components:
 * - Virtual Network with 2 Public subnets and 2 Private subnets
 * - Network Security Groups
 * - Bastion Host
 * - NAT Gateway with Public IP
 */

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.resource_name_prefix}-vnet"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

# Public Subnets (Frontend)
resource "azurerm_subnet" "public" {
  count                = length(var.public_subnet_address_prefixes)
  name                 = "${var.resource_name_prefix}-public-snet-${count.index + 1}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.public_subnet_address_prefixes[count.index]]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.ContainerRegistry"]
}

# Public Subnet NSG
resource "azurerm_network_security_group" "public" {
  name                = "${var.resource_name_prefix}-public-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowHTTPInBound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "Internet"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "80"
  }

  security_rule {
    name                       = "AllowHTTPSInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "Internet"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "443"
  }

  security_rule {
    name                       = "AllowSSHFromBastion"
    priority                   = 115
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = var.bastion_subnet_address_prefix
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "22"
  }

  security_rule {
    name                       = "AllowAppGwInbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_ranges    = [65200 - 65535]
  }
}

# Associate Public Subnet NSG with Public Subnet
resource "azurerm_subnet_network_security_group_association" "public" {
  count                     = length(var.public_subnet_address_prefixes)
  subnet_id                 = azurerm_subnet.public[count.index].id
  network_security_group_id = azurerm_network_security_group.public.id
}

# Private Subnets (Backend)
resource "azurerm_subnet" "private" {
  count                = length(var.private_subnet_address_prefixes)
  name                 = "${var.resource_name_prefix}-private-snet-${count.index + 1}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.private_subnet_address_prefixes[count.index]]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.ContainerRegistry"]
}

#Private Subnet NSG
resource "azurerm_network_security_group" "private" {
  name                = "${var.resource_name_prefix}-private-nsg"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  #   security_rule {
  #     name = "AllowVnetInbound"
  #     priority = 100
  #     direction = "Inbound"
  #     access = "Allow"
  #     protocol = "*"
  #     source_address_prefix = "VirtualNetwork"
  #     source_port_range = "*"
  #     destination_address_prefix = "VirtualNetwork"
  #     destination_port_range = "*"
  #   }

  security_rule {
    name                       = "AllowBackendAppPort"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = var.vnet_address_space
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "*"
  }

  security_rule {
    name                       = "AllowInternetOutbound"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "Internet"
    destination_port_range     = "*"
  }


}

# Associate Private Subnet NSG with Private Subnet
resource "azurerm_subnet_network_security_group_association" "private" {
  count                     = length(var.private_subnet_address_prefixes)
  subnet_id                 = azurerm_subnet.private[count.index].id
  network_security_group_id = azurerm_network_security_group.private.id
}

# Database Subnets
resource "azurerm_subnet" "database" {
  count                = length(var.database_subnet_address_prefixes)
  name                 = "${var.resource_name_prefix}-db-snet-${count.index + 1}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.database_subnet_address_prefixes[count.index]]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.SQL"]
  # Required delegation for PostgreSQL Flexible Server VNet integration
  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

#Database Subnet NSG
resource "azurerm_network_security_group" "databse" {
  name                = "${var.resource_name_prefix}-db-nsg"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  security_rule {
    name                       = "AllowPostgreSQLInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = var.vnet_address_space
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "5432"
  }

  security_rule {
    name                       = "AllowVnetOutbound"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "VirtualNetwork"
    destination_port_range     = "*"
  }

  security_rule {
    name                       = "AllowAzureServicesOutbound"
    priority                   = 210
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "AzureCloud"
    destination_port_range     = "443"
  }
}

# Associate Database Subnet NSG with Database Subnet
resource "azurerm_subnet_network_security_group_association" "database" {
  count                     = length(var.database_subnet_address_prefixes)
  subnet_id                 = azurerm_subnet.database[count.index].id
  network_security_group_id = azurerm_network_security_group.databse.id
}

# Bastion Subnet
resource "azurerm_subnet" "bastion" {
  name                 = "${var.resource_name_prefix}-bastion-snet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.bastion_subnet_address_prefix]
}

# Bastion Subnet NSG
resource "azurerm_network_security_group" "bastion" {
  name                = "${var.resource_name_prefix}-bastion-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Required inbound rules for Bastion
  security_rule {
    name                       = "AllowHttpsInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowGatewayManagerInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAzureLoadBalancerInbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowBastionHostComm"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # Required outbound rules for Bastion
  security_rule {
    name                       = "AllowSshOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowRdpOutbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowBastionHostCommOutbound"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowHttpsOutbound"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }
}

resource "azurerm_subnet_network_security_group_association" "bastion" {
  subnet_id                 = azurerm_subnet.bastion.id
  network_security_group_id = azurerm_network_security_group.bastion.id
}

#Bastion Public IP
resource "azurerm_public_ip" "bastion" {
  name                = "${var.resource_name_prefix}-bastion-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Bastion Host
resource "azurerm_bastion_host" "main" {
  name                = "${var.resource_name_prefix}-bastion"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  ip_configuration {
    name                 = "config"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

# Azure Application Gateway Subnet
resource "azurerm_subnet" "app_gateway" {
  name                 = "${var.resource_name_prefix}-appgw-snet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.app_gateway_subnet_address_prefix]
}

# NAT Gateway provides outbound internet connectivity for private subnets
resource "azurerm_nat_gateway" "main" {
  name                    = "${var.resource_name_prefix}-natgw"
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  tags                    = var.tags
}

# NAT Gateway Public IP for backend subnets
resource "azurerm_public_ip" "natgw" {
  name                = "${var.resource_name_prefix}-natgw-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}


# Associate NAT Gateway with its Public IP
resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.natgw.id
}

# Associate NAT Gateway with private subnets
resource "azurerm_subnet_nat_gateway_association" "private" {
  count          = length(azurerm_subnet.private)
  subnet_id      = azurerm_subnet.private[count.index].id
  nat_gateway_id = azurerm_nat_gateway.main.id
}