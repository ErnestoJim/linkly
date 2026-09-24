output "bucket_name" {
  description = "Bucket a copiar en el `bucket = \"...\"` de infra/envs/*/backend.tf"
  value       = aws_s3_bucket.tf_state.bucket
}
