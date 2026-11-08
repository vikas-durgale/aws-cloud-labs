resource "aws_s3_bucket" "s3_lock_test" {
  bucket = local.bucket_name
  tags = {
    Name = local.bucket_name
  }
}
