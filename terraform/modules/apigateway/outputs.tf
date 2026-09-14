output "api_endpoint" {
  description = "URL base pública do AWS API Gateway HTTP API v2"
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}

output "api_id" {
  description = "ID do API Gateway HTTP API v2"
  value       = aws_apigatewayv2_api.http_api.id
}

output "api_arn" {
  description = "ARN do API Gateway HTTP API v2"
  value       = aws_apigatewayv2_api.http_api.arn
}

output "api_execution_arn" {
  description = "Execution ARN do API Gateway HTTP API v2"
  value       = aws_apigatewayv2_api.http_api.execution_arn
}

output "vpc_link_id" {
  description = "ID do AWS API Gateway VPC Link privado"
  value       = aws_apigatewayv2_vpc_link.eks_link.id
}

output "vpc_link_security_group_id" {
  description = "ID do Security Group do AWS API Gateway VPC Link"
  value       = aws_security_group.vpc_link.id
}
