# Virtual Network
# Vytvorí hlavnú virtuálnu sieť (VNet) pre celý projekt
# VNet je základný building block pre sieťovú infraštruktúru v Azure
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}-${var.environment}-${var.location}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space  # Napríklad ["10.0.0.0/16"]

  tags = merge(
    var.tags, {
      Module      = "networking"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Subnets
# Vytvorí podsieťe (subnets) vo VNet na základe premennej var.subnets
# for_each iteruje cez mapu subnetov (napr. frontend, api, database)
# Každý subnet má svoj vlastný rozsah IP adries
resource "azurerm_subnet" "subnets" {
  for_each = var.subnets  # Napríklad: { frontend = {...}, api = {...}, database = {...} }

  name                 = "snet-${var.project_name}-${each.key}-${var.environment}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value.address_prefix]  # Napríklad "10.0.1.0/24"

  # Service endpoints umožňujú priamy prístup k Azure službám (Storage, SQL, atď.)
  service_endpoints = lookup(each.value, "service_endpoints", [])

  # Dynamic block - vytvorí delegation blok len ak je definovaný v subnet konfigurácii
  # Delegation umožňuje Azure službám vytvárať resources v subnete
  dynamic "delegation" {
    for_each = lookup(each.value, "delegation", null) != null ? [each.value.delegation] : []
    content {
      name = delegation.value.name  # Oprava: malo byť delegation namiesto dalegation
      service_delegation {
        name    = delegation.value.service_name
        actions = delegation.value.actions
      }
    }
  }
}

# Network Security Groups
# Vytvorí NSG (firewall) pre každý subnet
# for_each vytvorí NSG pre každý subnet definovaný vo var.subnets
resource "azurerm_network_security_group" "nsg" {
  for_each = var.subnets  # Vytvorí NSG pre frontend, api, database, atď.

  name                = "nsg-${var.project_name}-${each.key}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(
    var.tags, {
      Module      = "networking"
      Environment = var.environment
      Subnets     = each.key  # Napríklad "frontend", "api", "database"
    }
  )
}

# NSG Rules for Frontend Subnet
# Vytvorí pravidlá pre frontend subnet - povolí HTTPS prístup z Azure Front Door
# for_each filtruje len frontend subnet z celej mapy subnetov
resource "azurerm_network_security_rule" "frontend_inbound_https" {
  for_each = { for k, v in var.subnets : k => v if k == "frontend" }  # Vytvorí len pre frontend

  name                        = "AllowHTTPS"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "AzureFrontDoor.Backend"  # Povolí len z Azure Front Door
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg[each.key].name
}

# Podobné pravidlo pre HTTP na frontend
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
# Povolí prístup z frontend subnetu do API subnetu na porte 443
# for_each filtruje len API subnet
resource "azurerm_network_security_rule" "api_inbound_app" {
  for_each = { for k, v in var.subnets : k => v if k == "api" }  # Vytvorí len pre API subnet

  name                        = "AllowAppServices"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = azurerm_subnet.subnets["frontend"].address_prefixes[0]  # Z frontend subnetu
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg[each.key].name
}

# Povolí HTTP prístup na porte 8080 pre API
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
# Povolí PostgreSQL prístup len z API subnetu
# for_each filtruje len database subnet
resource "azurerm_network_security_rule" "database_inbound_postgres" {
  for_each = { for k, v in var.subnets : k => v if k == "database" }  # Vytvorí len pre database

  name                        = "AllowPostgreSQL"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"  # PostgreSQL port
  source_address_prefix       = azurerm_subnet.subnets["api"].address_prefixes[0]  # Len z API subnetu
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg[each.key].name
}

# Deny all other inbound traffic
# Vytvorí "deny all" pravidlo pre každý NSG s najnižšou prioritou
# for_each vytvorí toto pravidlo pre všetky subnety
resource "azurerm_network_security_rule" "deny_all_inbound" {
  for_each = var.subnets  # Pre všetky subnety

  name                        = "DenyAllInbound"
  priority                    = 4096  # Najnižšia priorita
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"  # Všetky protokoly
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg[each.key].name
}

# Associate NSGs with Subnets
# Pripojí každý NSG k príslušnému subnetu
# for_each zabezpečí, že každý subnet má priradený svoj NSG
resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  for_each = var.subnets  # Pre každý subnet

  subnet_id                 = azurerm_subnet.subnets[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
}

# Private DNS Zone for PostgreSQL
# Vytvorí privátnu DNS zónu pre PostgreSQL private endpoints
# count = podmienené vytvorenie na základe boolean premennej
resource "azurerm_private_dns_zone" "postgres" {
  count = var.create_private_dns_zone_postgres ? 1 : 0  # Vytvorí len ak je true

  name                = "privatelink.postgres.database.azure.com"  # Štandardný názov pre PostgreSQL
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
# Vytvorí privátnu DNS zónu pre App Services private endpoints
resource "azurerm_private_dns_zone" "app_services" {
  count = var.create_private_dns_zone_app_services ? 1 : 0  # Podmienené vytvorenie

  name                = "privatelink.azurewebsites.net"  # Štandardný názov pre App Services
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
# Vytvorí privátnu DNS zónu pre Key Vault private endpoints
resource "azurerm_private_dns_zone" "key_vault" {
  count = var.create_private_dns_zone_key_vault ? 1 : 0  # Podmienené vytvorenie

  name                = "privatelink.vaultcore.azure.net"  # Štandardný názov pre Key Vault
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
# Prepojí DNS zónu s VNet, aby mohli resources vo VNet používať private DNS
# count = vytvorí len ak existuje DNS zóna
resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  count = var.create_private_dns_zone_postgres ? 1 : 0

  name                  = "pdnsz-link-postgres-${var.project_name}-${var.environment}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres[0].name  # [0] pretože používame count
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false  # Neregistruje VM automaticky

  tags = var.tags
}

# Link Private DNS Zone to VNet - App Services
# Prepojí App Services DNS zónu s VNet
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
# Prepojí Key Vault DNS zónu s VNet
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
# Vytvorí verejnú IP adresu pre NAT Gateway
# NAT Gateway umožňuje outbound konektivitu pre private resources
resource "azurerm_public_ip" "nat_gateway" {
  count = var.create_nat_gateway ? 1 : 0  # Podmienené vytvorenie

  name                = "pip-natgw-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"  # Statická IP
  sku                 = "Standard"

  tags = merge(
    var.tags,
    {
      Module  = "networking"
      Service = "NAT Gateway"
    }
  )
}

# NAT Gateway
# Vytvorí NAT Gateway pre outbound konektivitu
resource "azurerm_nat_gateway" "main" {
  count = var.create_nat_gateway ? 1 : 0

  name                    = "natgw-${var.project_name}-${var.environment}"
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 4  # Timeout pre idle spojenia

  tags = merge(
    var.tags,
    {
      Module = "networking"
    }
  )
}

# Pripojí verejnú IP k NAT Gateway
resource "azurerm_nat_gateway_public_ip_association" "main" {
  count = var.create_nat_gateway ? 1 : 0

  nat_gateway_id       = azurerm_nat_gateway.main[0].id
  public_ip_address_id = azurerm_public_ip.nat_gateway[0].id
}

# Associate NAT Gateway with subnets
# Pripojí NAT Gateway k vybraným subnetom
# for_each s podmienkou - vytvorí asociáciu len pre subnety s associate_nat_gateway = true
resource "azurerm_subnet_nat_gateway_association" "main" {
  # Komplexný for_each:
  # 1. Kontroluje či var.create_nat_gateway je true
  # 2. Ak áno, filtruje subnety kde associate_nat_gateway = true
  # 3. Ak nie, vracia prázdnu mapu {}
  for_each = var.create_nat_gateway ? { for k, v in var.subnets : k => v if lookup(v, "associate_nat_gateway", false) } : {}

  subnet_id      = azurerm_subnet.subnets[each.key].id
  nat_gateway_id = azurerm_nat_gateway.main[0].id
}