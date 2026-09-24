# Bucket creado por infra/bootstrap (ejecútalo primero). Los bloques
# `backend` no admiten variables ni data sources, así que el nombre va
# literal aquí: reemplaza <ACCOUNT_ID> por `terraform output bucket_name`
# en infra/bootstrap (o por tu Account ID de 12 dígitos).
terraform {
  backend "s3" {
    bucket       = "linkly-tfstate-<ACCOUNT_ID>"
    key          = "dev/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true # locking nativo en S3 (Terraform >= 1.10) — sin DynamoDB
    encrypt      = true
  }
}
