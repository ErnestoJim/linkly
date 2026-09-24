# Bootstrapa el bucket S3 usado como backend remoto de Terraform para
# infra/envs/*. Se corre una sola vez, a mano, antes del primer
# `terraform init` en cualquier entorno.
#
# Desde Terraform 1.10, el backend "s3" soporta locking nativo
# (`use_lockfile = true`) usando el propio bucket — ya no hace falta una
# tabla de DynamoDB aparte para los locks.

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
}

data "aws_caller_identity" "current" {}

locals {
  # El nombre del bucket incluye el account id para que sea único
  # globalmente sin tener que inventarse un sufijo random.
  bucket_name = "linkly-tfstate-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "tf_state" {
  bucket = local.bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
