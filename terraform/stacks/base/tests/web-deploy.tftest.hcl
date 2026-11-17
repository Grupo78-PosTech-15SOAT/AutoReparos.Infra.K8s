# C1 de web-deploy: namespace web, role autoreparos-deploy-web com trust nas duas formas do sub (D-61), política
# mínima (só ECR autoreparos-web e eks:DescribeCluster) e edição só no namespace web. Sem AWS: provedores simulados.

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

run "deploy_do_web" {
  command = apply

  assert {
    condition = (
      kubernetes_namespace_v1.web.metadata[0].name == "web" &&
      kubernetes_namespace_v1.web.metadata[0].labels["app.kubernetes.io/part-of"] == "autoreparos"
    )
    error_message = "A plataforma precisa criar o namespace web com o rótulo app.kubernetes.io/part-of = autoreparos."
  }

  assert {
    condition     = var.github_repo_ids["web"] == "1454153026"
    error_message = "github_repo_ids.web precisa ser o id do AutoReparos.Web (1454153026)."
  }

  assert {
    condition     = aws_iam_role.deploy_web.name == "autoreparos-deploy-web"
    error_message = "A role de deploy do Web precisa se chamar autoreparos-deploy-web."
  }

  assert {
    condition = (
      length(jsondecode(aws_iam_role.deploy_web.assume_role_policy).Statement) == 1 &&
      jsonencode(jsondecode(aws_iam_role.deploy_web.assume_role_policy).Statement[0]) == jsonencode({
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = ["repo:Grupo78-PosTech-15SOAT/AutoReparos.Web:environment:production", "repo:Grupo78-PosTech-15SOAT@272379485/AutoReparos.Web@1454153026:environment:production"]
          }
        }
        Effect    = "Allow"
        Principal = { Federated = "arn:aws:iam::198903849859:oidc-provider/token.actions.githubusercontent.com" }
      })
    )
    error_message = "O trust da role do Web só pode aceitar as duas formas do sub do Environment production do AutoReparos.Web."
  }

  assert {
    condition = (
      aws_iam_role_policy.deploy_web.name == "autoreparos-deploy-web" &&
      jsondecode(aws_iam_role_policy.deploy_web.policy) == jsondecode(templatefile("./politicas/deploy-web.json.tftpl", {
        conta   = "198903849859"
        regiao  = "us-east-1"
        cluster = "autoreparos-cluster"
      }))
    )
    error_message = "A política inline autoreparos-deploy-web precisa ser a renderizada de politicas/deploy-web.json.tftpl."
  }

  assert {
    condition = (
      !strcontains(aws_iam_role_policy.deploy_web.policy, "sqs:") &&
      !strcontains(aws_iam_role_policy.deploy_web.policy, "sns:") &&
      !strcontains(aws_iam_role_policy.deploy_web.policy, "dynamodb:") &&
      !strcontains(aws_iam_role_policy.deploy_web.policy, "secretsmanager:") &&
      !strcontains(aws_iam_role_policy.deploy_web.policy, "iam:") &&
      strcontains(aws_iam_role_policy.deploy_web.policy, "arn:aws:ecr:us-east-1:198903849859:repository/autoreparos-web\"")
    )
    error_message = "A política do Web não pode dar SQS, SNS, DynamoDB, Secrets Manager nem IAM, e o ECR é só autoreparos-web."
  }

  assert {
    condition = (
      aws_eks_access_entry.deploy_web.principal_arn == aws_iam_role.deploy_web.arn &&
      aws_eks_access_entry.deploy_web.type == "STANDARD" &&
      aws_eks_access_policy_association.deploy_web.principal_arn == aws_iam_role.deploy_web.arn &&
      aws_eks_access_policy_association.deploy_web.policy_arn == "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy" &&
      aws_eks_access_policy_association.deploy_web.access_scope[0].type == "namespace" &&
      aws_eks_access_policy_association.deploy_web.access_scope[0].namespaces == toset(["web"])
    )
    error_message = "A role do Web precisa de access entry com AmazonEKSEditPolicy limitada ao namespace web."
  }

  assert {
    condition     = toset(keys(aws_iam_role.deploy)) == toset(["os", "cobranca", "execucao", "cadastros"])
    error_message = "As 4 roles de serviço continuam as mesmas; o Web tem role própria fora do mapa de serviços."
  }
}
