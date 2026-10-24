terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.70" # check registry.terraform.io for the current major
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = {
      Project   = "aws-cloud-labs"
      ManagedBy = "terraform"
    }
  }
}