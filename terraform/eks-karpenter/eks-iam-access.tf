resource "aws_eks_access_entry" "github_actions" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.eks_deployment.arn
  type          = "STANDARD"
  user_name     = "github-actions"

  tags = local.tags
}

resource "aws_eks_access_policy_association" "github_actions_edit_app" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.eks_deployment.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["app"]
  }

  depends_on = [aws_eks_access_entry.github_actions]
}
