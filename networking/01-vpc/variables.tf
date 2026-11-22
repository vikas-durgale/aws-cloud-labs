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
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod"
  }
}

variable "lab" {
  type        = string
  description = "Lab title"
}