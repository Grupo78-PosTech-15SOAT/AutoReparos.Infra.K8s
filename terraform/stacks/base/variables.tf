variable "aws_region" { type = string }
variable "environment" {
  type    = string
  default = "production"
}
variable "cluster_name" {
  type    = string
  default = "autoreparos-cluster"
}
variable "kubernetes_version" {
  type    = string
  default = "1.35"
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}
variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.3.0/24", "10.0.4.0/24"]
}
variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}
variable "instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}
variable "desired_size" {
  type    = number
  default = 2
}
variable "max_size" {
  type    = number
  default = 3
}
variable "min_size" {
  type    = number
  default = 2
}
variable "tf_state_bucket" {
  description = "Bucket do state do Terraform; as roles de deploy dos serviços só alcançam servicos/<servico>/ nele"
  type        = string
}
variable "tf_lock_table" {
  description = "Tabela DynamoDB de lock do state do Terraform"
  type        = string
  default     = "autoreparos-terraform-locks"
}
variable "github_org" {
  description = "Organização do GitHub dona dos repositórios dos serviços"
  type        = string
  default     = "Grupo78-PosTech-15SOAT"
}
variable "administradores_eks" {
  description = "Roles humanas com acesso de administrador ao cluster (permission set do Identity Center usado por José e Enrico, AD-055)"
  type        = list(string)
  default     = ["arn:aws:iam::198903849859:role/managed/AccountFullAccessRole"]
}

variable "github_org_id" {
  description = "Id numérico da organização no GitHub, usado no assunto imutável do OIDC"
  type        = string
  default     = "272379485"
}

variable "github_repo_ids" {
  description = "Id numérico de cada repositório de serviço no GitHub, usado no assunto imutável do OIDC"
  type        = map(string)
  default = {
    os        = "1451569216"
    cobranca  = "1451580860"
    execucao  = "1451800348"
    cadastros = "1369332411"
  }
}
