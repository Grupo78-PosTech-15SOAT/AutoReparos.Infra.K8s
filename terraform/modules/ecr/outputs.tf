output "repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.api.repository_url
}

output "repository_arn" {
  description = "The ARN of the ECR repository"
  value       = aws_ecr_repository.api.arn
}

output "registry_id" {
  description = "AWS account ID that owns the repository"
  value       = aws_ecr_repository.api.registry_id
}
