# Acesso de deploy de cada repositório de serviço (porta 2 e porta 6 de deploy-servicos, ADR-005).
# Cada serviço ganha um namespace, uma role OIDC presa ao Environment production do próprio repositório,
# permissão limitada por nome aos próprios recursos e acesso de edição só ao próprio namespace.

locals {
  # servico -> sufixo do repositório AutoReparos.<Repo>
  servicos = {
    os        = "OS"
    cobranca  = "Cobranca"
    execucao  = "Execucao"
    cadastros = "Cadastros"
  }
  conta           = data.aws_caller_identity.current.account_id
  github_oidc_url = "token.actions.githubusercontent.com"
}

data "aws_caller_identity" "current" {}

# O provedor OIDC do GitHub já existe na conta (scripts/infra/criar-acesso-github.sh, AD-060): só é lido.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://${local.github_oidc_url}"
}

resource "kubernetes_namespace_v1" "servico" {
  for_each = local.servicos

  metadata {
    name = each.key
    labels = {
      "app.kubernetes.io/part-of" = "autoreparos"
    }
  }
}

# Teto das roles IRSA que o Terraform de cada serviço cria: a role de deploy só cria role com este boundary.
# É um só para os 4 serviços e se limita ao serviço pela tag Servico da própria role (default_tags do Terraform de
# cada serviço; a role de deploy só cria role com Servico = o próprio serviço e não troca nem tira essa tag).
resource "aws_iam_policy" "servico_boundary" {
  name        = "autoreparos-servico-boundary"
  description = "Permissions boundary das roles IRSA dos servicos do AutoReparos"
  policy = templatefile("${path.module}/politicas/servico-boundary.json.tftpl", {
    conta  = local.conta
    regiao = var.aws_region
  })
}

resource "aws_iam_role" "deploy" {
  for_each = local.servicos

  name                 = "autoreparos-deploy-${each.key}"
  description          = "Deploy do AutoReparos.${each.value} pelo GitHub Actions (Environment production)"
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.github_oidc_url}:aud" = "sts.amazonaws.com"
          "${local.github_oidc_url}:sub" = [
            "repo:${var.github_org}/AutoReparos.${each.value}:environment:production",
            # Repositórios com assunto imutável do GitHub (não dá para desligar): org e repositório com o id numérico.
            "repo:${var.github_org}@${var.github_org_id}/AutoReparos.${each.value}@${var.github_repo_ids[each.key]}:environment:production",
          ]
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "deploy" {
  for_each = local.servicos

  name = "autoreparos-deploy-${each.key}"
  role = aws_iam_role.deploy[each.key].id
  policy = templatefile("${path.module}/politicas/deploy-servico.json.tftpl", {
    servico     = each.key
    conta       = local.conta
    regiao      = var.aws_region
    bucket      = var.tf_state_bucket
    tabela_lock = var.tf_lock_table
    cluster     = module.eks.cluster_name
  })
}

resource "aws_eks_access_entry" "deploy" {
  for_each = local.servicos

  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.deploy[each.key].arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "deploy" {
  for_each = local.servicos

  cluster_name  = module.eks.cluster_name
  principal_arn = aws_eks_access_entry.deploy[each.key].principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = [kubernetes_namespace_v1.servico[each.key].metadata[0].name]
  }
}

# Acesso humano ao cluster: sem isto só a role do pai (criadora do cluster) usa kubectl e helm.
resource "aws_eks_access_entry" "administrador" {
  for_each = toset(var.administradores_eks)

  cluster_name  = module.eks.cluster_name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "administrador" {
  for_each = toset(var.administradores_eks)

  cluster_name  = module.eks.cluster_name
  principal_arn = aws_eks_access_entry.administrador[each.key].principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
