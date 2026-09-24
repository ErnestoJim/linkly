output "role_arn" {
  description = "Pégalo en el repo variable AWS_GITHUB_ACTIONS_ROLE_ARN (Settings > Secrets and variables > Actions > Variables)"
  value       = aws_iam_role.github_actions.arn
}
