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
resource "null_resource" "tsi_eventhubs_ingestion" {
  provisioner "local-exec" {
    command = <<-EOT
      az extension add -n azure-iot
      az dt route create -n ${azurerm_digital_twins_instance.main.name} --endpoint-name ${azurerm_digital_twins_endpoint_eventhub.main.name} --route-name EHRoute --filter "type = 'Microsoft.DigitalTwins.Twin.Update'"
      EOT
  }
  depends_on = [
    azurerm_role_assignment.owner,
  ]
}

resource "null_resource" "upload_models" {
  provisioner "local-exec" {
    command = <<-EOT
      az dt model create -n ${azurerm_digital_twins_instance.main.name} --models ./models/TemperatureSensorInterface.json
      az dt model create -n ${azurerm_digital_twins_instance.main.name} --models ./models/CO2SensorInterface.json
      for i in $(seq 1 5); do 
        az dt twin create -n ${azurerm_digital_twins_instance.main.name} --dtmi "dtmi:com:microsoft:azure:samples:streamingatscale:dt:tempsensor;1" --twin-id "device-id-$i-temp"
        az dt twin create -n ${azurerm_digital_twins_instance.main.name} --dtmi "dtmi:com:microsoft:azure:samples:streamingatscale:dt:co2sensor;1" --twin-id "device-id-$i-co2"
      done
      EOT
  }
  depends_on = [
    azurerm_role_assignment.owner,
  ]
}