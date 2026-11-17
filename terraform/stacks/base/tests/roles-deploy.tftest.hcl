# C23 de deploy-servicos: namespaces, boundary, roles de deploy com trust por Environment e access entry
# limitada ao namespace. Sem AWS: provedores simulados.

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

# As asserções citam cada serviço por endereço estático: com chave dinâmica (for sobre o mapa de roles) o
# Terraform 1.15 entra em pânico ao imprimir a falha, por causa dos atributos depreciados marcados do aws_iam_role.
run "roles_de_deploy" {
  command = apply

  assert {
    condition     = toset([for ns in kubernetes_namespace_v1.servico : ns.metadata[0].name]) == toset(["os", "cobranca", "execucao", "cadastros"])
    error_message = "A plataforma precisa criar exatamente os namespaces os, cobranca, execucao e cadastros."
  }

  assert {
    condition     = aws_iam_policy.servico_boundary.name == "autoreparos-servico-boundary"
    error_message = "O permissions boundary precisa se chamar autoreparos-servico-boundary."
  }

  assert {
    condition = (
      strcontains(aws_iam_policy.servico_boundary.policy, "secret:autoreparos/production/$${aws:PrincipalTag/Servico}/*") &&
      strcontains(aws_iam_policy.servico_boundary.policy, "table/autoreparos-$${aws:PrincipalTag/Servico}-*") &&
      !strcontains(aws_iam_policy.servico_boundary.policy, "autoreparos/production/os/")
    )
    error_message = "O boundary precisa limitar segredos e tabelas ao serviço pela variável aws:PrincipalTag/Servico, renderizada literalmente."
  }

  # C22 de infra-ci-observabilidade (D-67): SNS só no prefixo do serviço; publicar só nos tópicos do próprio serviço.
  assert {
    condition = (
      strcontains(aws_iam_policy.servico_boundary.policy, "\"sns:Publish\"") &&
      strcontains(aws_iam_policy.servico_boundary.policy, "arn:aws:sns:us-east-1:198903849859:autoreparos-$${aws:PrincipalTag/Servico}-*") &&
      !strcontains(aws_iam_policy.servico_boundary.policy, "\"sns:*\"")
    )
    error_message = "O boundary precisa permitir sns:Publish só em autoreparos-$${aws:PrincipalTag/Servico}-*."
  }

  assert {
    condition = (
      strcontains(aws_iam_role_policy.deploy["execucao"].policy, "\"Resource\": \"arn:aws:sns:us-east-1:198903849859:autoreparos-execucao-*\"") &&
      strcontains(aws_iam_role_policy.deploy["os"].policy, "\"Resource\": \"arn:aws:sns:us-east-1:198903849859:autoreparos-os-*\"") &&
      !strcontains(aws_iam_role_policy.deploy["os"].policy, "autoreparos-execucao-*")
    )
    error_message = "A política de deploy precisa dar sns:* só nos tópicos autoreparos-<servico>-* do próprio serviço."
  }

  assert {
    condition     = toset(keys(aws_iam_role.deploy)) == toset(["os", "cobranca", "execucao", "cadastros"]) && length(aws_eks_access_entry.deploy) == 4 && length(aws_eks_access_policy_association.deploy) == 4
    error_message = "Precisam existir exatamente 4 roles de deploy, cada uma com uma access entry."
  }

  assert {
    condition     = aws_iam_role.deploy["os"].name == "autoreparos-deploy-os"
    error_message = "A role de deploy de os precisa se chamar autoreparos-deploy-os."
  }

  assert {
    condition = (
      length(jsondecode(aws_iam_role.deploy["os"].assume_role_policy).Statement) == 1 &&
      jsonencode(jsondecode(aws_iam_role.deploy["os"].assume_role_policy).Statement[0]) == jsonencode({
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = ["repo:Grupo78-PosTech-15SOAT/AutoReparos.OS:environment:production", "repo:Grupo78-PosTech-15SOAT@272379485/AutoReparos.OS@1451569216:environment:production"]
          }
        }
        Effect    = "Allow"
        Principal = { Federated = "arn:aws:iam::198903849859:oidc-provider/token.actions.githubusercontent.com" }
      })
    )
    error_message = "O trust da role de os só pode aceitar repo:Grupo78-PosTech-15SOAT/AutoReparos.OS:environment:production pelo OIDC do GitHub."
  }

  assert {
    condition = (
      aws_eks_access_entry.deploy["os"].principal_arn == aws_iam_role.deploy["os"].arn &&
      aws_eks_access_policy_association.deploy["os"].principal_arn == aws_iam_role.deploy["os"].arn &&
      aws_eks_access_policy_association.deploy["os"].policy_arn == "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy" &&
      aws_eks_access_policy_association.deploy["os"].access_scope[0].type == "namespace" &&
      aws_eks_access_policy_association.deploy["os"].access_scope[0].namespaces == toset(["os"])
    )
    error_message = "A role de os precisa de access entry com AmazonEKSEditPolicy limitada ao namespace os."
  }

  assert {
    condition     = aws_iam_role.deploy["cobranca"].name == "autoreparos-deploy-cobranca"
    error_message = "A role de deploy de cobranca precisa se chamar autoreparos-deploy-cobranca."
  }

  assert {
    condition = (
      length(jsondecode(aws_iam_role.deploy["cobranca"].assume_role_policy).Statement) == 1 &&
      jsonencode(jsondecode(aws_iam_role.deploy["cobranca"].assume_role_policy).Statement[0]) == jsonencode({
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = ["repo:Grupo78-PosTech-15SOAT/AutoReparos.Cobranca:environment:production", "repo:Grupo78-PosTech-15SOAT@272379485/AutoReparos.Cobranca@1451580860:environment:production"]
          }
        }
        Effect    = "Allow"
        Principal = { Federated = "arn:aws:iam::198903849859:oidc-provider/token.actions.githubusercontent.com" }
      })
    )
    error_message = "O trust da role de cobranca só pode aceitar repo:Grupo78-PosTech-15SOAT/AutoReparos.Cobranca:environment:production pelo OIDC do GitHub."
  }

  assert {
    condition = (
      aws_eks_access_entry.deploy["cobranca"].principal_arn == aws_iam_role.deploy["cobranca"].arn &&
      aws_eks_access_policy_association.deploy["cobranca"].principal_arn == aws_iam_role.deploy["cobranca"].arn &&
      aws_eks_access_policy_association.deploy["cobranca"].policy_arn == "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy" &&
      aws_eks_access_policy_association.deploy["cobranca"].access_scope[0].type == "namespace" &&
      aws_eks_access_policy_association.deploy["cobranca"].access_scope[0].namespaces == toset(["cobranca"])
    )
    error_message = "A role de cobranca precisa de access entry com AmazonEKSEditPolicy limitada ao namespace cobranca."
  }

  assert {
    condition     = aws_iam_role.deploy["execucao"].name == "autoreparos-deploy-execucao"
    error_message = "A role de deploy de execucao precisa se chamar autoreparos-deploy-execucao."
  }

  assert {
    condition = (
      length(jsondecode(aws_iam_role.deploy["execucao"].assume_role_policy).Statement) == 1 &&
      jsonencode(jsondecode(aws_iam_role.deploy["execucao"].assume_role_policy).Statement[0]) == jsonencode({
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = ["repo:Grupo78-PosTech-15SOAT/AutoReparos.Execucao:environment:production", "repo:Grupo78-PosTech-15SOAT@272379485/AutoReparos.Execucao@1451800348:environment:production"]
          }
        }
        Effect    = "Allow"
        Principal = { Federated = "arn:aws:iam::198903849859:oidc-provider/token.actions.githubusercontent.com" }
      })
    )
    error_message = "O trust da role de execucao só pode aceitar repo:Grupo78-PosTech-15SOAT/AutoReparos.Execucao:environment:production pelo OIDC do GitHub."
  }

  assert {
    condition = (
      aws_eks_access_entry.deploy["execucao"].principal_arn == aws_iam_role.deploy["execucao"].arn &&
      aws_eks_access_policy_association.deploy["execucao"].principal_arn == aws_iam_role.deploy["execucao"].arn &&
      aws_eks_access_policy_association.deploy["execucao"].policy_arn == "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy" &&
      aws_eks_access_policy_association.deploy["execucao"].access_scope[0].type == "namespace" &&
      aws_eks_access_policy_association.deploy["execucao"].access_scope[0].namespaces == toset(["execucao"])
    )
    error_message = "A role de execucao precisa de access entry com AmazonEKSEditPolicy limitada ao namespace execucao."
  }

  assert {
    condition     = aws_iam_role.deploy["cadastros"].name == "autoreparos-deploy-cadastros"
    error_message = "A role de deploy de cadastros precisa se chamar autoreparos-deploy-cadastros."
  }

  assert {
    condition = (
      length(jsondecode(aws_iam_role.deploy["cadastros"].assume_role_policy).Statement) == 1 &&
      jsonencode(jsondecode(aws_iam_role.deploy["cadastros"].assume_role_policy).Statement[0]) == jsonencode({
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = ["repo:Grupo78-PosTech-15SOAT/AutoReparos.Cadastros:environment:production", "repo:Grupo78-PosTech-15SOAT@272379485/AutoReparos.Cadastros@1369332411:environment:production"]
          }
        }
        Effect    = "Allow"
        Principal = { Federated = "arn:aws:iam::198903849859:oidc-provider/token.actions.githubusercontent.com" }
      })
    )
    error_message = "O trust da role de cadastros só pode aceitar repo:Grupo78-PosTech-15SOAT/AutoReparos.Cadastros:environment:production pelo OIDC do GitHub."
  }

  assert {
    condition = (
      aws_eks_access_entry.deploy["cadastros"].principal_arn == aws_iam_role.deploy["cadastros"].arn &&
      aws_eks_access_policy_association.deploy["cadastros"].principal_arn == aws_iam_role.deploy["cadastros"].arn &&
      aws_eks_access_policy_association.deploy["cadastros"].policy_arn == "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy" &&
      aws_eks_access_policy_association.deploy["cadastros"].access_scope[0].type == "namespace" &&
      aws_eks_access_policy_association.deploy["cadastros"].access_scope[0].namespaces == toset(["cadastros"])
    )
    error_message = "A role de cadastros precisa de access entry com AmazonEKSEditPolicy limitada ao namespace cadastros."
  }
}
