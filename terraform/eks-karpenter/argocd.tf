# # 1. Define the IAM Assume Role Policy Document
# data "aws_iam_policy_document" "argocd_assume_role" {
#   statement {
#     effect = "Allow"
#     principals {
#       type = "Service"
#       # The EKS service principal needs to be able to assume the role
#       identifiers = ["eks.amazonaws.com"]
#     }
#     actions = ["sts:AssumeRole"]
#   }
# }

# # 2. Create the IAM Role for the ArgoCD Capability
# resource "aws_iam_role" "eks_capability_role" {
#   name_prefix        = "ArgoCDCapabilityRole"
#   assume_role_policy = data.aws_iam_policy_document.argocd_assume_role.json
# }

# # 3. Define an IAM policy for ArgoCD's specific needs (example for CodeCommit access)
# data "aws_iam_policy_document" "argocd_policy" {
#   statement {
#     effect = "Allow"
#     actions = [
#       "codecommit:GitPull",
#       "codecommit:GitPush"
#     ]
#     resources = ["arn:aws:codecommit:*:*:*"] # Refine this to specific repositories
#   }
# }

# # 4. Attach the policy to the role
# resource "aws_iam_role_policy" "argocd_policy_attachment" {
#   name   = "ArgoCDCustomPolicy"
#   role   = aws_iam_role.eks_capability_role.name
#   policy = data.aws_iam_policy_document.argocd_policy.json
# }

# # 5. Associate the IAM role with the EKS cluster capability
# # resource "aws_eks_capability" "argocd_capability" {
# #   cluster_name    = aws_eks_cluster.my_cluster.name
# #   capability_name = "argocd-gitops"
# #   type            = "ARGOCD"
# #   # The role_arn argument is required
# #   role_arn        = aws_iam_role.eks_capability_role.arn
# # }
# resource "aws_eks_capability" "argocd" {
#   cluster_name              = module.eks.cluster_name #aws_eks_cluster.example.name
#   capability_name           = "argocd"
#   type                      = "ARGOCD"
#   role_arn                  = aws_iam_role.eks_capability_role.arn
#   delete_propagation_policy = "RETAIN"

#   configuration {
#     argo_cd {
#       aws_idc {
#         idc_instance_arn = "arn:aws:sso:::instance/ssoins-1234567890abcdef0"
#       }
#       namespace = "argocd"
#     }
#   }

#   tags = local.tags
# }
