locals {
  name_prefix = "${var.project}-${var.lab}-${var.environment}-${data.aws_caller_identity.current.account_id}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Lab         = var.lab
  }
}