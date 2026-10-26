output "bucket_name" {
  description = "Name of the bucket"
  value       = aws_s3_bucket.s3_lab.bucket
}

output "bucket_arn" {
  description = "ARN of the bucket"
  value       = aws_s3_bucket.s3_lab.arn
}