variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for EKS node group"
}

variable "instance_types" {
  type        = list(string)
  description = "EC2 instance types for EKS nodes"
  default     = ["t3.small"]
}


variable "desired_size" {
  type        = number
  description = "Desired number of worker nodes"
  default     = 2
}

variable "max_size" {
  type        = number
  description = "Maximum number of worker nodes"
  default     = 2
}

variable "min_size" {
  type        = number
  description = "Minimum number of worker nodes"
  default     = 2
}

variable "environment" {
  type        = string
  description = "Environment name"
  default     = "production"
}
