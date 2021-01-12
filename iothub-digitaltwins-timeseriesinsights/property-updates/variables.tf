variable "appname" {
  type        = string
  description = "Application name. Use only lowercase letters and numbers"
}

variable "location" {
  type        = string
  description = "Azure region where to create resources."
  default     = "eastus"
}

variable "resource_group" {
  type        = string
  description = "Resource group to deploy in."
}

variable "iothub_sku" {
  type        = string
  default     = "S1"
  description = "The IoT Hub SKU name."
}

variable "iothub_capacity" {
  type        = number
  default     = 1
  description = "The number of IoT hub units."
}

variable "function_sku" {
  type        = string
  default     = "EP1"
  description = "The Azure Function SKU."
}

variable "function_workers" {
  type        = number
  default     = 1
  description = "The number of Azure Function workers."
}
