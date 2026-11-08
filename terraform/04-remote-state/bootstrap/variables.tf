variable "aws_region" {
  type        = string
  description = "Resources deployment region"
}

variable "project" {
  type        = string
  description = "Project title"
}

variable "environment" {
  type        = string
  description = "Resource deployment environment"

  validation {
    condition     = contains(["dev", "prod", "shared"], var.environment)
    error_message = "environment must be dev, prod, or shared"
  }
}

variable "lab" {
  type        = string
  description = "Lab title"
}

variable "expire_noncurrent_versions_status" {
  type        = bool
  description = "Status to expire noncurrent versions"
}

variable "expire_noncurrent_versions_days" {
  type        = number
  description = "Days to set for noncurrent versions expiry"
}