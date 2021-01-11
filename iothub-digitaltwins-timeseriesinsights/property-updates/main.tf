# Provides client_id, tenant_id, subscription_id and object_id variables
data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group
  location = var.location
}

module "application_insights" {
  source         = "../../components/terraform/application_insights"
  basename       = var.appname
  resource_group = azurerm_resource_group.main.name
  location       = azurerm_resource_group.main.location
}

module "iothub" {
  source         = "../../components/terraform/iothub"
  basename       = "${var.appname}in"
  resource_group = azurerm_resource_group.main.name
  location       = azurerm_resource_group.main.location
  sku            = var.iothub_sku
  capacity       = var.iothub_capacity
}

module "function_adt" {
  source         = "../../components/terraform/function"
  basename       = "${var.appname}in"
  resource_group = azurerm_resource_group.main.name
  location       = azurerm_resource_group.main.location
  source_path    = abspath("../src/EventHubToDigitalTwins")
  tier           = "ElasticPremium"
  sku            = var.function_sku
  workers        = var.function_workers

  instrumentation_key = module.application_insights.instrumentation_key

  appsettings = {
    EVENT_HUB       = module.iothub.listen_event_hubs_primary_connection_string
    ADT_SERVICE_URL = module.digital_twins.service_url
  }
}

resource "azurerm_role_assignment" "main" {
  scope                = module.digital_twins.digital_twins_instance_resource_id
  role_definition_name = "Azure Digital Twins Data Owner"
  principal_id         = module.function_adt.system_assigned_identity.principal_id
}

module "digital_twins" {
  source                               = "../../components/terraform/digital_twins"
  basename                             = "${var.appname}dt"
  resource_group                       = azurerm_resource_group.main.name
  location                             = azurerm_resource_group.main.location
  eventhub_primary_connection_string   = module.eventhubs_adt.send_primary_connection_string
  eventhub_secondary_connection_string = module.eventhubs_adt.send_secondary_connection_string
  owner_principal_object_id            = data.azurerm_client_config.current.object_id

  event_hubs_route_filter = "type = 'Microsoft.DigitalTwins.Twin.Update'"
}

module "eventhubs_adt" {
  source         = "../../components/terraform/eventhubs"
  basename       = "${var.appname}dt"
  resource_group = azurerm_resource_group.main.name
  location       = azurerm_resource_group.main.location
}

module "function_updates_to_tsi" {
  source         = "../../components/terraform/function"
  basename       = "${var.appname}uts"
  resource_group = azurerm_resource_group.main.name
  location       = azurerm_resource_group.main.location
  source_path    = abspath("../src/DigitalTwinsUpdatesToTimeSeriesInsightsEvents")
  tier           = "ElasticPremium"
  sku            = var.function_sku
  workers        = var.function_workers

  instrumentation_key = module.application_insights.instrumentation_key

  appsettings = {
    EVENT_HUB_ADT = module.eventhubs_adt.listen_primary_connection_string
    EVENT_HUB_TSI = module.eventhubs_tsi.send_primary_connection_string
  }
}

module "eventhubs_tsi" {
  source         = "../../components/terraform/eventhubs"
  basename       = "${var.appname}ts"
  resource_group = azurerm_resource_group.main.name
  location       = azurerm_resource_group.main.location
}

module "time_series_insights" {
  source                     = "../../components/terraform/time_series_insights"
  basename                   = var.appname
  resource_group             = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  reader_principal_object_id = data.azurerm_client_config.current.object_id
  eventhub_namespace_name    = module.eventhubs_tsi.eventhub_namespace_name
  eventhub_name              = module.eventhubs_tsi.eventhub_name
}
