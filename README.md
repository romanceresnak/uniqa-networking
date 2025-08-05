# Azure Networking Terraform Module

This module creates the networking infrastructure for Azure applications, including Virtual Networks, subnets, Network Security Groups, and private DNS zones.

## ✅ Features

- Virtual Network with configurable address space  
- Multiple subnets with service endpoints  
- Network Security Groups with predefined security rules  
- Private DNS Zones for Azure services (PostgreSQL, App Services, Key Vault)  
- Support for subnet delegation  
- Optional NAT Gateway for outbound connectivity  
- Consistent naming convention following Azure best practices  
- Comprehensive tagging strategy  
- NSG rules tailored for web applications architecture  

## Architecture

This module creates the following architecture:



## 🚀 Usage

### Basic Example

```hcl
module "networking" {
  source = "git::https://gitlab.com/your-org/terraform-module-azure-networking.git?ref=v1.0.0"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  environment         = "dev"
  project_name        = "myapp"
  
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

📦 Requirements
| Name      | Version       |
| --------- | ------------- |
| terraform | >= 1.0        |
| azurerm   | >= 3.0, < 4.0 |

🔌 Providers
| Name    | Version       |
| ------- | ------------- |
| azurerm | >= 3.0, < 4.0 |

Inputs
| Name                                      | Description                                  | Type           | Default | Required |
| ----------------------------------------- | -------------------------------------------- | -------------- | ------- | -------- |
| resource\_group\_name                     | The name of the resource group               | `string`       | n/a     | ✅        |
| location                                  | Azure region for resources                   | `string`       | n/a     | ✅        |
| environment                               | Environment name (dev, staging, prod)        | `string`       | n/a     | ✅        |
| project\_name                             | Project name for resource naming             | `string`       | n/a     | ✅        |
| vnet\_address\_space                      | Address space for the virtual network        | `list(string)` | n/a     | ✅        |
| subnets                                   | Map of subnet configurations                 | `map(object)`  | n/a     | ✅        |
| create\_private\_dns\_zone\_postgres      | Create private DNS zone for PostgreSQL       | `bool`         | `true`  | ❌        |
| create\_private\_dns\_zone\_app\_services | Create private DNS zone for App Services     | `bool`         | `true`  | ❌        |
| create\_private\_dns\_zone\_key\_vault    | Create private DNS zone for Key Vault        | `bool`         | `true`  | ❌        |
| create\_nat\_gateway                      | Create NAT Gateway for outbound connectivity | `bool`         | `false` | ❌        |
| tags                                      | Common tags to apply to all resources        | `map(string)`  | `{}`    | ❌        |

Outputs
| Name                                    | Description                                       |
| --------------------------------------- | ------------------------------------------------- |
| vnet\_id                                | The ID of the Virtual Network                     |
| vnet\_name                              | The name of the Virtual Network                   |
| vnet\_address\_space                    | The address space of the Virtual Network          |
| subnet\_ids                             | Map of subnet names to their IDs                  |
| subnet\_names                           | Map of subnet names                               |
| subnet\_address\_prefixes               | Map of subnet names to their address prefixes     |
| nsg\_ids                                | Map of Network Security Group IDs                 |
| nsg\_names                              | Map of Network Security Group names               |
| private\_dns\_zone\_postgres\_id        | The ID of the private DNS zone for PostgreSQL     |
| private\_dns\_zone\_postgres\_name      | The name of the private DNS zone for PostgreSQL   |
| private\_dns\_zone\_app\_services\_id   | The ID of the private DNS zone for App Services   |
| private\_dns\_zone\_app\_services\_name | The name of the private DNS zone for App Services |
| private\_dns\_zone\_key\_vault\_id      | The ID of the private DNS zone for Key Vault      |
| private\_dns\_zone\_key\_vault\_name    | The name of the private DNS zone for Key Vault    |
| nat\_gateway\_id                        | The ID of the NAT Gateway                         |
| nat\_gateway\_public\_ip                | The public IP address of the NAT Gateway          |

🔐 Network Security Rules
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

📛 Resource Naming Convention
All resources follow Azure naming best practices:

Virtual Network: vnet-{project_name}-{environment}-{location}

Subnet: snet-{project_name}-{subnet_key}-{environment}

NSG: nsg-{project_name}-{subnet_key}-{environment}

Private DNS Zone: Standard Azure private DNS zone names

NAT Gateway: natgw-{project_name}-{environment}

🔒 Security Considerations
Network Security Groups implement a zero-trust approach with explicit allow rules

Default deny-all inbound rule on all subnets

Service endpoints enabled for Azure PaaS services

Private DNS zones for private endpoint connectivity

Subnet delegation support for Azure services