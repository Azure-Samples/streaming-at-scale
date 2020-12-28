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

variable "container_registry_name" {
  type        = string
  description = "Container registry to use for building image."
}

variable "container_registry_admin_username" {
  type        = string
  description = "The container registry admin username."
}

variable "container_registry_admin_password" {
  type        = string
  description = "The container registry admin password."
}

variable "container_registry_login_server" {
  type        = string
  description = "The container registry login server."
}

variable "eventhub_connectionstring" {
  type        = string
  description = "Connection string of the Event Hub to send data to. Requires Send permission."
}

variable "events_per_second" {
  type        = number
  default     = 1000
  description = "Number of events per second to send."
}

variable "duplicate_every_n_events" {
  type        = number
  default     = 1000
  description = "Frequency of duplicate events to send."
}

variable "source_path" {
  type        = string
  default     = "../simulator/generator"
  description = "Local path to the Simulator source code."
}
