output "ec2_role_arn" {
  description = "ARN of the EC2 IAM role"
  value       = aws_iam_role.ec2.arn
}

output "instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2.name
}

output "bucket_name" {
  description = "Name of the lab S3 bucket"
  value       = aws_s3_bucket.lab.bucket
}

output "log_group_name" {
  description = "Name of the EC2 CloudWatch log group"
  value       = aws_cloudwatch_log_group.ec2.name
}