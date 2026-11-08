locals {
  bucket_name = "${var.project}-${var.lab}-${data.aws_caller_identity.current.account_id}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Lab         = var.lab
    Purpose     = "lock-test"
  }
}