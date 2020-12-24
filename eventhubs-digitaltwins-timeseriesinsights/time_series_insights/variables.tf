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
  description = "Azure AD Object ID of the user to be assigned Reader role to."
}

variable "id_properties" {
  type    = list(string)
  default = ["deviceId"]
}

variable "timestamp_property_name" {
  type    = string
  default = "createdAt"
}

variable "eventhub_namespace_name" {
  type = string
}

variable "eventhub_name" {
  type = string
}
