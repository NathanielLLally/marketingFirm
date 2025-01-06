variable "billing_account" {
  description = "The ID of the billing account to associate projects with"
  type        = string
  default     = "0173E5-A648AA-AC3F08"
}

variable "org_id" {
  description = "The organization id for the associated resources"
  type        = string
  default     = "568120179692"
}

variable "billing_project" {
  description = "The project id to use for billing"
  type        = string
  default     = "cs-host-8b8c13d9685d4174ac38e8"
}

variable "folders" {
  description = "Folder structure as a map"
  type        = map
}
