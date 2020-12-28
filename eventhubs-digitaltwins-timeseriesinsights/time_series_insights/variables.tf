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

variable "reader_principal_object_id" {
  type        = string
  description = "Azure AD Object ID of the user to be assigned Reader role into the Time Series Insights instance."
}

variable "id_properties" {
  type        = list(string)
  default     = ["$dtId"]
  description = "List of inbound message properties making up the Time Series Insights device identifier."
}

variable "timestamp_property_name" {
  type        = string
  default     = "createdAt"
  description = "Inbound message property defining the Time Series Insights event timestamp."
}

variable "eventhub_namespace_name" {
  type        = string
  description = "The event hub namespace from which to read messages into Time Series Insights."
}

variable "eventhub_name" {
  type        = string
  description = "The event hub name from which to read messages into Time Series Insights."
}
