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

# 2. Integração com a API Backend no cluster EKS (/api/{proxy+})
resource "aws_apigatewayv2_integration" "eks_proxy" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = "${var.eks_ingress_url}/api/{proxy}"
  payload_format_version = "1.0"
  description            = "Proxy HTTP para o Ingress NLB do cluster Kubernetes EKS"
}

resource "aws_apigatewayv2_route" "eks_proxy_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /api/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.eks_proxy.id}"
}
