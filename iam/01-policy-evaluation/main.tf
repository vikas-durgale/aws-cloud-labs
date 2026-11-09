resource "aws_iam_role" "lab_reader" {
  name               = "${local.name_prefix}-reader"
  description        = "IAM-01 test principal for policy-evaluation break-and-fix; assumed from SSO admin"
  assume_role_policy = data.aws_iam_policy_document.lab_reader_trust.json
}

resource "aws_kms_key" "lab" {
  description             = "KMS key for ${local.name_prefix}"
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "lab" {
  name          = "alias/${local.name_prefix}"
  target_key_id = aws_kms_key.lab.key_id
}

resource "aws_s3_bucket" "lab" {
  bucket = local.bucket_name
  tags = {
    Name = local.bucket_name
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lab" {
  bucket = aws_s3_bucket.lab.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.lab.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "lab" {
  bucket = aws_s3_bucket.lab.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "test_file" {
  depends_on = [aws_s3_bucket_server_side_encryption_configuration.lab]
  bucket     = aws_s3_bucket.lab.id
  key        = "lab_test.txt"
  content    = "Hello, from Terraform!"
}

resource "aws_iam_role_policy" "lab_reader_s3_read" {
  name   = "${local.name_prefix}-s3-read"
  role   = aws_iam_role.lab_reader.id
  policy = data.aws_iam_policy_document.lab_reader_s3_read.json
}

resource "aws_s3_bucket_policy" "lab" {
  bucket = aws_s3_bucket.lab.id
  policy = data.aws_iam_policy_document.lab_bucket_policy.json
}