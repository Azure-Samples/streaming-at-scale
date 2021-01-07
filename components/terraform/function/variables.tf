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

variable "source_path" {
  type        = string
  description = "Local path to the Azure Function source code."
}

variable "tier" {
  type        = string
  description = "The Azure Function tier."
}

variable "sku" {
  type        = string
  description = "The Azure Function SKU."
}

variable "workers" {
  type        = number
  description = "The number of Azure Function workers."
}

variable "configuration" {
  type        = string
  description = "Build configuration used to compile the Azure Function. Should be 'Debug' or 'Release'."
  default     = "Release"
}

variable "appsettings" {
  type        = map(string)
  description = "App settings strings to add to function configuration."
  default     = {}
}

variable "instrumentation_key" {
  type        = string
  description = "The Application Insights instrumentation key."
}
