variable "appname" {
  type        = string
  description = "Application name. Use only lowercase letters and numbers"
}

variable "location" {
  type        = string
  description = "Azure region where to create resources."
  default     = "westeurope"
}

variable "resource_group" {
  type        = string
  description = "Resource group to deploy in."
}

variable "adt_model_file" {
  type        = string
  default     = "models/digital_twin_types.json"
  description = "File containing DTDL model definitions."
}

variable "tsi_types_file" {
  type        = string
  default     = "models/time_series_insights_types.json"
  description = "File containing Time Series Insights type definitions."
}

variable "tsi_hierarchies_file" {
  type        = string
  default     = "models/time_series_insights_hierarchies.json"
  description = "File containing Time Series Insights hierarchy definitions."
}
