data "aws_caller_identity" "current" {}

data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  cluster_oidc_host        = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  github_actions_oidc_host = "token.actions.githubusercontent.com"

  aws_load_balancer_controller_sa = "system:serviceaccount:kube-system:aws-load-balancer-controller"
  github_actions_sub              = "repo:vvi11iam/home-assignment:*"
}

################################################################################
# IAM Roles for Service Accounts (IRSA)
################################################################################

data "aws_iam_policy_document" "ebs_csi_driver_assume_role" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes-namespace"
      values   = ["kube-system"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes-service-account"
      values   = ["ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name               = "AmazonEKS_EBS_CSI_DriverRole"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver_assume_role.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.cluster_oidc_host}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.cluster_oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.cluster_oidc_host}:sub"
      values   = [local.aws_load_balancer_controller_sa]
    }
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/files/load-balancer-controller-iam-policy.json")

  tags = local.tags
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name               = "AmazonEKS_LoadBalancer_ControllerRole"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

################################################################################
# GitHub Actions OIDC
################################################################################

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://${local.github_actions_oidc_host}"

  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    data.tls_certificate.github_actions.certificates[0].sha1_fingerprint,
  ]

  tags = local.tags
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_actions_oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "${local.github_actions_oidc_host}:sub"
      values   = [local.github_actions_sub]
    }
  }
}

resource "aws_iam_role" "eks_deployment" {
  name               = "EKSDeployment"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = local.tags
}

resource "aws_iam_role_policy" "eks_deployment" {
  name = "EKSDeploymentDescribeCluster"
  role = aws_iam_role.eks_deployment.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
        ]
        Resource = "*"
      },
    ]
  })
}
