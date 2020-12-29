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

variable "capacity" {
  type        = number
  default     = 1
  description = "Event hub namespace capacity."
}

variable "partition_count" {
  type        = number
  default     = 2
  description = "Event hub partition count."
}
