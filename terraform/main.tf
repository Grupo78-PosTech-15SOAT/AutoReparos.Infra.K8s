# 1. Rede e Topologia VPC Multi-AZ
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  cluster_name         = var.cluster_name
  environment          = var.environment
}

# 2. Cluster Kubernetes Gerenciado (AWS EKS) e Managed Node Groups
module "eks" {
  source = "./modules/eks"

  cluster_name       = var.cluster_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  instance_types     = var.instance_types
  desired_size       = var.desired_size
  max_size           = var.max_size
  min_size           = var.min_size
  environment        = var.environment
}

# 3. Add-ons do EKS (Metrics Server, EBS CSI, VPC CNI, CoreDNS, Kube-Proxy)
module "addons" {
  source = "./modules/addons"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  depends_on = [module.eks]
}

# 4. AWS ECR para Armazenamento Seguro de Imagens Docker
module "ecr" {
  source = "./modules/ecr"

  repository_name = "autoreparos-api"
  environment     = var.environment
}

# 5. AWS API Gateway v2 (HTTP API com VPC Link Privado: /auth/cliente -> Lambda, /api/* e /health -> EKS)
module "apigateway" {
  source = "./modules/apigateway"

  environment          = var.environment
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  lambda_function_arn  = var.lambda_function_arn
  lambda_function_name = var.lambda_function_name
  eks_ingress_url      = var.eks_ingress_url
}

# 6. Publicação de Parâmetros de Rede no AWS SSM Parameter Store para Desacoplamento Multi-Repo
resource "aws_ssm_parameter" "vpc_id" {
  name        = "/autoreparos/${var.environment}/vpc_id"
  description = "ID da VPC provisionada para o cluster EKS e RDS do AutoReparos"
  type        = "String"
  value       = module.vpc.vpc_id
  overwrite   = true

  tags = {
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "private_subnets" {
  name        = "/autoreparos/${var.environment}/subnets/private"
  description = "Lista separada por virgula dos IDs das Subnets privadas do AutoReparos"
  type        = "StringList"
  value       = join(",", module.vpc.private_subnet_ids)
  overwrite   = true

  tags = {
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "eks_security_group" {
  name        = "/autoreparos/${var.environment}/security-groups/eks-nodes"
  description = "ID do Security Group do cluster EKS para permitir acesso ao RDS PostgreSQL"
  type        = "String"
  value       = module.eks.cluster_security_group_id
  overwrite   = true

  tags = {
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "api_gateway_endpoint" {
  name        = "/autoreparos/${var.environment}/apigateway/endpoint"
  description = "Endpoint base publico do AWS API Gateway HTTP API v2"
  type        = "String"
  value       = module.apigateway.api_endpoint
  overwrite   = true

  tags = {
    Environment = var.environment
  }
}
