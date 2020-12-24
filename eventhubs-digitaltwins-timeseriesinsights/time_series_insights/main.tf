resource "azurerm_storage_account" "time_series_insights" {
  name                     = "st${var.basename}tsi"
  location                 = var.location
  resource_group_name      = var.resource_group
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_iot_time_series_insights_gen2_environment" "main" {
  name                = "tsi-${var.basename}"
  location            = var.location
  resource_group_name = var.resource_group
  sku_name            = "L1"
  id_properties       = var.id_properties
  storage {
    name = azurerm_storage_account.time_series_insights.name
    key  = azurerm_storage_account.time_series_insights.primary_access_key
  }
}

resource "azurerm_iot_time_series_insights_access_policy" "name" {
  name                                = "deployer"
  time_series_insights_environment_id = azurerm_iot_time_series_insights_gen2_environment.main.id

  principal_object_id = var.reader_principal_object_id
  roles               = ["Reader"]
}

resource "azurerm_eventhub_consumer_group" "main" {
  name                = "TSI"
  namespace_name      = var.eventhub_namespace_name
  eventhub_name       = var.eventhub_name
  resource_group_name = var.resource_group
}

resource "azurerm_eventhub_authorization_rule" "listen" {
  name                = "TSI-Listen"
  namespace_name      = var.eventhub_namespace_name
  eventhub_name       = var.eventhub_name
  resource_group_name = var.resource_group
  listen              = true
  send                = false
  manage              = false
}

# Create Event Source for event hubs ingestion with Azure CLI
# https://github.com/terraform-providers/terraform-provider-azurerm/issues/7053
resource "null_resource" "tsi_eventhubs_ingestion" {
  provisioner "local-exec" {
    command = <<-EOT
      az extension add -n timeseriesinsights
      az timeseriesinsights event-source eventhub create -g ${var.resource_group} --environment-name ${azurerm_iot_time_series_insights_gen2_environment.main.name} -n es1 --key-name ${azurerm_eventhub_authorization_rule.listen.name} --shared-access-key ${azurerm_eventhub_authorization_rule.listen.primary_key} --event-source-resource-id ${azurerm_eventhub_authorization_rule.listen.id} --consumer-group-name '${azurerm_eventhub_consumer_group.main.name}' --timestamp-property-name '${var.timestamp_property_name}'
      EOT
  }
}
