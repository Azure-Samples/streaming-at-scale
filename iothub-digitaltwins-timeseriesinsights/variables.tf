variable "appname" {
  type        = string
  description = "Application name. Use only lowercase letters and numbers"
}

variable "location" {
  type        = string
  description = "Azure region where to create resources."
  default     = "eastus"
}

variable "resource_group" {
  type        = string
  description = "Resource group to deploy in."
}

variable "IoTHubToDigitalTwins_function_name" {
  type    = string
  default = "IoTHubToDigitalTwins"
}

