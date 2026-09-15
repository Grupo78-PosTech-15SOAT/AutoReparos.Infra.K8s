variable "aws_region" {
  type        = string
  description = "Região da AWS para deploy da infraestrutura"
  default     = "us-east-1"
}

variable "cluster_name" {
  type        = string
  description = "Nome do cluster EKS"
  default     = "autoreparos-cluster"
}

variable "environment" {
  type        = string
  description = "Nome do ambiente de deploy (production, staging, dev)"
  default     = "production"
}

variable "vpc_cidr" {
  type        = string
  description = "Bloco CIDR da VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Blocos CIDR para subnets públicas (Ingress, NAT Gateway)"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Blocos CIDR para subnets privadas (EKS Node Groups)"
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones para alta disponibilidade multi-AZ"
  default     = ["us-east-1a", "us-east-1b"]
}

variable "instance_types" {
  type        = list(string)
  description = "Tipos de instância EC2 para os worker nodes do EKS"
  default     = ["t3.small"]
}

variable "desired_size" {
  type        = number
  description = "Quantidade desejada de worker nodes"
  default     = 2
}

variable "max_size" {
  type        = number
  description = "Quantidade máxima de worker nodes (HPA auto scaling)"
  default     = 4
}

variable "min_size" {
  type        = number
  description = "Quantidade mínima de worker nodes"
  default     = 2
}

variable "lambda_function_arn" {
  type        = string
  description = "ARN da AWS Lambda de autenticação de cliente (opcional no provisionamento inicial)"
  default     = ""
}

variable "lambda_function_name" {
  type        = string
  description = "Nome da AWS Lambda de autenticação de cliente para permissão do API Gateway"
  default     = ""
}

variable "eks_ingress_url" {
  type        = string
  description = "ARN do Listener do NLB/ALB interno (recomendado para HTTP API VPC Link) ou URL DNS do Ingress Controller do EKS para onde as rotas /api/* e /health serão encaminhadas via VPC Link"
  default     = "http://localhost:8080"
}
