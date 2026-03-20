# provider "aws" {
#   alias  = "use1"
#   region = "us-east-1"
# }

# data "aws_ecrpublic_authorization_token" "karpenter" {
#   provider = aws.use1
# }

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = "kube-system"
  create_namespace = false

  repository          = "oci://public.ecr.aws/karpenter"
  # repository_username = data.aws_ecrpublic_authorization_token.karpenter.user_name
  # repository_password = data.aws_ecrpublic_authorization_token.karpenter.password
  chart               = "karpenter"
  version             = "1.9.0"

  values = [
    yamlencode({
      nodeSelector = {
        "karpenter.sh/controller" = "true"
      }
      settings = {
        clusterName       = module.eks.cluster_name
        interruptionQueue = module.karpenter.queue_name
      }
    }),
  ]

  depends_on = [
    module.eks,
    module.karpenter,
  ]
}

resource "helm_release" "aws_load_balancer_controller" {
  name             = "aws-load-balancer-controller"
  namespace        = "kube-system"
  create_namespace = false

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"

  values = [
    yamlencode({
      clusterName = module.eks.cluster_name
      region      = local.region
      vpcId       = data.terraform_remote_state.vpc.outputs.vpc_id
      serviceAccount = {
        name = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
        }
      }
    }),
  ]

  depends_on = [
    module.eks,
    aws_iam_role_policy_attachment.aws_load_balancer_controller,
  ]
}
