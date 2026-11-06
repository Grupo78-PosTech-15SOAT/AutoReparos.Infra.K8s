module "vpc" {
  source               = "../../modules/vpc"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  cluster_name         = var.cluster_name
  environment          = var.environment
}

module "eks" {
  source             = "../../modules/eks"
  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  instance_types     = var.instance_types
  desired_size       = var.desired_size
  max_size           = var.max_size
  min_size           = var.min_size
  environment        = var.environment
}

module "ecr" {
  source          = "../../modules/ecr"
  repository_name = "autoreparos-api"
  environment     = var.environment
}

module "ecr_web" {
  source          = "../../modules/ecr"
  repository_name = "autoreparos-web"
  environment     = var.environment
}

resource "aws_security_group" "lambda" {
  name        = "autoreparos-auth-lambda-sg-${var.environment}"
  description = "Shared egress security group for the AutoReparos authentication Lambda"
  vpc_id      = module.vpc.vpc_id

  egress {
    description = "TLS egress for AWS APIs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "PostgreSQL egress within the project VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Name = "autoreparos-auth-lambda-sg-${var.environment}" }
}
