variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "allowed_public_access_cidrs" {
  type        = list(string)
  description = "Tu IP pública (p.ej. [\"1.2.3.4/32\"], mira `curl ifconfig.me`). Vacío = nadie puede llegar al endpoint del cluster."
  default     = []
}
