output "service_url" {
  value       = "https://${azurerm_digital_twins_instance.main.host_name}"
  description = "The URL of the Azure Digital Twins service."
}

output "digital_twins_instance_resource_id" {
  value       = azurerm_digital_twins_instance.main.id
  description = "The ARM Resource ID of the Azure Digital Twins service."
}
