output "resource_group_name" {
  description = "The name of the Azure Resource Group"
  value       = azurerm_resource_group.rg.name
}

output "public_ip_address" {
  description = "The public IP address of the virtual machine"
  value       = azurerm_public_ip.web_ip.ip_address
}
