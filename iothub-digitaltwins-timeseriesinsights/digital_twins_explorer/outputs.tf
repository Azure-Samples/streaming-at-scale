output "digital_twins_explorer_url" {
  value       = "http://${azurerm_container_group.main.ip_address}"
  description = "The URL of the Azure Digital Twins Explorer webapp."
}

