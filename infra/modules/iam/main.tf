# EKS Pod Identity: le da permisos de AWS a los pods sin claves de larga
# duración y sin el lío de OIDC/IRSA — solo un rol + una asociación por
# ServiceAccount. Necesita el addon eks-pod-identity-agent (ver módulo
# eks) instalado en el cluster.

data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

# --- worker: consume la cola -------------------------------------------

resource "aws_iam_role" "worker" {
  name               = "${var.cluster_name}-linkly-worker"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "worker_sqs" {
  statement {
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage"]
    resources = [var.sqs_queue_arn]
  }
}

resource "aws_iam_role_policy" "worker_sqs" {
  role   = aws_iam_role.worker.id
  policy = data.aws_iam_policy_document.worker_sqs.json
}

resource "aws_eks_pod_identity_association" "worker" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = "linkly-worker"
  role_arn        = aws_iam_role.worker.arn
}

# --- api: publica en la cola --------------------------------------------

resource "aws_iam_role" "api" {
  name               = "${var.cluster_name}-linkly-api"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "api_sqs" {
  statement {
    actions   = ["sqs:SendMessage"]
    resources = [var.sqs_queue_arn]
  }
}

resource "aws_iam_role_policy" "api_sqs" {
  role   = aws_iam_role.api.id
  policy = data.aws_iam_policy_document.api_sqs.json
}

resource "aws_eks_pod_identity_association" "api" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = "linkly-api"
  role_arn        = aws_iam_role.api.arn
}
