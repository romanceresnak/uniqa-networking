Azure Networking Terraform Module
This module creates the networking infrastructure for Azure applications, including Virtual Networks, subnets, Network Security Groups, and private DNS zones.
Features

✅ Virtual Network with configurable address space
✅ Multiple subnets with service endpoints
✅ Network Security Groups with predefined security rules
✅ Private DNS Zones for Azure services (PostgreSQL, App Services, Key Vault)
✅ Support for subnet delegation
✅ Optional NAT Gateway for outbound connectivity
✅ Consistent naming convention following Azure best practices
✅ Comprehensive tagging strategy
✅ NSG rules tailored for web applications architecture

Architecture
This module creates the following architecture:
┌─────────────────────────────────────────────────────────────┐
│                    Virtual Network (VNet)                    │
├─────────────────┬─────────────────┬────────────────────────┤
│  Frontend Subnet │   API Subnet    │   Database Subnet      │
│  NSG: Allow 443  │  NSG: Allow 443 │  NSG: Allow 5432      │
│  from Front Door │  from Frontend  │  from API Subnet       │
└─────────────────┴─────────────────┴────────────────────────┘
                            │
                    Private DNS Zones
          ┌─────────────────┼─────────────────┐
          │                 │                 │
    PostgreSQL        App Services       Key Vault
Usage
Basic Example
hclmodule "networking" {
  source = "git::https://gitlab.com/your-org/terraform-module-azure-networking.git?ref=v1.0.0"

  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  environment        = "dev"
  project_name       = "myapp"
  
  vnet_address_space = ["10.0.0.0/16"]
  
  subnets = {
    frontend = {
      address_prefix    = "10.0.1.0/24"
      service_endpoints = ["Microsoft.Web"]
    }
    api = {
      address_prefix    = "10.0.2.0/24"
      service_endpoints = ["Microsoft.Web", "Microsoft.Sql"]
    }
    database = {
      address_prefix    = "10.0.3.0/24"
      service_endpoints = ["Microsoft.Sql"]
    }
  }
  
  tags = {
    Project    = "MyApplication"
    CostCenter = "IT"
  }
}
Requirements
NameVersionterraform>= 1.0azurerm>= 3.0, < 4.0
Providers
NameVersionazurerm>= 3.0, < 4.0
Inputs
NameDescriptionTypeDefaultRequiredresource_group_nameThe name of the resource groupstringn/ayeslocationAzure region for resourcesstringn/ayesenvironmentEnvironment name (dev, staging, prod)stringn/ayesproject_nameProject name for resource namingstringn/ayesvnet_address_spaceAddress space for the virtual networklist(string)n/ayessubnetsMap of subnet configurationsmap(object)n/ayescreate_private_dns_zone_postgresCreate private DNS zone for PostgreSQLbooltruenocreate_private_dns_zone_app_servicesCreate private DNS zone for App Servicesbooltruenocreate_private_dns_zone_key_vaultCreate private DNS zone for Key Vaultbooltruenocreate_nat_gatewayCreate NAT Gateway for outbound connectivityboolfalsenotagsCommon tags to apply to all resourcesmap(string){}no
Outputs
NameDescriptionvnet_idThe ID of the Virtual Networkvnet_nameThe name of the Virtual Networkvnet_address_spaceThe address space of the Virtual Networksubnet_idsMap of subnet names to their IDssubnet_namesMap of subnet namessubnet_address_prefixesMap of subnet names to their address prefixesnsg_idsMap of Network Security Group IDsnsg_namesMap of Network Security Group namesprivate_dns_zone_postgres_idThe ID of the private DNS zone for PostgreSQLprivate_dns_zone_postgres_nameThe name of the private DNS zone for PostgreSQLprivate_dns_zone_app_services_idThe ID of the private DNS zone for App Servicesprivate_dns_zone_app_services_nameThe name of the private DNS zone for App Servicesprivate_dns_zone_key_vault_idThe ID of the private DNS zone for Key Vaultprivate_dns_zone_key_vault_nameThe name of the private DNS zone for Key Vaultnat_gateway_idThe ID of the NAT Gatewaynat_gateway_public_ipThe public IP address of the NAT Gateway
Network Security Rules
The module automatically creates the following NSG rules:
Frontend Subnet

AllowHTTPS: Allows HTTPS (443) from Azure Front Door
AllowHTTP: Allows HTTP (80) from Azure Front Door
DenyAllInbound: Denies all other inbound traffic

API Subnet

AllowAppServices: Allows HTTPS (443) from Frontend subnet
AllowHTTP: Allows HTTP (8080) from Frontend subnet
DenyAllInbound: Denies all other inbound traffic

Database Subnet

AllowPostgreSQL: Allows PostgreSQL (5432) from API subnet
DenyAllInbound: Denies all other inbound traffic

Resource Naming Convention
All resources follow Azure naming best practices:

Virtual Network: vnet-{project_name}-{environment}-{location}
Subnet: snet-{project_name}-{subnet_key}-{environment}
NSG: nsg-{project_name}-{subnet_key}-{environment}
Private DNS Zone: Standard Azure private DNS zone names
NAT Gateway: natgw-{project_name}-{environment}

Security Considerations

Network Security Groups implement a zero-trust approach with explicit allow rules
Default deny-all inbound rule on all subnets
Service endpoints enabled for Azure PaaS services
Private DNS zones for private endpoint connectivity
Subnet delegation support for Azure services