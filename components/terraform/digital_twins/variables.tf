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

variable "eventhub_primary_connection_string" {
  type        = string
  description = "Primary connection string of the Event Hub to which ADT data is sent. Requires Send permission."
}

variable "eventhub_secondary_connection_string" {
  type        = string
  description = "Secondary connection string of the Event Hub to which ADT data is sent. Requires Send permission."
}

variable "owner_principal_object_id" {
  type        = string
  description = "Azure AD Object ID of the user to be assigned Azure Digital Twins Data Owner role to."
}

variable "event_hubs_route_filter" {
  type        = string
  description = "ADT filter expression for events routed to Event Hubs. See https://docs.microsoft.com/en-us/azure/digital-twins/how-to-manage-routes-apis-cli#filter-events"
}
