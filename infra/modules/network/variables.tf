variable "name" {
  type        = string
  description = "Nombre del entorno (p.ej. linkly-dev) — también el nombre esperado del cluster EKS"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "tags" {
  type    = map(string)
  default = {}
}
