variable "project" {
  type        = string
  description = "Name of the project"
}

variable "environment" {
  type        = string
  description = "Deployment environment name"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod"
  }
}

variable "aws_region" {
  type        = string
  description = "Resources deployment region"
}

variable "enable_bucket_versioning" {
  type        = bool
  description = "Enabling bucket versioning"
}

variable "lab" {
  type        = string
  description = "Lab title name"
}