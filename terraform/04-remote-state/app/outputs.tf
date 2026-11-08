output "bucket_name" {
  description = "Bucket name"
  value       = aws_s3_bucket.s3_lock_test.bucket
}

output "bucket_arn" {
  description = "Bucket ARN"
  value       = aws_s3_bucket.s3_lock_test.arn
}