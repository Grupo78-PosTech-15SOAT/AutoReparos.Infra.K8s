variable "environment" {
  description = "Ambiente de deploy (ex: production, staging, dev)"
  type        = string
  default     = "production"
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
  description = "URL HTTP ou DNS do NLB/ALB do Ingress Controller do EKS para onde as rotas /api/* serão encaminhadas"
  type        = string
  default     = "http://localhost:8080"
}
