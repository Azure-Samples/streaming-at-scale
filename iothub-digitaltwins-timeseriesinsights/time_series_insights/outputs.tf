output "data_access_fqdn" {
  value       = azurerm_iot_time_series_insights_gen2_environment.main.data_access_fqdn
  description = "The Time Series Insights data access host name."
}

output "name" {
  value       = azurerm_iot_time_series_insights_gen2_environment.main.name
  description = "The Time Series Insights ARM Resource name."
}

output "storage_account_name" {
  value       = azurerm_storage_account.time_series_insights.name
  description = "The Time Series Insights long-term data storage account ARM Resource name."
}
