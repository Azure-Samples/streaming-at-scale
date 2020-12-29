output "name" {
  value       = azurerm_function_app.main.name
  description = "The function app resource name."
}

output "host_name" {
  value       = azurerm_function_app.main.default_hostname
  description = "The function host name."
}

output "system_assigned_identity" {
  value       = azurerm_function_app.main.identity.0
  description = "The function system assigned identity (service principal). Includes the principal_id attribute."
}
