variable "aws_region" { type = string }
variable "environment" {
  type    = string
  default = "production"
}
variable "cluster_name" {
  type    = string
  default = "autoreparos-cluster"
}
variable "kubernetes_version" {
  type    = string
  default = "1.35"
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}
variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.3.0/24", "10.0.4.0/24"]
}
variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}
variable "instance_types" {
  type    = list(string)
  default = ["t3.small"]
}
variable "desired_size" {
  type    = number
  default = 2
}
variable "max_size" {
  type    = number
  default = 4
}
variable "min_size" {
  type    = number
  default = 2
}
