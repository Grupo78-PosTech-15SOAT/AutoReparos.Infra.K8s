terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
  }

  # Backend S3 configurável
  # backend "s3" {
  #   bucket         = "autoreparos-terraform-state"
  #   key            = "k8s/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "autoreparos-tflocks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "AutoReparos"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "Grupo78-PosTech-15SOAT/AutoReparos.Infra.K8s"
      Fase        = "Fase-3"
    }
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}
