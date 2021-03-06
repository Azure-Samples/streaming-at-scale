output "subscription_id" {
  description = "The Azure Subscription identifier."
  value       = data.azurerm_client_config.current.subscription_id
}

output "iothub_resource_id" {
  value       = module.iothub.resource_id
  description = "The ARM Resource ID of the IoT Hub."
}

output "eventhub_namespace_names" {
  description = "The list of Event Hub namespaces."
  value       = module.eventhubs_adt.eventhub_namespace_name
}

output "iothub_name" {
  value       = module.iothub.name
  description = "The IoT Hub ARM Resource name."
}

output "iothub_telemetry_send_primary_connection_string" {
  value       = module.iothub.send_primary_connection_string
  description = "The primary connection string to send events to IoT Hub."
  sensitive   = true
}

output "digital_twins_service_url" {
  value       = module.digital_twins.service_url
  description = "The URL of the Azure Digital Twins instance service."
}

output "time_series_insights_data_access_fqdn" {
  value       = module.time_series_insights.data_access_fqdn
  description = "The Time Series Insights data access host name."
}

output "time_series_insights_name" {
  value       = module.time_series_insights.name
  description = "The Time Series Insights ARM Resource name."
}

output "time_series_insights_storage_account_name" {
  value       = module.time_series_insights.storage_account_name
  description = "The Time Series Insights long-term data storage account ARM Resource name."
}
