# VPC con 2 AZs: subredes públicas (nodos EKS) y privadas aisladas
# (RDS, sin salida a internet). enable_nat_gateway = false a propósito —
# ver docs/adr/0002-no-nat-gateway.md.

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = var.name
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = [for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnets = [for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, 4, i + length(local.azs))]

  enable_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Mismo valor que se pasa como `cluster_name` al módulo eks (ver
  # infra/envs/dev/main.tf) — así el auto-discovery del AWS Load Balancer
  # Controller / in-tree ELB provisioning encuentra las subredes.
  public_subnet_tags = {
    "kubernetes.io/role/elb"            = "1"
    "kubernetes.io/cluster/${var.name}" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"   = "1"
    "kubernetes.io/cluster/${var.name}" = "shared"
  }

  tags = var.tags
}
