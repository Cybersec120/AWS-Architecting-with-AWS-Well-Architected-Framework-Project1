###############################################################
# Project 1: Operational Excellence — Production Static Website
# AWS Well-Architected Framework — Operational Excellence Pillar
# Author: Portfolio Project
###############################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment this block when you have an S3 backend configured
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "project1/operational-excellence/terraform.tfstate"
  #   region         = var.aws_region
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "operational-excellence"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
      Pillar      = "operational-excellence"
    }
  }
}

# Second provider for us-east-1 — required for CloudFront ACM certificates
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "operational-excellence"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
      Pillar      = "operational-excellence"
    }
  }
}
