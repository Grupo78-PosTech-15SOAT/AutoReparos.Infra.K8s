terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # IMPORTANTE: Backend LOCAL deliberado.
  # O bootstrap cria o bucket S3 e a tabela DynamoDB que servirão como backend remoto
  # para a infraestrutura principal (VPC, EKS, RDS, Lambda).
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Component   = "TerraformBootstrap"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "Grupo78-PosTech-15SOAT/AutoReparos.Infra.K8s"
    }
  }
}

# -------------------------------------------------------------
# 1. Bucket S3 para Armazenamento Seguro do Terraform State
# -------------------------------------------------------------

resource "aws_s3_bucket" "terraform_state" {
  bucket        = var.state_bucket_name
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = var.state_bucket_name
    Description = "Terraform remote state storage for AutoReparos infrastructure"
  }
}

# Habilita versionamento do bucket (essencial para histórico, auditoria e rollback de state)
resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Habilita criptografia em repouso com SSE-S3 (AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_crypto" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloqueia completamente qualquer acesso público ao bucket
resource "aws_s3_bucket_public_access_block" "terraform_state_pab" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Garante controle de propriedade dos objetos pelo dono do bucket (BucketOwnerEnforced, sem ACLs legadas)
resource "aws_s3_bucket_ownership_controls" "terraform_state_ownership" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Política do bucket para forçar transporte seguro (TLS/HTTPS obrigatório)
resource "aws_s3_bucket_policy" "enforce_tls" {
  bucket = aws_s3_bucket.terraform_state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLSRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.terraform_state_pab]
}

# -------------------------------------------------------------
# 2. Tabela DynamoDB para State Locking do Terraform
# -------------------------------------------------------------

resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = var.lock_table_name
    Description = "Terraform state lock table for AutoReparos infrastructure"
  }
}
