variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "allowed_public_access_cidrs" {
  type        = list(string)
  description = "IPs con permiso para llegar al endpoint del cluster. Vacío = nadie puede acceder."
  default     = []
}
