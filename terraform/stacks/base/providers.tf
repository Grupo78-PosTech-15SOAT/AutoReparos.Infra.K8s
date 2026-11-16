terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 3.2" }
  }
  backend "s3" {
    key            = "network/production/terraform.tfstate"
    dynamodb_table = "autoreparos-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = { Project = "AutoReparos", Environment = var.environment, ManagedBy = "Terraform" }
  }
}

# Namespaces dos serviços. O token vem do aws eks get-token a cada chamada, porque o cluster é criado
# neste mesmo apply e um token lido no plan expiraria antes dos namespaces.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
  }
}
