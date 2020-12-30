output "instrumentation_key" {
  value       = azurerm_application_insights.main.instrumentation_key
  description = "The Application Insights instrumentation key."
  sensitive   = true
}
