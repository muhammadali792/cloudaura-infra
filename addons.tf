# 1. Cert-Manager Deployment
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.14.0"
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true
  timeout          = 600

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [module.eks]
}

# 2. ArgoCD Deployment
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.52.0"
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 300

  depends_on = [module.eks]
}

# 3. Nginx Ingress Controller
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.9.0"
  namespace        = "ingress-nginx"
  create_namespace = true
  wait             = true
  timeout          = 300
  disable_webhooks = true

  depends_on = [module.eks]
}

# 4. Prometheus Stack
resource "helm_release" "prometheus_stack" {
  name             = "prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "57.0.3"
  namespace        = "monitoring"
  create_namespace = true
  wait             = true
  timeout          = 600

  set {
    name  = "grafana.enabled"
    value = "true"
  }

  set {
    name  = "grafana.adminPassword"
    value = "admin123"
  }

  set {
    name  = "grafana.service.type"
    value = "ClusterIP"
  }

  set {
    name  = "prometheus.enabled"
    value = "true"
  }

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "15d"
  }

  set {
    name  = "alertmanager.enabled"
    value = "true"
  }

  depends_on = [module.eks, helm_release.cert_manager]
}

# 5. ClusterIssuer - Self Signed
resource "kubernetes_manifest" "selfsigned_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "selfsigned-issuer"
    }
    spec = {
      selfSigned = {}
    }
  }
  depends_on = [helm_release.cert_manager]
}

# 6. ArgoCD Ingress
resource "kubernetes_manifest" "argocd_ingress" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "argocd-server-ingress"
      namespace = "argocd"
      annotations = {
        "cert-manager.io/cluster-issuer"               = "selfsigned-issuer"
        "nginx.ingress.kubernetes.io/ssl-redirect"     = "true"
        "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
      }
    }
    spec = {
      ingressClassName = "nginx"
      rules = [
        {
          host = "argocd.cloudaura.local"
          http = {
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "argocd-server"
                    port = {
                      name = "https"
                    }
                  }
                }
              }
            ]
          }
        }
      ]
      tls = [
        {
          hosts      = ["argocd.cloudaura.local"]
          secretName = "argocd-server-tls"
        }
      ]
    }
  }
  depends_on = [
    helm_release.argocd,
    helm_release.nginx_ingress,
    kubernetes_manifest.selfsigned_issuer
  ]
}

# 7. Grafana Ingress
resource "kubernetes_manifest" "grafana_ingress" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "grafana-ingress"
      namespace = "monitoring"
      annotations = {
        "cert-manager.io/cluster-issuer"           = "selfsigned-issuer"
        "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
      }
    }
    spec = {
      ingressClassName = "nginx"
      rules = [
        {
          host = "grafana.cloudaura.local"
          http = {
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "prometheus-stack-grafana"
                    port = {
                      number = 80
                    }
                  }
                }
              }
            ]
          }
        }
      ]
      tls = [
        {
          hosts      = ["grafana.cloudaura.local"]
          secretName = "grafana-tls"
        }
      ]
    }
  }
  depends_on = [
    helm_release.prometheus_stack,
    helm_release.nginx_ingress,
    kubernetes_manifest.selfsigned_issuer
  ]
}

# 8. Prometheus Ingress
resource "kubernetes_manifest" "prometheus_ingress" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "prometheus-ingress"
      namespace = "monitoring"
      annotations = {
        "cert-manager.io/cluster-issuer"           = "selfsigned-issuer"
        "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
      }
    }
    spec = {
      ingressClassName = "nginx"
      rules = [
        {
          host = "prometheus.cloudaura.local"
          http = {
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "prometheus-stack-kube-prom-prometheus"
                    port = {
                      number = 9090
                    }
                  }
                }
              }
            ]
          }
        }
      ]
      tls = [
        {
          hosts      = ["prometheus.cloudaura.local"]
          secretName = "prometheus-tls"
        }
      ]
    }
  }
  depends_on = [
    helm_release.prometheus_stack,
    helm_release.nginx_ingress,
    kubernetes_manifest.selfsigned_issuer
  ]
}
