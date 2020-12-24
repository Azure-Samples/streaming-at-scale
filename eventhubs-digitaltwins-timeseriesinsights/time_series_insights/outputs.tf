output "data_access_fqdn" {
  value       = azurerm_iot_time_series_insights_gen2_environment.main.data_access_fqdn
  description = "The Time Series Insights data access host name."
}
