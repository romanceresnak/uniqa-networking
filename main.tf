#Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}-${var.environment}-${var.location}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space

  tags = merge(
    var.tags, {
      Module      = "networking"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

#Subnets
resource "azurerm_subnet" "subnets" {
  for_each = var.subnets

  name                 = "snet-${var.project_name}-${each.key}-${var.environment}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value.address_prefix]

  service_endpoints = lookup(each.value, "service_endpoints", [])

  dynamic "delegation" {
    for_each = lookup(each.value, "delegation", null) != null ? [each.value.delegation] : []
    content {
      name = dalegation.value.name
      service_delegation {
        name    = delegation.value.service_name
        actions = delegation.value.actions
      }
    }
  }
}

# Network Security Groups
resource "azurerm_network_security_group" "nsg" {
  for_each = var.subnets

  name                = "nsg-${var.project_name}-${each.key}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(
    var.tags, {
      Module      = "networking"
      Environment = var.environment
      Subnets     = each.key
    }
  )
}

# NSG Rules for Frontend Subnet
resource "azurerm_network_security_rule" "frontend_inbound_https" {
  for_each = { for k, v in var.subnets : k => v if k == "frontend" }

  name                        = "AllowHTTPS"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "AzureFrontDoor.Backend"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg[each.key].name
}

resource "azurerm_network_security_rule" "frontend_inbound_http" {
  for_each = { for k, v in var.subnets : k => v if k == "frontend" }

  name                        = "AllowHTTP"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "AzureFrontDoor.Backend"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg[each.key].name
}

# NSG Rules for API Subnet
resource "azurerm_network_security_rule" "api_inbound_app" {
  for_each = { for k, v in var.subnets : k => v if k == "api" }

  name                        = "AllowAppServices"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = azurerm_subnet.subnets["frontend"].address_prefixes[0]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg[each.key].name
}

resource "azurerm_network_security_rule" "api_inbound_http" {
  for_each = { for k, v in var.subnets : k => v if k == "api" }

  name                        = "AllowHTTP"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8080"
  source_address_prefix       = azurerm_subnet.subnets["frontend"].address_prefixes[0]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg[each.key].name
}

# NSG Rules for Database Subnet
resource "azurerm_network_security_rule" "database_inbound_postgres" {
  for_each = { for k, v in var.subnets : k => v if k == "database" }

  name                        = "AllowPostgreSQL"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = azurerm_subnet.subnets["api"].address_prefixes[0]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg[each.key].name
}

# Deny all other inbound traffic
resource "azurerm_network_security_rule" "deny_all_inbound" {
  for_each = var.subnets

  name                        = "DenyAllInbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg[each.key].name
}

# Associate NSGs with Subnets
resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  for_each = var.subnets

  subnet_id                 = azurerm_subnet.subnets[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
}

# Private DNS Zone for PostgreSQL
resource "azurerm_private_dns_zone" "postgres" {
  count = var.create_private_dns_zone_postgres ? 1 : 0

  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name

  tags = merge(
    var.tags,
    {
      Module  = "networking"
      Service = "PostgreSQL"
    }
  )
}

# Private DNS Zone for App Services
resource "azurerm_private_dns_zone" "app_services" {
  count = var.create_private_dns_zone_app_services ? 1 : 0

  name                = "privatelink.azurewebsites.net"
  resource_group_name = var.resource_group_name

  tags = merge(
    var.tags,
    {
      Module  = "networking"
      Service = "AppServices"
    }
  )
}

# Private DNS Zone for Key Vault
resource "azurerm_private_dns_zone" "key_vault" {
  count = var.create_private_dns_zone_key_vault ? 1 : 0

  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name

  tags = merge(
    var.tags,
    {
      Module  = "networking"
      Service = "KeyVault"
    }
  )
}

# Link Private DNS Zone to VNet - PostgreSQL
resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  count = var.create_private_dns_zone_postgres ? 1 : 0

  name                  = "pdnsz-link-postgres-${var.project_name}-${var.environment}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres[0].name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false

  tags = var.tags
}

# Link Private DNS Zone to VNet - App Services
resource "azurerm_private_dns_zone_virtual_network_link" "app_services" {
  count = var.create_private_dns_zone_app_services ? 1 : 0

  name                  = "pdnsz-link-app-${var.project_name}-${var.environment}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.app_services[0].name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false

  tags = var.tags
}

# Link Private DNS Zone to VNet - Key Vault
resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  count = var.create_private_dns_zone_key_vault ? 1 : 0

  name                  = "pdnsz-link-kv-${var.project_name}-${var.environment}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault[0].name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false

  tags = var.tags
}

# NAT Gateway for outbound connectivity (optional)
resource "azurerm_public_ip" "nat_gateway" {
  count = var.create_nat_gateway ? 1 : 0

  name                = "pip-natgw-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(
    var.tags,
    {
      Module  = "networking"
      Service = "NAT Gateway"
    }
  )
}

resource "azurerm_nat_gateway" "main" {
  count = var.create_nat_gateway ? 1 : 0

  name                    = "natgw-${var.project_name}-${var.environment}"
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 4

  tags = merge(
    var.tags,
    {
      Module = "networking"
    }
  )
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  count = var.create_nat_gateway ? 1 : 0

  nat_gateway_id       = azurerm_nat_gateway.main[0].id
  public_ip_address_id = azurerm_public_ip.nat_gateway[0].id
}

# Associate NAT Gateway with subnets
resource "azurerm_subnet_nat_gateway_association" "main" {
  for_each = var.create_nat_gateway ? { for k, v in var.subnets : k => v if lookup(v, "associate_nat_gateway", false) } : {}

  subnet_id      = azurerm_subnet.subnets[each.key].id
  nat_gateway_id = azurerm_nat_gateway.main[0].id
}