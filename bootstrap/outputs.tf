output "state_bucket_name" {
  description = "Nome do bucket S3 criado para o armazenamento do Terraform State compartilhado"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN do bucket S3 do Terraform State"
  value       = aws_s3_bucket.terraform_state.arn
}

output "state_bucket_region" {
  description = "Região da AWS onde o bucket S3 foi provisionado"
  value       = var.aws_region
}

output "lock_table_name" {
  description = "Nome da tabela DynamoDB criada para state locking do Terraform"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "lock_table_arn" {
  description = "ARN da tabela DynamoDB de state locking"
  value       = aws_dynamodb_table.terraform_locks.arn
}
