output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "node_security_group_id" {
  description = "Para el security group de RDS: solo acepta tráfico desde los nodos"
  value       = module.eks.node_security_group_id
}
