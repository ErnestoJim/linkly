# Ver el mismo comentario en infra/envs/dev/backend.tf.
terraform {
  backend "s3" {
    bucket       = "linkly-tfstate-<ACCOUNT_ID>"
    key          = "prod/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }
}
