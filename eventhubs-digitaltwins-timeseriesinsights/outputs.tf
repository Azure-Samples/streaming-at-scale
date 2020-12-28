output "subscription_id" {
  description = "The Azure Subscription identifier."
  value       = data.azurerm_client_config.current.subscription_id
}
