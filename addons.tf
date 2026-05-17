# 1. Cert-Manager Deployment
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.14.0"
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}

# 2. ArgoCD Deployment
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.52.0"
  namespace        = "argocd"
  create_namespace = true

  # 🚀 Pipeline timeout se bachne ke liye wait false kiya hai
  wait = false
}

# 3. Nginx Ingress Controller
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.9.0"
  namespace        = "ingress-nginx"
  create_namespace = true

  # 🚀 Ziddi timeout aur webhooks ko bypass karne ke liye important settings:
  wait             = false
  wait_for_jobs    = false
  disable_webhooks = true
}

# ==============================================================================
# ⚠️ KUBERNETES MANIFESTS (Temporary Commented Out for Bootstrapping)
# Cluster poora banne ke baad, hum inko uncomment karke dobara push karenge.
# ==============================================================================
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

resource "kubernetes_manifest" "argocd_ingress" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "argocd-server-ingress"
      namespace = "argocd"
      annotations = {
        "cert-manager.io/cluster-issuer"             = "selfsigned-issuer"
        "nginx.ingress.kubernetes.io/ssl-redirect"   = "true"
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
  depends_on = [helm_release.argocd, helm_release.nginx_ingress, kubernetes_manifest.selfsigned_issuer]
}
*/
