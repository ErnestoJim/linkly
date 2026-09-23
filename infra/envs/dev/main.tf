terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "linkly-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "linkly-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}

# module "network" { source = "../../modules/network" }
# module "eks"     { source = "../../modules/eks" }
# module "rds"     { source = "../../modules/rds" }
# module "sqs"     { source = "../../modules/sqs" }
# module "iam"     { source = "../../modules/iam" }
