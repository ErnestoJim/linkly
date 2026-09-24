variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "node_security_group_id" {
  type        = string
  description = "Security group de los nodos EKS (módulo eks) — es el único origen permitido hacia Postgres"
}

variable "tags" {
  type    = map(string)
  default = {}
}
