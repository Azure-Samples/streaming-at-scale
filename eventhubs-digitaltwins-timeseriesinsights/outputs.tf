output "subscription_id" {
  description = "The Azure Subscription identifier."
  value       = data.azurerm_client_config.current.subscription_id
}

output "eventhub_namespace_names" {
  description = "The list of Event Hub namespaces."
  value       = "${module.eventhubs_in.eventhub_namespace_name} ${module.eventhubs_adt.eventhub_namespace_name} ${module.eventhubs_tsi.eventhub_namespace_name}"
}

output "digital_twins_explorer_url" {
  value       = module.explorer.digital_twins_explorer_url
  description = "The URL of the Azure Digital Twins Explorer webapp."
}

output "digital_twins_service_url" {
  value       = module.digital_twins.service_url
  description = "The URL of the Azure Digital Twins instance service."
}
