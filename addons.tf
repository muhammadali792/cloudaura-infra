# ==========================================
# 1. ARGOCD INSTALLATION
# ==========================================
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
  depends_on = [module.eks]
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.51.4"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  set {
    name  = "server.insecure"
    value = "true" # ArgoCD ka apna SSL offload kar rahe hain kyunki Ingress handle karega TLS
  }
  depends_on = [module.eks]
}

# ==========================================
# 2. CERT-MANAGER (Self-Signed Certificate Engine)
# ==========================================
resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
  depends_on = [module.eks]
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.13.3"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name

  set {
    name  = "installCRDs"
    value = "true" # Kubernetes ko Cert-Manager ke resources samjhane ke liye LAZMI hai
  }
  depends_on = [module.eks]
}

# Cluster-wide Certificate Issuer (Jo certificate sign karega)
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

# ==========================================
# 3. NGINX INGRESS CONTROLLER (AWS Load Balancer Creator)
# ==========================================
resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }
  depends_on = [module.eks]
}

resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.9.0"
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name

  # AWS specific annotations jo peeche Network Load Balancer (NLB) banati hain
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }
  depends_on = [module.eks, module.vpc]
}

# ==========================================
# 4. INGRESS RULE FOR ARGOCD (The Bridge)
# ==========================================
resource "kubernetes_manifest" "argocd_ingress" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "argocd-server-ingress"
      namespace = "argocd"
      annotations = {
        "kubernetes.io/ingress.class"                      = "nginx"
        "cert-manager.io/cluster-issuer"                   = "selfsigned-issuer" # Cert manager ko call karna
        "nginx.ingress.kubernetes.io/ssl-redirect"         = "true"              # HTTP ko HTTPS par bhejna
        "nginx.ingress.kubernetes.io/backend-protocol"     = "HTTP"
      }
    }
    spec = {
      tls = [{
        hosts      = ["*"] # Kisi bhi domain/URL par TLS activate kar do
        secretName = "argocd-server-tls"
      }]
      rules = [{
        http = {
          paths = [{
            path     = "/"
            pathType = "Prefix"
            backend = {
              service = {
                name = "argocd-server"
                port = {
                  name = "http"
                }
              }
            }
          }]
        }
      }]
    }
  }
  depends_on = [helm_release:argocd, helm_release:nginx_ingress, kubernetes_manifest:selfsigned_issuer]
}
