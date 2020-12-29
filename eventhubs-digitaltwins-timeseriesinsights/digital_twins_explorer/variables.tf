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

variable "container_registry_resource_id" {
  type = string
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

variable "instrumentation_key" {
  type        = string
  description = "The Application Insights instrumentation key."
}

variable "digital_twins_instance_resource_id" {
  type        = string
  description = "The ARM Resource ID of the Azure Digital Twins service."
}
