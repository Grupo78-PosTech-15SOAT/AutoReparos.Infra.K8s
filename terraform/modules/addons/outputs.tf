output "ebs_csi_addon_arn" {
  value       = aws_eks_addon.ebs_csi.arn
  description = "ARN of the EBS CSI driver addon"
}

output "load_balancer_controller_status" {
  value       = helm_release.aws_load_balancer_controller.status
  description = "Status of the AWS Load Balancer Controller release"
}
