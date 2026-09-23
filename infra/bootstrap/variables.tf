variable "region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket_name" {
  type        = string
  description = "Globally-unique S3 bucket name for Terraform state"
  default     = "linkly-terraform-state"
}

variable "lock_table_name" {
  type        = string
  description = "DynamoDB table used for Terraform state locking"
  default     = "linkly-terraform-locks"
}
