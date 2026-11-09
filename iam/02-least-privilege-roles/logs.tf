resource "aws_cloudwatch_log_group" "ec2" {
  name              = "/${var.project}/${var.lab}/ec2"
  retention_in_days = 7
}