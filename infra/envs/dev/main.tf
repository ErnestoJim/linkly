terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "linkly"
      Env       = "dev"
      ManagedBy = "terraform"
    }
  }
}

locals {
  name = "linkly-dev"
}

module "network" {
  source = "../../modules/network"
  name   = local.name
}

module "eks" {
  source = "../../modules/eks"

  cluster_name                = local.name
  vpc_id                      = module.network.vpc_id
  public_subnet_ids           = module.network.public_subnet_ids
  allowed_public_access_cidrs = var.allowed_public_access_cidrs
}

module "data" {
  source = "../../modules/data"

  name                   = local.name
  vpc_id                 = module.network.vpc_id
  private_subnet_ids     = module.network.private_subnet_ids
  node_security_group_id = module.eks.node_security_group_id
}

module "iam" {
  source = "../../modules/iam"

  cluster_name  = module.eks.cluster_name
  sqs_queue_arn = module.data.sqs_queue_arn
}
