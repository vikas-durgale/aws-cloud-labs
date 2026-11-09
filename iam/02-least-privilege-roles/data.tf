data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    sid     = "AllowEC2AssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ec2_permissions" {
  statement {
    sid       = "ReadAppConfig"
    actions   = ["s3:GetObject"]
    effect    = "Allow"
    resources = ["${aws_s3_bucket.lab.arn}/config/*"]
  }

  statement {
    sid = "WriteAppLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect    = "Allow"
    resources = ["${aws_cloudwatch_log_group.ec2.arn}:*"]
  }
}