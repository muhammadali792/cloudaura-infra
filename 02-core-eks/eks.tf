module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name                    = local.name
  kubernetes_version      = "1.31"
  endpoint_public_access  = true
  endpoint_private_access = true

  enable_cluster_creator_admin_permissions = true

  addons = {
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni                = { most_recent = true, before_compute = true }
    eks-pod-identity-agent = { most_recent = true, before_compute = true }
    aws-ebs-csi-driver     = { most_recent = true }
  }

  vpc_id                   = data.terraform_remote_state.vpc_data.outputs.vpc_id
  subnet_ids               = data.terraform_remote_state.vpc_data.outputs.private_subnets
  control_plane_subnet_ids = data.terraform_remote_state.vpc_data.outputs.intra_subnets

  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node communication - allow all internal traffic"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    ingress_lb_http = {
      description = "Allow incoming HTTP traffic from specific public ALB"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
    }
    egress_secure_internet = {
      description = "Allow nodes to get updates and talk to AWS APIs"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  eks_managed_node_groups = {
    bankapp-ng = {
      min_size     = 2
      max_size     = 5
      desired_size = 2
      instance_types = ["t3.large"]
      capacity_type  = "SPOT"

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
      tags = { Environment = "Production" }
    }
  }
  tags = local.tags
}
