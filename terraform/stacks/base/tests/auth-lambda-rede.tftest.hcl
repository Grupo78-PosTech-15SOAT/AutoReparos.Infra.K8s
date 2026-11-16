# C44 de deploy-servicos: a AuthLambda alcança o ALB interno do Cadastros (HTTP 80 dentro da VPC).
# Sem essa saída, POST /auth/cliente responde 503 por timeout (achado no checkout de 16/11).

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "198903849859" }
  }
  mock_data "aws_iam_openid_connect_provider" {
    defaults = { arn = "arn:aws:iam::198903849859:oidc-provider/token.actions.githubusercontent.com" }
  }
  mock_data "aws_region" {
    defaults = { name = "us-east-1" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::198903849859:role/simulada" }
  }
  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws:kms:us-east-1:198903849859:key/simulada" }
  }
  mock_resource "aws_eks_cluster" {
    defaults = {
      certificate_authority = [{ data = "Y2VydGlmaWNhZG8=" }]
      identity              = [{ oidc = [{ issuer = "https://oidc.eks.us-east-1.amazonaws.com/id/EXEMPLO" }] }]
    }
  }
}

mock_provider "kubernetes" {}

mock_provider "tls" {
  mock_data "tls_certificate" {
    defaults = { certificates = [{ sha1_fingerprint = "9e99a48a9960b14926bb7f3b02e22da2b0ab7280" }] }
  }
}

variables {
  aws_region      = "us-east-1"
  cluster_name    = "autoreparos-cluster"
  tf_state_bucket = "autoreparos-tfstate-198903849859"
}

run "auth_lambda_alcanca_alb_interno" {
  command = apply

  assert {
    condition = anytrue([
      for e in aws_security_group.lambda.egress :
      e.protocol == "tcp" && e.from_port == 80 && e.to_port == 80 && length(e.cidr_blocks) == 1 && contains(e.cidr_blocks, var.vpc_cidr)
    ])
    error_message = "O security group da AuthLambda precisa de saída TCP 80 para o CIDR da VPC (ALB interno do Cadastros)."
  }

  assert {
    condition = !anytrue([
      for e in aws_security_group.lambda.egress :
      e.from_port == 80 && contains(e.cidr_blocks, "0.0.0.0/0")
    ])
    error_message = "A saída HTTP 80 da AuthLambda fica restrita à VPC."
  }
}
