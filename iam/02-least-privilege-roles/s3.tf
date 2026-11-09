resource "aws_s3_bucket" "lab" {
  bucket        = local.bucket_name
  force_destroy = true

  tags = {
    Name = local.bucket_name
  }
}

resource "aws_s3_bucket_public_access_block" "lab" {
  bucket = aws_s3_bucket.lab.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lab" {
  bucket = aws_s3_bucket.lab.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "config_file" {
  depends_on = [aws_s3_bucket_server_side_encryption_configuration.lab]
  bucket     = aws_s3_bucket.lab.id
  key        = "config/app.json"
  content    = jsonencode({ lab = var.lab })
}

resource "aws_s3_object" "secret_file" {
  depends_on = [aws_s3_bucket_server_side_encryption_configuration.lab]
  bucket     = aws_s3_bucket.lab.id
  key        = "secret/cred.txt"
  content    = "Test secret"
}