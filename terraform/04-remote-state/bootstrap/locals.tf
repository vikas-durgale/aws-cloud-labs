locals {
  bucket_name = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Lab         = var.lab
  }
}