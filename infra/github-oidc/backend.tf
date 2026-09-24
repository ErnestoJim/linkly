# Ver el mismo comentario en infra/envs/dev/backend.tf. Corre
# infra/bootstrap primero para tener el bucket.
terraform {
  backend "s3" {
    bucket       = "linkly-tfstate-<ACCOUNT_ID>"
    key          = "github-oidc/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }
}
