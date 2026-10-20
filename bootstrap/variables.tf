variable "aws_region" {
  description = "Região da AWS para o provisionamento do backend Terraform"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente de infraestrutura (ex: production, staging)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Nome do projeto para identificação e tagging dos recursos"
  type        = string
  default     = "AutoReparos"
}

variable "state_bucket_name" {
  description = "Nome do bucket S3 para armazenamento do Terraform State compartilhado"
  type        = string
  default     = "autoreparos-terraform-state-backend"
}

variable "lock_table_name" {
  description = "Nome da tabela DynamoDB para controle de lock do Terraform State"
  type        = string
  default     = "autoreparos-terraform-locks"
}
