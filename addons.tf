module "eks_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # NGINX INGRESS + NLB
  enable_ingress_nginx = true
  ingress_nginx = {
    values = [
      yamlencode({
        controller = {
          replicaCount = 3

          topologySpreadConstraints = [
            {
              maxSkew           = 1
              topologyKey       = "topology.kubernetes.io/zone"
              whenUnsatisfiable = "DoNotSchedule"
              labelSelector = {
                matchLabels = {
                  "app.kubernetes.io/name" = "ingress-nginx"
                }
              }
            }
          ]

          resources = {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }

          service = {
            type                  = "LoadBalancer"
            externalTrafficPolicy = "Local"
            annotations = {
              "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
              "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
              "service.beta.kubernetes.io/aws-load-balancer-scheme"                            = "internet-facing"
              "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"                   = "instance"
              "service.beta.kubernetes.io/aws-load-balancer-health-check-path"                 = "/healthz"
              "service.beta.kubernetes.io/aws-load-balancer-health-check-port"                 = "10254"
              "service.beta.kubernetes.io/aws-load-balancer-health-check-protocol"             = "HTTP"
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

  # ARGOCD
  enable_argocd = true
  argocd = {
    namespace = "argocd"
  }

  # CLUSTER AUTOSCALER
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

  # METRICS SERVER
  enable_metrics_server = true

  # EXTERNAL SECRETS
  enable_external_secrets = true

  # EXTERNAL DNS
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

  # EFS CSI DRIVER
  enable_aws_efs_csi_driver = true

  # SECRETS STORE CSI DRIVER
  enable_secrets_store_csi_driver              = true
  enable_secrets_store_csi_driver_provider_aws = true
  secrets_store_csi_driver = {
    set = [
      {
        name  = "syncSecret.enabled"
        value = "true"
      },
      {
        name  = "enableSecretRotation"
        value = "true"
      }
    ]
  }

  depends_on = [module.eks]
  tags       = local.common_tags
}
