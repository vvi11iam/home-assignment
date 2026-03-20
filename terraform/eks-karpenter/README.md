# EKS Karpenter

This directory provisions an Amazon EKS cluster in `ap-southeast-1` with:

- an EKS managed node group used as bootstrap capacity for Karpenter
- the Karpenter IAM resources required for node provisioning
- the Amazon EKS add-on `aws-ebs-csi-driver`
- Terraform-managed IAM roles for the AWS EBS CSI Driver and AWS Load Balancer Controller
- a GitHub Actions OIDC identity provider and deployment role
- an EKS access entry that grants the GitHub Actions role `AmazonEKSEditPolicy` in namespace `app`
- Terraform-managed Helm releases for Karpenter and the AWS Load Balancer Controller
- Terraform-managed Kubernetes manifests for `files/karpenter.yaml` and `files/storageclass.yaml`

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
- EKS add-on `aws-ebs-csi-driver`
- Pod Identity role `AmazonEKS_EBS_CSI_DriverRole`
- IRSA role `AmazonEKS_LoadBalancer_ControllerRole`
- custom policy `AWSLoadBalancerControllerIAMPolicy`
- Helm release `karpenter`
- Helm release `aws-load-balancer-controller`
- Kubernetes manifests for `EC2NodeClass`, `NodePool`, and the default EBS `StorageClass`
- GitHub OIDC provider for `token.actions.githubusercontent.com`
- GitHub Actions role `EKSDeployment`
- EKS access entry for user `github-actions`, scoped to namespace `app`

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

Useful outputs after apply:

```bash
terraform output
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

## Karpenter

Terraform now installs the Karpenter Helm chart from `helm.tf` and applies `files/karpenter.yaml` from `manifests.tf`.

Deploy a test workload that should trigger Karpenter capacity:

```bash
kubectl apply -f files/inflate.yaml
```

Watch Karpenter:

```bash
kubectl logs -f -n kube-system -l app.kubernetes.io/name=karpenter -c controller
kubectl get nodes -L karpenter.sh/registered
kubectl get pods -A -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
```

## AWS EBS CSI Driver

Terraform now installs `aws-ebs-csi-driver` as an Amazon EKS add-on in `module.eks`.

The add-on uses the Terraform-managed role `AmazonEKS_EBS_CSI_DriverRole` through EKS Pod Identity. No separate Helm install is required for this cluster.

Verify the add-on after `terraform apply`:

```bash
aws eks describe-addon \
  --region ap-southeast-1 \
  --cluster-name ex-eks-karpenter \
  --addon-name aws-ebs-csi-driver
```

Terraform also applies the default `StorageClass` from `files/storageclass.yaml`.

Verify the default storage class:

```bash
kubectl get storageclass
```

## AWS Load Balancer Controller

Terraform now installs AWS Load Balancer Controller from `helm.tf`. Terraform still provisions the IAM role and policy, and the Helm release uses that role annotation for the controller service account.

Verify the release after `terraform apply`:

```bash
helm list -n kube-system
kubectl get deployment aws-load-balancer-controller -n kube-system
```

## GitHub Actions Access

Terraform creates a GitHub OIDC provider and the role `EKSDeployment`.

- Trust entity:
  `token.actions.githubusercontent.com`
- Trusted subject:
  `repo:vvi11iam/home-assignment:*`
- IAM policy:
  `eks:DescribeCluster`
- EKS access:
  `AmazonEKSEditPolicy` for namespace `app` only, mapped as user `github-actions`

Your GitHub Actions workflow can assume the role ARN for `EKSDeployment` and then use `aws eks update-kubeconfig` or `kubectl` against the cluster, but its EKS edit rights are intentionally limited to namespace `app`.

## Destroy

Before destroying Terraform-managed resources, remove workloads and any nodes provisioned by Karpenter.

```bash
kubectl delete deployment inflate --ignore-not-found
terraform destroy
```

## Troubleshooting Notes

- If the bootstrap managed node group is stuck in `CREATING`, inspect the EKS node group health first:
  `aws eks describe-nodegroup --region ap-southeast-1 --cluster-name ex-eks-karpenter --nodegroup-name karpenter`
- If you already installed EBS CSI with Helm or another add-on configuration, clean it up before applying this Terraform change so the `aws-ebs-csi-driver` add-on can be created cleanly.
- Karpenter and AWS Load Balancer Controller are now managed by Terraform Helm releases in `helm.tf`. If you already installed either one manually, remove the old release before applying this change.

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

This stack currently returns:

- `cluster_name`
- `cluster_endpoint`
- `update_kubeconfig_command`
- `ebs_csi_driver_role_arn`
- `aws_load_balancer_controller_role_arn`
- `aws_load_balancer_controller_policy_arn`
<!-- END_TF_DOCS -->
