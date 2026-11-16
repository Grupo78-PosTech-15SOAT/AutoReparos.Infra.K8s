# Parâmetros que os Terraform dos serviços leem com data "aws_ssm_parameter" (D-53), sem terraform_remote_state.
locals {
  parametros_plataforma = {
    "vpc_id"                    = module.vpc.vpc_id
    "subnets/private"           = join(",", module.vpc.private_subnet_ids)
    "security-groups/eks-nodes" = module.eks.cluster_security_group_id
    "eks/cluster_name"          = module.eks.cluster_name
    "eks/oidc_provider_arn"     = module.eks.oidc_provider_arn
    "eks/oidc_provider_url"     = trimprefix(module.eks.oidc_provider_url, "https://")
  }
}

resource "aws_ssm_parameter" "plataforma" {
  for_each = local.parametros_plataforma

  name  = "/autoreparos/${var.environment}/${each.key}"
  type  = "String"
  value = each.value
}
