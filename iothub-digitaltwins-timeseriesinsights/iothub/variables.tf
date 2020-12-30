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

variable "sku" {
  type        = string
  description = "The IoT Hub SKU name."
}

variable "capacity" {
  type        = number
  default     = 1
  description = "The number of provisioned IoT Hub units."
}

variable "partition_count" {
  type        = number
  default     = 2
  description = "Backing event hub partition count."
}
