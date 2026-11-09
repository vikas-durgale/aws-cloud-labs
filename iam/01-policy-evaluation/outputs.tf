output "role_name" {
  description = "Role name"
  value       = aws_iam_role.lab_reader.name
}

output "role_arn" {
  description = "Role ARN"
  value       = aws_iam_role.lab_reader.arn
}

output "bucket_name" {
  description = "Bucket name"
  value       = aws_s3_bucket.lab.bucket
}

output "object_key" {
  description = "Object Key"
  value       = aws_s3_object.test_file.key
}

output "kms_key_arn" {
  description = "KMS key ARN"
  value       = aws_kms_key.lab.arn
}