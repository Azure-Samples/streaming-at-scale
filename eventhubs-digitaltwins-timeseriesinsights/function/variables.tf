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

variable "appsettings" {
  type        = map(string)
  description = "App settings strings to add to function configuration."
  default     = {}
}

variable "instrumentation_key" {
  type        = string
  description = "The Application Insights instrumentation key."
}
