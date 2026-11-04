module "api_gateway" {
  source = "../../modules/apigateway"
  environment          = var.environment
  vpc_id               = var.vpc_id
  private_subnet_ids   = var.private_subnet_ids
  lambda_function_arn  = var.lambda_function_arn
  lambda_function_name = var.lambda_function_name
  eks_ingress_url      = var.alb_listener_arn
}
