terraform {
  required_version = ">= 1.10"

  backend "s3" {
    key          = "labs/iam/02-least-privilege-roles/terraform.tfstate"
    use_lockfile = true
    encrypt      = true
    region       = "ap-southeast-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.72"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.8"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}