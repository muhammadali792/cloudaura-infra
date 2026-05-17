resource "aws_eks_access_entry" "usman_admin" {
  cluster_name      = data.terraform_remote_state.eks_data.outputs.cluster_name
  principal_arn     = "arn:aws:iam::123456789012:user/usman"
  kubernetes_groups = ["system:masters"]
}
resource "aws_eks_access_policy_association" "usman_policy" {
  cluster_name  = data.terraform_remote_state.eks_data.outputs.cluster_name
  policy_arn    = "arn:aws:eks:aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = "arn:aws:iam::123456789012:user/usman"
  access_scope { type = "cluster" }
}
data "aws_iam_policy_document" "bankapp_s3" {
  statement {
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["arn:aws:s3:::ca-onlineshop-prod-user-images/*"]
  }
}
resource "aws_iam_policy" "bankapp_policy" {
  name   = "production-bankapp-s3-policy"
  policy = data.aws_iam_policy_document.bankapp_s3.json
}
module "eks_pod_identity_bankapp" {
  source  = "terraform-aws-modules/eks/aws//modules/pod-identity"
  version = "~> 21.0"
  name = "production-bankapp-pod-role"
  iam_role_policies = { S3Access = aws_iam_policy.bankapp_policy.arn }
  associations = {
    bankapp_association = {
      cluster_name    = data.terraform_remote_state.eks_data.outputs.cluster_name
      namespace       = "production"
      service_account = "bankapp-sa"
    }
  }
}
