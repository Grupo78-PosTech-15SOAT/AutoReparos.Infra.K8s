output "cluster_name" {
  description = "Nome do cluster EKS provisionado"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint da API do cluster EKS"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "ID do Security Group do cluster EKS"
  value       = module.eks.cluster_security_group_id
}

output "vpc_id" {
  description = "ID da VPC provisionada"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Lista de subnets privadas onde o cluster EKS e o RDS operam"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Lista de subnets publicas onde os Load Balancers / Ingress operam"
  value       = module.vpc.public_subnet_ids
}

output "ecr_repository_url" {
  description = "Legacy alias: complete API ECR repository URL"
  value       = module.ecr.repository_url
}

output "ecr_api_repository_url" {
  description = "Complete ECR repository URL for the API image"
  value       = module.ecr.repository_url
}

output "ecr_web_repository_url" {
  description = "Complete ECR repository URL for the Web image"
  value       = module.ecr_web.repository_url
}

output "ecr_registry_id" {
  description = "AWS account ID that owns both ECR repositories"
  value       = module.ecr.registry_id
}

output "lambda_security_group_id" {
  description = "Shared Lambda security group ID for the RDS and Lambda layers"
  value       = aws_security_group.lambda.id
}

output "api_gateway_endpoint" {
  description = "URL base pública do AWS API Gateway HTTP API v2"
  value       = module.apigateway.api_endpoint
}

output "api_gateway_id" {
  description = "ID do AWS API Gateway HTTP API v2"
  value       = module.apigateway.api_id
}

output "vpc_link_id" {
  description = "ID do AWS API Gateway VPC Link privado"
  value       = module.apigateway.vpc_link_id
}
