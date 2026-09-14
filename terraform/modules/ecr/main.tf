resource "aws_ecr_repository" "api" {
  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  # Enable automatic deletion of images upon destroying the repository
  force_delete = true


  tags = {
    Name        = var.repository_name
    Environment = var.environment
  }
}
