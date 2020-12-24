output "service_url" {
  value       = "https://${azurerm_digital_twins_instance.main.host_name}"
  description = "The URL of the Azure Digital Twins service."
}
