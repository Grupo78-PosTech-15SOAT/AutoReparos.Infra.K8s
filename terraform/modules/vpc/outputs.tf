output "vpc_id" {
  value       = aws_vpc.main.id
  description = "The ID of the VPC"
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "List of IDs of private subnets"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "List of IDs of public subnets"
}

output "private_route_table_ids" {
  value       = [aws_route_table.private.id]
  description = "IDs das tabelas de rota privadas"
}

output "nat_gateway_ids" {
  value       = [aws_nat_gateway.nat.id]
  description = "IDs dos NAT Gateways (um só, D-55)"
}
