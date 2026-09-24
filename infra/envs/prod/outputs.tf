output "cluster_name" {
  value = module.eks.cluster_name
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

output "db_address" {
  value = module.data.db_address
}

output "db_secret_arn" {
  value = module.data.db_secret_arn
}

output "sqs_queue_url" {
  value = module.data.sqs_queue_url
}
