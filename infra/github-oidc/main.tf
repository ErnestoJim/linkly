# OIDC provider de GitHub Actions + el rol que CI asume vía
# aws-actions/configure-aws-credentials — sin access keys de larga
# duración guardadas como secret. Proyecto aparte (como infra/bootstrap):
# se corre una sola vez, a mano, después de bootstrap.

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

# Desde 2025 AWS valida los proveedores OIDC conocidos (GitHub incluido)
# contra su propio almacén de CAs de confianza; thumbprint_list ya no
# hace falta.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Dos casos, no uno: `terraform plan` en pull_request (el token de
    # GitHub trae sub=repo:.../pull_request, sin ref de rama) y el
    # `apply` manual por workflow_dispatch (sub=repo:.../ref:refs/heads/main).
    # Con solo el segundo patrón (como en el enunciado original), el
    # plan en PRs nunca podría autenticarse.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repo}:ref:refs/heads/main",
        "repo:${var.github_repo}:pull_request",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-linkly"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

# Deliberadamente amplio: este rol hace `plan`/`apply` de un stack que
# toca EC2 (VPC), EKS, RDS, SQS e IAM (roles de Pod Identity) — acotarlo
# a los verbos exactos que hace falta es un ejercicio de iterar contra
# AccessDenied, no algo que se pueda adivinar de antemano. Para un uso
# real, este es el primer sitio a estrechar.
data "aws_iam_policy_document" "deploy" {
  statement {
    sid = "BroadDeploy"
    actions = [
      "ec2:*",
      "eks:*",
      "rds:*",
      "sqs:*",
      "iam:*",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "TerraformState"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [
      "arn:aws:s3:::${var.state_bucket_name}",
      "arn:aws:s3:::${var.state_bucket_name}/*",
    ]
  }
}

resource "aws_iam_role_policy" "deploy" {
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.deploy.json
}
