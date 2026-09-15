variable "environment" {
  description = "Ambiente de deploy (ex: production, staging, dev)"
  type        = string
  default     = "production"
}

variable "vpc_id" {
  description = "ID da VPC onde o Security Group do VPC Link será criado"
  type        = string
}

variable "private_subnet_ids" {
  description = "Lista de IDs das Subnets privadas onde o VPC Link será conectado"
  type        = list(string)
}

variable "lambda_function_arn" {
  description = "ARN da AWS Lambda de autenticação de clientes (AutoReparos.AuthLambda)"
  type        = string
  default     = ""
}

variable "lambda_function_name" {
  description = "Nome da função AWS Lambda de autenticação para concessão de permissão"
  type        = string
  default     = ""
}

variable "eks_ingress_url" {
  description = "ARN do Listener do NLB/ALB interno (recomendado para HTTP API VPC Link) ou URL DNS do Ingress Controller do EKS para onde as rotas /api/* e /health serão encaminhadas via VPC Link"
  type        = string
  default     = "http://localhost:8080"
}
