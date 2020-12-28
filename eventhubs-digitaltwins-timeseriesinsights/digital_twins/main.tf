locals {
  build = abspath("${path.module}/target")
}

resource "azurerm_storage_account" "time_series_insights" {
  name                     = "st${var.basename}tsi"
  location                 = var.location
  resource_group_name      = var.resource_group
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_digital_twins_instance" "main" {
  name                = "dt-${var.basename}"
  location            = var.location
  resource_group_name = var.resource_group
}

resource "azurerm_digital_twins_endpoint_eventhub" "main" {
  name                                 = "EventHub"
  digital_twins_id                     = azurerm_digital_twins_instance.main.id
  eventhub_primary_connection_string   = var.eventhub_primary_connection_string
  eventhub_secondary_connection_string = var.eventhub_secondary_connection_string
}

resource "azurerm_role_assignment" "owner" {
  scope                = azurerm_digital_twins_instance.main.id
  role_definition_name = "Azure Digital Twins Data Owner"
  principal_id         = var.owner_principal_object_id
}

# Create ADT route to Event Hubs using Azure CLI (not currently supported in Terraform)
resource "null_resource" "tsi_eventhubs_ingestion_route" {
  triggers = {
    twins    = azurerm_digital_twins_instance.main.name
    endpoint = azurerm_digital_twins_endpoint_eventhub.main.name
  }
  provisioner "local-exec" {
    command = <<-EOT
      az extension add -n azure-iot
      az dt route create -n ${self.triggers.twins} --endpoint-name ${self.triggers.endpoint} --route-name EHRoute --filter "type = 'Microsoft.DigitalTwins.Twin.Update'" -o none
      EOT
  }
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      az extension add -n azure-iot
      az dt route delete -n ${self.triggers.twins} --route-name EHRoute -o none
      EOT
  }
  depends_on = [
    azurerm_role_assignment.owner,
  ]
}
