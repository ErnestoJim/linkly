output "worker_role_arn" {
  value = aws_iam_role.worker.arn
}

output "api_role_arn" {
  value = aws_iam_role.api.arn
}
