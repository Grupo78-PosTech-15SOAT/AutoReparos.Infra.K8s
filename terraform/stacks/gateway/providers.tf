terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    key            = "gateway/production/terraform.tfstate"
    dynamodb_table = "autoreparos-terraform-locks"
    encrypt        = true
  }
}
provider "aws" { region = var.aws_region }
