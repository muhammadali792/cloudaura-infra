# 1. AWS par naya IAM User banana
resource "aws_iam_user" "cluster_admin" {
  name = "cluster-admin-user"
  tags = {
    Environment = "staging"
  }
}

# 2. IAM User ke liye Access Key aur Secret Key generate karna
resource "aws_iam_access_key" "cluster_admin_key" {
  user = aws_iam_user.cluster_admin.name
}

# 3. EKS Permissions Policy
resource "aws_iam_user_policy" "cluster_admin_eks" {
  name = "cluster-admin-eks-policy"
  user = aws_iam_user.cluster_admin.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi",
          "eks:ListNodegroups",
          "eks:DescribeNodegroup",
          "eks:ListAddons",
          "eks:DescribeAddon",
          "eks:ListFargateProfiles",
          "eks:DescribeFargateProfile",
          "eks:ListUpdates",
          "eks:DescribeUpdate"
        ]
        Resource = "*"
      }
    ]
  })
}

# 4. EKS Access Entry banana
resource "aws_eks_access_entry" "cluster_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_user.cluster_admin.arn
  type          = "STANDARD"
}

# 5. Cluster Admin Policy Associate karna
resource "aws_eks_access_policy_association" "cluster_admin" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_user.cluster_admin.arn
  access_scope {
    type = "cluster"
  }
}

# ==============================================================================
# OUTPUTS
# ==============================================================================
output "admin_user_access_key" {
  value       = aws_iam_access_key.cluster_admin_key.id
  description = "Naye admin user ki Access Key"
}

output "admin_user_secret_key" {
  value     = aws_iam_access_key.cluster_admin_key.secret
  sensitive = true
}
