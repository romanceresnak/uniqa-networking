variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  validation {
    condition = alltrue([
      for cidr in var.vnet_address_space : can(cidrhost(cidr, 0))
    ])
    error_message = "All address spaces must be valid CIDR blocks."
  }
}

variable "subnets" {
  description = "Map of subnet configurations"
  type = map(object({
    address_prefix    = string
    service_endpoints = optional(list(string), [])
    delegation = optional(object({
      name         = string
      service_name = string
      actions      = list(string)
    }))
    associate_nat_gateway = optional(bool, false)
  }))
  validation {
    condition = alltrue([
      for subnet in var.subnets : can(cidrhost(subnet.address_prefix, 0))
    ])
    error_message = "All subnet address prefixes must be valid CIDR blocks."
  }
}

variable "create_private_dns_zone_postgres" {
  description = "Create private DNS zone for PostgreSQL"
  type        = bool
  default     = true
}

variable "create_private_dns_zone_app_services" {
  description = "Create private DNS zone for App Services"
  type        = bool
  default     = true
}

variable "create_private_dns_zone_key_vault" {
  description = "Create private DNS zone for Key Vault"
  type        = bool
  default     = true
}

variable "create_nat_gateway" {
  description = "Create NAT Gateway for outbound connectivity"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}