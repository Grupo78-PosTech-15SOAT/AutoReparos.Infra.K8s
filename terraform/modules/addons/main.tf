# -------------------------------------------------------------
# IAM Role for EBS CSI Driver (IRSA)
# -------------------------------------------------------------
data "aws_iam_policy_document" "ebs_csi_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role_policy.json

  tags = {
    Name        = "${var.cluster_name}-ebs-csi-role"
    Description = "IAM role for AWS EBS CSI driver addon"
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi.name
}

# -------------------------------------------------------------
# EKS Addon: AWS EBS CSI Driver
# -------------------------------------------------------------
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.39.0-eksbuild.1" # Standard active stable addon version
  service_account_role_arn = aws_iam_role.ebs_csi.arn

  depends_on = [
    aws_iam_role_policy_attachment.ebs_csi
  ]
}

# -------------------------------------------------------------
# Kubernetes Storage Class: GP3 (using EBS CSI Driver)
# -------------------------------------------------------------
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
  }
  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"
  reclaim_policy      = "Retain"
  parameters = {
    type = "gp3"
  }

  depends_on = [
    aws_eks_addon.ebs_csi
  ]
}

# -------------------------------------------------------------
# Helm Release: Metrics Server (for horizontal pod autoscaler)
# -------------------------------------------------------------
resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = "3.12.2"
  namespace        = "kube-system"
  create_namespace = false

  # Wait for API server to be ready and avoid certificate errors in self-signed environments
  set = [
    {
      name  = "args[0]"
      value = "--kubelet-insecure-tls"
    }
  ]
}

# -------------------------------------------------------------
# Helm Release: Nginx Ingress Controller
# -------------------------------------------------------------
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.11.3"
  namespace        = "ingress-nginx"
  create_namespace = true

  # Optimizing ELB parameters for AWS
  set = [
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
      value = "nlb"
    }
  ]
}

# -------------------------------------------------------------
# Helm Release: kube-prometheus-stack (Prometheus & Grafana)
# -------------------------------------------------------------
resource "helm_release" "prometheus_stack" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "65.5.0"
  namespace        = "monitoring"
  create_namespace = true

  # Optimizing resource requests for t3.small
  values = [
    <<-EOT
    prometheus:
      prometheusSpec:
        resources:
          requests:
            cpu: 100m
            memory: 512Mi
          limits:
            cpu: 500m
            memory: 1024Mi
        retention: 2d
        storageSpec:
          volumeClaimTemplate:
            spec:
              storageClassName: gp3
              accessModes: ["ReadWriteOnce"]
              resources:
                requests:
                  storage: 5Gi
    grafana:
      adminPassword: "admin"
      service:
        type: LoadBalancer
        annotations:
          service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      persistence:
        enabled: true
        storageClassName: gp3
        size: 2Gi
    alertmanager:
      enabled: false
    EOT
  ]

  depends_on = [
    aws_eks_addon.ebs_csi,
    kubernetes_storage_class_v1.gp3
  ]
}
