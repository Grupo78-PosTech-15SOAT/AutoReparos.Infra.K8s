variable "aws_region" { type = string }
variable "environment" {
  type    = string
  default = "production"
}
variable "vpc_id" {
  type = string
  validation {
    condition     = startswith(var.vpc_id, "vpc-")
    error_message = "Pass the VPC ID from the network state."
  }
}
variable "private_subnet_ids" { type = list(string) }
variable "lambda_function_arn" { type = string }
variable "lambda_function_name" { type = string }
variable "alb_listener_arn" {
  type = string
  validation {
    condition     = can(regex("^arn:aws:elasticloadbalancing:[^:]+:[0-9]+:listener/", var.alb_listener_arn))
    error_message = "Pass the internal ALB listener ARN, not its DNS name."
  }
}
