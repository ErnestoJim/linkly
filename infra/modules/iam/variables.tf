variable "cluster_name" {
  type = string
}

variable "namespace" {
  type        = string
  description = "Namespace de Kubernetes donde vive el release de Helm (ver deploy/helm/linkly)"
  default     = "linkly"
}

variable "sqs_queue_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
