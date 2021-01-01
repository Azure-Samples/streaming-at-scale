variable "basename" {
  type        = string
  description = "Base name. Use only lowercase letters and numbers"
}

variable "location" {
  type        = string
  description = "Azure region where to create resources."
}

variable "resource_group" {
  type        = string
  description = "Resource group to deploy in."
}

variable "iothub_connectionstring" {
  type        = string
  description = "Connection string of the IoT Hub to send data to. Requires Send permission."
}

variable "device_count" {
  type        = number
  description = "Number of simulated devices."
}

variable "interval" {
  type        = number
  description = "Interval between events per device [milliseconds]."
}

variable "device_prefix" {
  type        = string
  default     = "contoso-device-id-"
  description = "Prefix before device name. Device name will be formed by appending six digits, e.g. 000001."
}

variable "container_registry_name" {
  type        = string
  description = "Container registry to use for building image."
}

variable "container_registry_admin_username" {
  type        = string
  description = "The container registry admin username."
}

variable "container_registry_admin_password" {
  type        = string
  description = "The container registry admin password."
}

variable "container_registry_login_server" {
  type        = string
  description = "The container registry login server."
}

variable "source_code" {
  type        = string
  default     = "https://github.com/algattik/Iot-Telemetry-Simulator"
  description = "Path to the Simulator source."
}
