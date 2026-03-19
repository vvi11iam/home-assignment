# EKS Karpenter

This directory provisions an Amazon EKS cluster in `ap-southeast-1` with:

- an EKS managed node group used as bootstrap capacity for Karpenter
- the Karpenter IAM resources required for node provisioning
- no in-Terraform Helm releases for Karpenter, EBS CSI, or the AWS Load Balancer Controller

The cluster name is derived from the directory name:

```bash
ex-eks-karpenter
```

## What This Configuration Assumes

- Terraform state is stored in S3 bucket `home-assignment-terraform-backend`
- VPC outputs are read from remote state key `vpc.tfstate`
- The VPC state already exists and exposes:
  `vpc_id`, `private_subnets`, and `intra_subnets`
- AWS region is `ap-southeast-1`

## What Terraform Creates

- EKS cluster version `1.35`
- Bootstrap managed node group `karpenter`
- Karpenter IAM resources, including the node IAM role named `ex-eks-karpenter`

The bootstrap node group is intentionally separate from Karpenter-managed capacity. It exists so the Karpenter controller and core EKS system pods have somewhere to run before Karpenter starts provisioning nodes.

## Prerequisites

- Terraform `>= 1.5.7`
- AWS credentials with permission to manage EKS, IAM, EC2, and the remote state bucket
- AWS CLI configured for the same account and region
- `kubectl`
- `helm`

## Apply

```bash
terraform init
terraform plan
terraform apply
```

## Configure kubectl

```bash
aws eks --region ap-southeast-1 update-kubeconfig --name ex-eks-karpenter
```

Verify the cluster and bootstrap node group:

```bash
kubectl get nodes -L karpenter.sh/controller
kubectl get pods -A
```

## Install Karpenter

This Terraform configuration creates the IAM resources for Karpenter, but it does not install the Karpenter Helm chart. Install the chart separately after the cluster is reachable.

```bash
helm registry logout public.ecr.aws
docker logout public.ecr.aws

export CLUSTER_NAME="ex-eks-karpenter"
export KARPENTER_NAMESPACE="kube-system"
export KARPENTER_VERSION="1.9.0"

helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version "${KARPENTER_VERSION}" \
  --namespace "${KARPENTER_NAMESPACE}" \
  --create-namespace \
  --set "settings.clusterName=${CLUSTER_NAME}" \
  --set "settings.interruptionQueue=${CLUSTER_NAME}" \
  --wait
```

Apply the sample `EC2NodeClass` and `NodePool`:

```bash
kubectl apply -f karpenter.yaml
```

Deploy a test workload that should trigger Karpenter capacity:

```bash
kubectl apply -f inflate.yaml
```

Watch Karpenter:

```bash
kubectl logs -f -n kube-system -l app.kubernetes.io/name=karpenter -c controller
kubectl get nodes -L karpenter.sh/registered
kubectl get pods -A -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
```

## Install AWS EBS CSI Driver With Helm and IRSA

Use either the EKS add-on or the Helm chart, not both. If `aws-ebs-csi-driver` was previously installed as an EKS add-on, remove the add-on and its leftover resources before installing the Helm chart.

Create the IRSA role for the controller service account:

```bash
export AWS_REGION=ap-southeast-1
export CLUSTER_NAME=ex-eks-karpenter
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ROLE_NAME=AmazonEKS_EBS_CSI_DriverRole
export OIDC_ISSUER=$(aws eks describe-cluster --region "${AWS_REGION}" --name "${CLUSTER_NAME}" --query 'cluster.identity.oidc.issuer' --output text)
export OIDC_HOST=${OIDC_ISSUER#https://}
```

```bash
tee aws-ebs-csi-driver-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_HOST}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_HOST}:aud": "sts.amazonaws.com",
          "${OIDC_HOST}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }
  ]
}
EOF
```

```bash
aws iam create-role \
  --role-name "${ROLE_NAME}" \
  --assume-role-policy-document file://aws-ebs-csi-driver-trust-policy.json

aws iam attach-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy
```

Install the Helm chart:

```bash
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update

helm upgrade --install aws-ebs-csi-driver \
  aws-ebs-csi-driver/aws-ebs-csi-driver \
  -n kube-system \
  --create-namespace \
  --set controller.region="${AWS_REGION}" \
  --set-string controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME} \
  --set defaultStorageClass.enabled=true
```

Important for `zsh`: keep the variable braces in the ARN. Without braces, `zsh` can treat `:role` as a modifier and produce an invalid ARN.

Verify the service account annotation:

```bash
kubectl get sa ebs-csi-controller-sa -n kube-system -o yaml
```

## Install AWS Load Balancer Controller With IRSA

Create the IAM role:

```bash
export AWS_REGION=ap-southeast-1
export CLUSTER_NAME=ex-eks-karpenter
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ROLE_NAME=AmazonEKS_LoadBalancer_ControllerRole
export OIDC_ISSUER=$(aws eks describe-cluster --region "${AWS_REGION}" --name "${CLUSTER_NAME}" --query 'cluster.identity.oidc.issuer' --output text)
export OIDC_HOST=${OIDC_ISSUER#https://}
```

```bash
tee aws-load-balancer-controller-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_HOST}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_HOST}:aud": "sts.amazonaws.com",
          "${OIDC_HOST}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }
  ]
}
EOF
```

Download the recommended controller policy and attach it:

```bash
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam-policy.json

aws iam create-role \
  --role-name "${ROLE_NAME}" \
  --assume-role-policy-document file://aws-load-balancer-controller-trust-policy.json

aws iam attach-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy
```

Install the controller:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm upgrade --install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  -n kube-system \
  --create-namespace \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set-string serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME} \
  --set region="${AWS_REGION}" \
  --set vpcId=$(aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER_NAME" --query 'cluster.resourcesVpcConfig.vpcId' --output text)
```

## Destroy

Before destroying Terraform-managed resources, remove workloads and any nodes provisioned by Karpenter.

```bash
kubectl delete deployment inflate --ignore-not-found
terraform destroy
```

## Troubleshooting Notes

- If the bootstrap managed node group is stuck in `CREATING`, inspect the EKS node group health first:
  `aws eks describe-nodegroup --region ap-southeast-1 --cluster-name ex-eks-karpenter --nodegroup-name karpenter`
- If Helm install for EBS CSI fails because resources are labeled `managed-by: EKS`, remove the existing EKS add-on resources before retrying the Helm install.
- If the EBS CSI controller reports `Request ARN is invalid`, check the `eks.amazonaws.com/role-arn` annotation for a malformed value and verify the `zsh` variable expansion used when applying the Helm chart.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.28 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.28 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | n/a |
| <a name="module_karpenter"></a> [karpenter](#module\_karpenter) | terraform-aws-modules/eks/aws//modules/karpenter | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END_TF_DOCS -->
