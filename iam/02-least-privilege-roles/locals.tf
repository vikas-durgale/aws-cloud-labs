locals {
  name_prefix = "${var.project}-${var.lab}"
  bucket_name = "${local.name_prefix}-${data.aws_caller_identity.current.account_id}"

  function_name       = "${local.name_prefix}-function"
  dynamodb_table_name = "${local.name_prefix}-table"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Lab         = var.lab
  }
}