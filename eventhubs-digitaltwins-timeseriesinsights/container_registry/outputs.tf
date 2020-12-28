output "name" {
  value       = azurerm_container_registry.main.name
  description = "The container registry name."
}

output "admin_username" {
  value       = azurerm_container_registry.main.admin_username
  description = "The container registry admin username."
}

output "admin_password" {
  value       = azurerm_container_registry.main.admin_password
  sensitive   = true
  description = "The container registry admin password."
}

output "login_server" {
  value       = azurerm_container_registry.main.login_server
  description = "The container registry login server."
}
