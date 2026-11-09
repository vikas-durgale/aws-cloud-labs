data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

data "aws_iam_policy_document" "lab_reader_trust" {
  statement {
    sid     = "AllowSSOAdminAssume"
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "AWS"
      identifiers = [local.root_account_arn]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:PrincipalArn"
      values   = [data.aws_iam_session_context.current.issuer_arn]
    }
  }
}

data "aws_iam_policy_document" "lab_reader_s3_read" {
  statement {
    sid       = "AllowKMSDecrypt"
    actions   = ["kms:Decrypt"]
    effect    = "Allow"
    resources = [aws_kms_key.lab.arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${data.aws_region.current.region}.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lab_bucket_policy" {
  statement {
    sid       = "AllowLabReaderGetObject"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.lab.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.lab_reader.arn]
    }
  }
}