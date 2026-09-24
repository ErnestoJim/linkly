variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type        = string
  description = "Versión de Kubernetes. Usa la penúltima en soporte estándar de EKS (la más probada), no la última."
  default     = "1.35"
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Subredes públicas: el control plane y los nodos viven aquí (sin NAT gateway, ver módulo network)"
}

variable "allowed_public_access_cidrs" {
  type        = list(string)
  description = "CIDRs con permiso para llegar al endpoint público del cluster (tu IP, p.ej. [\"1.2.3.4/32\"]). Vacío = nadie puede acceder."
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
