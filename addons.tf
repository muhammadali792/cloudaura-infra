module "eks_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # =============================================================================
  # NGINX INGRESS + NLB
  # =============================================================================
  enable_ingress_nginx = true
  ingress_nginx = {
    values = [
      yamlencode({
        controller = {
          service = {
            type = "LoadBalancer"
            annotations = {
              "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
              "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
              "service.beta.kubernetes.io/aws-load-balancer-scheme"                            = "internet-facing"
            }
          }
          config = {
            use-forwarded-headers      = "true"
            compute-full-forwarded-for = "true"
          }
        }
      })
    ]
  }

  # =============================================================================
  # ARGOCD
  # =============================================================================
  enable_argocd = true
  argocd = {
    namespace = "argocd"
  }

  # =============================================================================
  # CLUSTER AUTOSCALER
  # =============================================================================
  enable_cluster_autoscaler = true
  cluster_autoscaler = {
    set = [
      {
        name  = "extraArgs.scale-down-delay-after-add"
        value = "2m"
      },
      {
        name  = "extraArgs.scale-down-unneeded-time"
        value = "2m"
      },
      {
        name  = "extraArgs.balance-similar-node-groups"
        value = "true"
      }

    ]
  }

  # =============================================================================
  # METRICS SERVER
  # =============================================================================
  enable_metrics_server = true

  # =============================================================================
  # EXTERNAL SECRETS
  # =============================================================================
  enable_external_secrets = true

  # =============================================================================
  # EXTERNAL DNS
  # =============================================================================
  enable_external_dns = true
  external_dns = {
    set = [
      {
        name  = "domainFilters[0]"
        value = var.domain_name
      },
      {
        name  = "provider"
        value = "aws"
      }
    ]
  }

  # =============================================================================
  # EFS CSI DRIVER
  # =============================================================================
  enable_aws_efs_csi_driver = true

  depends_on = [module.eks]

  tags = local.common_tags
}
