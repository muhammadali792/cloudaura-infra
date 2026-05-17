terraform {
  required_version = ">= 1.5.7"
  backend "s3" {
    bucket         = "cloudaura-io-prod-tfstate"
    key            = "platform/addons.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-lock-table"
  }
  required_providers {
    aws = { source = "hashicorp/aws"; version = "~> 6.0" }
    helm = { source = "hashicorp/helm"; version = "~> 2.12" }
  }
}
data "terraform_remote_state" "eks_data" {
  backend = "s3"
  config = {
    bucket = "cloudaura-io-prod-tfstate"
    key    = "infrastructure/eks.tfstate"
    region = "us-east-2"
  }
}
provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.eks_data.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks_data.outputs.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks_data.outputs.cluster_name]
    }
  }
}
