locals {
  # Keys to predefined access policies
  # see https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-security#access-control-and-permissions
  sendPolicy          = "device"
  registryWritePolicy = "registryReadWrite"
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

output "registry_write_primary_connection_string" {
  value       = "HostName=${azurerm_iothub.main.hostname};SharedAccessKeyName=${local.registryWritePolicy};SharedAccessKey=${azurerm_iothub.main.shared_access_policy[index(azurerm_iothub.main.shared_access_policy.*.key_name, local.registryWritePolicy)].primary_key}"
  description = "The primary connection string to send events."
  sensitive   = true
}


