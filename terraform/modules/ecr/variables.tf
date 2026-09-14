variable "repository_name" {
  type        = string
  description = "Name of the ECR repository"
  default     = "autoreparos-api"
}

variable "environment" {
  type        = string
  description = "Deployment environment name"
}
