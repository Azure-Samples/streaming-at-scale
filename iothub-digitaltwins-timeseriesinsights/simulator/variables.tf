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
