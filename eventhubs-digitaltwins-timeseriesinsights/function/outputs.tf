output "host_name" {
  value       = azurerm_function_app.main.default_hostname
  description = "The function host name."
}
