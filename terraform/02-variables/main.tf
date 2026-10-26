resource "aws_s3_bucket" "s3_lab" {
  bucket = local.name_prefix
  tags = {
    Name = local.name_prefix
  }
}

resource "aws_s3_bucket_versioning" "versioining_lab" {
  bucket = aws_s3_bucket.s3_lab.id

  versioning_configuration {
    status = var.enable_bucket_versioning ? "Enabled" : "Suspended"
  }
}