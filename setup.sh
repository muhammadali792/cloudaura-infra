#!/bin/bash

echo "🔄 Starting Infrastructure Fresh Setup..."

# Step 1: Purani saari files aur folders ko delete karna (Swaye .git folder ke)
echo "🧹 Cleaning up old files..."
find . -maxdepth 1 ! -name '.' ! -name '.git' ! -name 'setup.sh' -exec rm -rf {} +
rm -rf .github

# Step 2: GitHub Workflow folder structure banana
echo "📁 Creating directory structure..."
mkdir -p .github/workflows

# ==========================================
# Step 3: Nayi production-grade files generate karna
# ==========================================

echo "📝 Writing providers.tf..."
cat << 'EOF' > providers.tf
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}
EOF

echo "📝 Writing variables.tf..."
cat << 'EOF' > variables.tf
variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "environment" {
  type    = string
  default = "staging"
}

variable "cluster_name" {
  type    = string
  default = "cloudaura-eks-cluster"
}
EOF

echo "📝 Writing vpc.tf..."
cat << 'EOF' > vpc.tf
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "cloudaura-${var.environment}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
EOF

echo "📝 Writing security_groups.tf..."
cat << 'EOF' > security_groups.tf
resource "aws_security_group" "additional_node_sg" {
  name        = "cloudaura-${var.environment}-node-additional-sg"
  description = "Additional security group for EKS worker nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow all internal traffic between nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
    Name        = "cloudaura-${var.environment}-node-additional-sg"
  }
}
EOF

echo "📝 Writing eks.tf..."
cat << 'EOF' > eks.tf
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    general = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      additional_security_group_ids = [aws_security_group.additional_node_sg.id]
    }
  }

  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "eks_ebs_csi_policy" {
  for_each   = module.eks.eks_managed_node_groups
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role_name  = each.value.iam_role_name
}
EOF

echo "📝 Writing GitHub Workflow Pipeline..."
cat << 'EOF' > .github/workflows/gitops-pipeline.yml
name: "Cloudaura GitOps Infrastructure Pipeline"

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

permissions:
  id-token: write
  contents: read

jobs:
  terraform:
    name: "Terraform Run"
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.0"

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}
          audience: sts.amazonaws.com

      - name: Terraform Init
        run: |
          terraform init \
            -backend-config="bucket=${{ vars.TF_STATE_BUCKET }}" \
            -backend-config="key=staging/eks-cluster/terraform.tfstate" \
            -backend-config="region=${{ vars.AWS_REGION }}" \
            -backend-config="dynamodb_table=${{ vars.TF_LOCK_TABLE }}"

      - name: Terraform Format Check
        run: terraform fmt -check

      - name: Terraform Plan
        run: terraform plan -input=false

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve -input=false
EOF

# ==========================================
# Step 4: GitHub par Push karna
# ==========================================

echo "🚀 Pushing fresh code to GitHub..."
git add .
git commit -m "chore: full clean reset and add modular eks configuration with gitops pipeline"
git push origin main

# Cleanup setup script itself so local remains neat
rm setup.sh

echo "✅ Success! Everything is cleaned, newly written, and pushed to GitHub."
echo "🎯 Go check your GitHub Actions tab right now!"
