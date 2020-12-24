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

variable "configuration" {
  type        = string
  description = "Build configuration used to compile the Azure Function. Should be 'Debug' or 'Release'."
  default     = "Release"
}

variable "appsettings" {
  type        = map(any)
  description = "App settings strings to add to function configuration."
  default     = {}
}
