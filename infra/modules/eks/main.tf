# Cluster EKS con un managed node group spot en subredes públicas (mismo
# motivo que enable_nat_gateway=false en el módulo network: sin NAT, los
# nodos necesitan salida directa a internet vía Internet Gateway).

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.public_subnet_ids

  endpoint_public_access       = true
  endpoint_private_access      = false
  endpoint_public_access_cidrs = var.allowed_public_access_cidrs

  addons = {
    vpc-cni                = {}
    coredns                = {}
    kube-proxy             = {}
    eks-pod-identity-agent = {}
  }

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium", "t3a.medium"]
      capacity_type  = "SPOT"

      min_size     = 2
      max_size     = 2
      desired_size = 2

      subnet_ids = var.public_subnet_ids
    }
  }

  tags = var.tags
}
