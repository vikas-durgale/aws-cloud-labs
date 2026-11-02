moved {
  from = aws_s3_bucket_versioning.versioining_lab
  to   = aws_s3_bucket_versioning.versioning_lab
}

import {
  to = aws_s3_bucket.imported_bucket
  id = local.import_bucket_name
}

resource "aws_s3_bucket" "s3_lab" {
  bucket = local.name_prefix
  tags = {
    Name = local.name_prefix
  }
}

resource "aws_s3_bucket_versioning" "versioning_lab" {
  bucket = aws_s3_bucket.s3_lab.id

  versioning_configuration {
    status = var.enable_bucket_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket" "imported_bucket" {
  bucket = local.import_bucket_name
}