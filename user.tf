# 1. AWS par naya IAM User banana
resource "aws_iam_user" "cluster_admin" {
  name = "cluster-admin-user" # 🚀 Aap apni marzi ka naam rakh sakte hain
  tags = {
    Environment = "staging"
  }
}

# 2. IAM User ke liye Access Key aur Secret Key generate karna (taake woh login ho sake)
resource "aws_iam_access_key" "cluster_admin_key" {
  user = aws_iam_user.cluster_admin.name
}

# 3. EKS Access Entry banana (EKS ko batana ke yeh user cluster me allowed hai)
resource "aws_eks_access_entry" "cluster_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_user.cluster_admin.arn
  type          = "STANDARD"
}

# 4. Us user ko poore Cluster ka Admin (AmazonEKSClusterAdminPolicy) banana
resource "aws_eks_access_policy_association" "cluster_admin" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_user.cluster_admin.arn

  access_scope {
    type = "cluster" # 🚀 Matlab poore cluster par admin quyền honge
  }
}

# ==============================================================================
# 📋 OUTPUTS (Terraform apply hone ke baad keys screen par show karne ke liye)
# ==============================================================================
output "admin_user_access_key" {
  value       = aws_iam_access_key.cluster_admin_key.id
  description = "Naye admin user ki Access Key"
}

output "admin_user_secret_key" {
  value     = aws_iam_access_key.cluster_admin_key.secret
  sensitive = true # 🚀 Taake log me leak na ho, hum command se nikalenge
}
