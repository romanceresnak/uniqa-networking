output "vnet_id" {
  description = "The ID of the Virtual Network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "The name of the Virtual Network"
  value       = azurerm_virtual_network.main.name
}

output "vnet_address_space" {
  description = "The address space of the Virtual Network"
  value       = azurerm_virtual_network.main.address_space
}

output "subnet_ids" {
  description = "Map of subnet names to their IDs"
  value       = { for k, v in azurerm_subnet.subnets : k => v.id }
}

output "subnet_names" {
  description = "Map of subnet names"
  value       = { for k, v in azurerm_subnet.subnets : k => v.name }
}

output "subnet_address_prefixes" {
  description = "Map of subnet names to their address prefixes"
  value       = { for k, v in azurerm_subnet.subnets : k => v.address_prefixes[0] }
}

output "nsg_ids" {
  description = "Map of Network Security Group IDs"
  value       = { for k, v in azurerm_network_security_group.nsg : k => v.id }
}

output "nsg_names" {
  description = "Map of Network Security Group names"
  value       = { for k, v in azurerm_network_security_group.nsg : k => v.name }
}

output "private_dns_zone_postgres_id" {
  description = "The ID of the private DNS zone for PostgreSQL"
  value       = var.create_private_dns_zone_postgres ? azurerm_private_dns_zone.postgres[0].id : null
}

output "private_dns_zone_postgres_name" {
  description = "The name of the private DNS zone for PostgreSQL"
  value       = var.create_private_dns_zone_postgres ? azurerm_private_dns_zone.postgres[0].name : null
}

output "private_dns_zone_app_services_id" {
  description = "The ID of the private DNS zone for App Services"
  value       = var.create_private_dns_zone_app_services ? azurerm_private_dns_zone.app_services[0].id : null
}

output "private_dns_zone_app_services_name" {
  description = "The name of the private DNS zone for App Services"
  value       = var.create_private_dns_zone_app_services ? azurerm_private_dns_zone.app_services[0].name : null
}

output "private_dns_zone_key_vault_id" {
  description = "The ID of the private DNS zone for Key Vault"
  value       = var.create_private_dns_zone_key_vault ? azurerm_private_dns_zone.key_vault[0].id : null
}

output "private_dns_zone_key_vault_name" {
  description = "The name of the private DNS zone for Key Vault"
  value       = var.create_private_dns_zone_key_vault ? azurerm_private_dns_zone.key_vault[0].name : null
}

output "nat_gateway_id" {
  description = "The ID of the NAT Gateway"
  value       = var.create_nat_gateway ? azurerm_nat_gateway.main[0].id : null
}

output "nat_gateway_public_ip" {
  description = "The public IP address of the NAT Gateway"
  value       = var.create_nat_gateway ? azurerm_public_ip.nat_gateway[0].ip_address : null
}