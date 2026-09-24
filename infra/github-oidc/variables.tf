variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "github_repo" {
  type        = string
  description = "owner/repo de GitHub, p.ej. ErnestoJim/linkly"
  default     = "ErnestoJim/linkly"
}

variable "state_bucket_name" {
  type        = string
  description = "Bucket creado por infra/bootstrap (mismo valor que en infra/envs/*/backend.tf)"
}
