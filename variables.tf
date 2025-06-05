variable "labelPrefix" {
  description = "Prefix used for naming Azure resources"
  type        = string
  default     = "alkh0115"
}

variable "region" {
  description = "Azure region to deploy resources"
  type        = string
  default     = "canadacentral"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureadmin"
}
