resource "aws_s3_bucket" "s3_bootstrap_lab" {
  bucket = local.bucket_name
  tags = {
    Name = local.bucket_name
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "versioning_config" {
  bucket = aws_s3_bucket.s3_bootstrap_lab.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption_config" {
  bucket = aws_s3_bucket.s3_bootstrap_lab.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "bucket_public_access_config" {
  bucket = aws_s3_bucket.s3_bootstrap_lab.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "only_secure_transport" {
  bucket = aws_s3_bucket.s3_bootstrap_lab.id
  policy = data.aws_iam_policy_document.secure_transport.json
}

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle_config" {
  depends_on = [aws_s3_bucket_versioning.versioning_config]
  bucket     = aws_s3_bucket.s3_bootstrap_lab.id
  rule {
    id = "expire_noncurrent_versions"
    filter {}
    status = var.expire_noncurrent_versions_status ? "Enabled" : "Disabled"

    noncurrent_version_expiration {
      noncurrent_days = var.expire_noncurrent_versions_days
    }
  }
}