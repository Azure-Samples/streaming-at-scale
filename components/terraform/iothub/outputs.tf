locals {
  # Keys to predefined access policies
  # see https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-security#access-control-and-permissions
  sendPolicy          = "device"
  listenPolicy        = "service"
  registryWritePolicy = "registryReadWrite"
}

output "name" {
  value       = azurerm_iothub.main.name
  description = "The IoT Hub ARM Resource name."
}

output "resource_id" {
  value       = azurerm_iothub.main.id
  description = "The ARM Resource ID of the IoT Hub."
}

output "send_primary_connection_string" {
  value       = "HostName=${azurerm_iothub.main.hostname};SharedAccessKeyName=${local.sendPolicy};SharedAccessKey=${azurerm_iothub.main.shared_access_policy[index(azurerm_iothub.main.shared_access_policy.*.key_name, local.sendPolicy)].primary_key}"
  description = "The primary connection string to send events."
  sensitive   = true
}

output "listen_event_hubs_primary_connection_string" {
  value       = "Endpoint=${azurerm_iothub.main.event_hub_events_endpoint};SharedAccessKeyName=${local.listenPolicy};SharedAccessKey=${azurerm_iothub.main.shared_access_policy[index(azurerm_iothub.main.shared_access_policy.*.key_name, local.listenPolicy)].primary_key};EntityPath=${azurerm_iothub.main.event_hub_events_path}"
  description = "The primary connection string to receive events."
  sensitive   = true
}
