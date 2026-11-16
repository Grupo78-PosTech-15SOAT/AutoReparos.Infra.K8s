# C30 de deploy-servicos: endpoints gateway de S3 e DynamoDB nas tabelas de rota privadas e um só NAT
# Gateway (D-55). Roda o módulo da VPC usado pelo stacks/base, com o provedor simulado.

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { name = "us-east-1" }
  }
}

run "endpoints_gateway" {
  command = apply

  module {
    source = "../../modules/vpc"
  }

  variables {
    cluster_name = "autoreparos-cluster"
  }

  assert {
    condition     = toset(keys(aws_vpc_endpoint.gateway)) == toset(["s3", "dynamodb"])
    error_message = "A VPC precisa de exatamente os endpoints de S3 e DynamoDB."
  }

  assert {
    condition = (
      aws_vpc_endpoint.gateway["s3"].service_name == "com.amazonaws.us-east-1.s3" &&
      aws_vpc_endpoint.gateway["s3"].vpc_endpoint_type == "Gateway" &&
      aws_vpc_endpoint.gateway["s3"].vpc_id == aws_vpc.main.id &&
      aws_vpc_endpoint.gateway["s3"].route_table_ids == toset([aws_route_table.private.id])
    )
    error_message = "O endpoint de S3 precisa ser do tipo Gateway e associado à tabela de rota privada."
  }

  assert {
    condition = (
      aws_vpc_endpoint.gateway["dynamodb"].service_name == "com.amazonaws.us-east-1.dynamodb" &&
      aws_vpc_endpoint.gateway["dynamodb"].vpc_endpoint_type == "Gateway" &&
      aws_vpc_endpoint.gateway["dynamodb"].vpc_id == aws_vpc.main.id &&
      aws_vpc_endpoint.gateway["dynamodb"].route_table_ids == toset([aws_route_table.private.id])
    )
    error_message = "O endpoint de DynamoDB precisa ser do tipo Gateway e associado à tabela de rota privada."
  }

  assert {
    condition     = length(output.nat_gateway_ids) == 1 && output.nat_gateway_ids[0] == aws_nat_gateway.nat.id
    error_message = "A VPC precisa continuar com exatamente um NAT Gateway."
  }

  assert {
    condition = alltrue([
      for rota in aws_route_table.private.route : rota.nat_gateway_id == aws_nat_gateway.nat.id if rota.cidr_block == "0.0.0.0/0"
    ])
    error_message = "A saída das sub-redes privadas precisa passar pelo único NAT Gateway."
  }
}
