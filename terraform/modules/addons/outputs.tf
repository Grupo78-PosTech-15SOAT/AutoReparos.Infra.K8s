output "ebs_csi_addon_arn" {
  value       = aws_eks_addon.ebs_csi.arn
  description = "ARN of the EBS CSI driver addon"
}

output "nginx_ingress_status" {
  value       = helm_release.nginx_ingress.status
  description = "Status of the Nginx Ingress helm release"
}
