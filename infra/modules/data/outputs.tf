output "db_address" {
  value = aws_db_instance.this.address
}

output "db_port" {
  value = aws_db_instance.this.port
}

output "db_secret_arn" {
  description = "Secrets Manager: credenciales de Postgres gestionadas por AWS"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "sqs_queue_url" {
  value = aws_sqs_queue.clicks.url
}

output "sqs_queue_arn" {
  value = aws_sqs_queue.clicks.arn
}

output "sqs_dlq_arn" {
  value = aws_sqs_queue.dlq.arn
}
