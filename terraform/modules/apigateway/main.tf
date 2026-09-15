resource "aws_apigatewayv2_api" "http_api" {
  name          = "autoreparos-http-api-${var.environment}"
  protocol_type = "HTTP"
  description   = "AWS API Gateway v2 HTTP API unificando roteamento da Lambda de autenticação e da API no EKS"

  cors_configuration {
    allow_credentials = false
    allow_headers     = ["Authorization", "Content-Type", "X-Amz-Date", "X-Api-Key", "X-Amz-Security-Token"]
    allow_methods     = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"]
    allow_origins     = ["*"]
    max_age           = 300
  }

  tags = {
    Name        = "autoreparos-http-api-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/autoreparos-http-api-${var.environment}"
  retention_in_days = 7
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      ip                      = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      httpMethod              = "$context.httpMethod"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      protocol                = "$context.protocol"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }

  tags = {
    Environment = var.environment
  }
}

# 1. Integração com a Lambda Serverless de Autenticação (/auth/cliente)
resource "aws_apigatewayv2_integration" "lambda_auth" {
  count                  = var.lambda_function_arn != "" ? 1 : 0
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = var.lambda_function_arn
  payload_format_version = "2.0"
  description            = "Integração com a função serverless AutoReparos.AuthLambda"
}

resource "aws_apigatewayv2_route" "lambda_auth_route" {
  count     = var.lambda_function_arn != "" ? 1 : 0
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /auth/cliente"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_auth[0].id}"
}

resource "aws_lambda_permission" "apigw_lambda" {
  count         = var.lambda_function_arn != "" && var.lambda_function_name != "" ? 1 : 0
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# 2. Security Group dedicado para a interface de rede do VPC Link
resource "aws_security_group" "vpc_link" {
  name        = "autoreparos-apigw-vpc-link-sg-${var.environment}"
  description = "Security Group para a interface do AWS API Gateway VPC Link"
  vpc_id      = var.vpc_id

  egress {
    description = "Permitir saida para as portas da aplicacao e NLB interno"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "autoreparos-apigw-vpc-link-sg-${var.environment}"
    Environment = var.environment
  }
}

# 3. AWS API Gateway v2 VPC Link conectando as subnets privadas do EKS
resource "aws_apigatewayv2_vpc_link" "eks_link" {
  name               = "autoreparos-vpc-link-${var.environment}"
  security_group_ids = [aws_security_group.vpc_link.id]
  subnet_ids         = var.private_subnet_ids

  tags = {
    Name        = "autoreparos-vpc-link-${var.environment}"
    Environment = var.environment
  }
}

# 4. Integração com a API Backend no cluster EKS (/api/{proxy+}) via VPC Link Privado
resource "aws_apigatewayv2_integration" "eks_proxy" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.eks_link.id
  integration_uri        = startswith(var.eks_ingress_url, "arn:aws:") ? var.eks_ingress_url : "${var.eks_ingress_url}/api/{proxy}"
  payload_format_version = "1.0"
  description            = "Proxy HTTP privado via VPC Link para o Ingress NLB do EKS"

  depends_on = [aws_apigatewayv2_vpc_link.eks_link]
}

resource "aws_apigatewayv2_route" "eks_proxy_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /api/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.eks_proxy.id}"
}

# 5. Rota Dedicada de Healthcheck (/health) via VPC Link
resource "aws_apigatewayv2_integration" "health_check" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "GET"
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.eks_link.id
  integration_uri        = startswith(var.eks_ingress_url, "arn:aws:") ? var.eks_ingress_url : "${var.eks_ingress_url}/health"
  payload_format_version = "1.0"
  description            = "Sondagem de integridade de ponta a ponta para o backend EKS"

  depends_on = [aws_apigatewayv2_vpc_link.eks_link]
}

resource "aws_apigatewayv2_route" "health_check_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.health_check.id}"
}
