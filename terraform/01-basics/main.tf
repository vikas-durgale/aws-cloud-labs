resource "aws_s3_bucket" "s3_lab" {
  bucket = "vikas-tf01-24102026"

  tags = {
    Lab = "tf-01"
  }
}