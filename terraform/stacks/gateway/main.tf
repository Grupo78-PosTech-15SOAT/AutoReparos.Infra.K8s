module "api_gateway" {
  source               = "../../modules/apigateway"
  environment          = var.environment
  vpc_id               = var.vpc_id
  private_subnet_ids   = var.private_subnet_ids
  lambda_function_arn  = var.lambda_function_arn
  lambda_function_name = var.lambda_function_name
  eks_ingress_url      = var.alb_listener_arn
}

# URL pública que os serviços usam como Authentication__Authority e emissor do Cadastros (D-53).
resource "aws_ssm_parameter" "api_gateway_endpoint" {
  name  = "/autoreparos/${var.environment}/apigateway/endpoint"
  type  = "String"
  value = module.api_gateway.api_endpoint
}
