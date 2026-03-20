# EKS Karpenter

This directory provisions an Amazon EKS cluster in `ap-southeast-1` with:

- an EKS managed node group used as bootstrap capacity for Karpenter
- the Amazon EKS add-on `aws-ebs-csi-driver`
- Terraform-managed IAM roles for:
  EBS CSI Driver, AWS Load Balancer Controller, and GitHub Actions
- Terraform-managed Helm releases for:
  Karpenter and AWS Load Balancer Controller
- `null_resource`-managed `kubectl apply` for:
  `files/karpenter.yaml` and `files/storageclass.yaml`
- an EKS access entry that grants the GitHub Actions role `AmazonEKSEditPolicy` in namespace `app`

The cluster name is derived from the directory name:

```bash
ex-eks-karpenter
```

## What This Stack Assumes

- Terraform state is stored in S3 bucket `home-assignment-terraform-backend`
- VPC outputs are read from remote state key `vpc.tfstate`
- The VPC state already exists and exposes:
  `vpc_id`, `private_subnets`, and `intra_subnets`
- AWS region is `ap-southeast-1`
- `aws`, `kubectl`, and `helm` are installed where Terraform runs

## What Terraform Creates

- EKS cluster version `1.35`
- bootstrap managed node group `karpenter`
- Karpenter IAM resources, including node role `ex-eks-karpenter`
- EKS add-on `aws-ebs-csi-driver`
- Pod Identity role `AmazonEKS_EBS_CSI_DriverRole`
- IRSA role `AmazonEKS_LoadBalancer_ControllerRole`
- custom policy `AWSLoadBalancerControllerIAMPolicy`
- GitHub OIDC provider for `token.actions.githubusercontent.com`
- GitHub Actions role `EKSDeployment`
- EKS access entry for user `github-actions`, scoped to namespace `app`
- `null_resource.update_kubeconfig`
- `null_resource.apply_storageclass`
- `null_resource.apply_karpenter_manifests`
- Helm release `karpenter`
- Helm release `aws-load-balancer-controller`

The bootstrap node group is intentionally separate from Karpenter-managed capacity. It gives the Karpenter controller and core system pods a place to run before Karpenter starts provisioning nodes.

## Apply

```bash
terraform init
terraform plan
terraform apply
```

If the Helm provider cannot connect to the cluster during the first apply, do the apply in two steps:

```bash
terraform apply -target=module.eks -target=module.karpenter
terraform apply
```

The stack also includes a `null_resource` that runs:

```bash
aws eks update-kubeconfig --region ap-southeast-1 --name ex-eks-karpenter
```

Useful outputs:

```bash
terraform output
```

## Verify Cluster Access

```bash
aws eks --region ap-southeast-1 update-kubeconfig --name ex-eks-karpenter
kubectl get nodes -L karpenter.sh/controller
kubectl get pods -A
```

## Karpenter

Terraform installs the Karpenter Helm chart from [helm.tf](/Users/nganngan/Downloads/hackathon-starter/terraform/eks-karpenter/helm.tf).

After the Helm release is healthy, Terraform applies `files/karpenter.yaml` automatically by `null_resource.apply_karpenter_manifests`.

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

Terraform installs `aws-ebs-csi-driver` as an Amazon EKS add-on in [main.tf](/Users/nganngan/Downloads/hackathon-starter/terraform/eks-karpenter/main.tf). The add-on uses the Terraform-managed role `AmazonEKS_EBS_CSI_DriverRole` through EKS Pod Identity.

Verify the add-on:

```bash
aws eks describe-addon \
  --region ap-southeast-1 \
  --cluster-name ex-eks-karpenter \
  --addon-name aws-ebs-csi-driver
```

Terraform applies `files/storageclass.yaml` automatically by `null_resource.apply_storageclass`.

Verify:

```bash
kubectl get storageclass
```

## AWS Load Balancer Controller

Terraform installs AWS Load Balancer Controller from [helm.tf](/Users/nganngan/Downloads/hackathon-starter/terraform/eks-karpenter/helm.tf). The controller service account is annotated with the Terraform-managed IAM role `AmazonEKS_LoadBalancer_ControllerRole`.

Verify the release:

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

That role can update kubeconfig and access the cluster, but its EKS edit rights are intentionally limited to namespace `app`.

## Destroy

Before destroying Terraform-managed resources, remove workloads and any nodes provisioned by Karpenter:

```bash
kubectl delete deployment inflate --ignore-not-found
terraform destroy
```

## Troubleshooting

- If the bootstrap managed node group is stuck in `CREATING`, inspect the EKS node group health first:
  `aws eks describe-nodegroup --region ap-southeast-1 --cluster-name ex-eks-karpenter --nodegroup-name karpenter`
- If Terraform fails with `no client config` while planning Helm resources, create the cluster first with a targeted apply, then run a normal apply.
- If you already installed EBS CSI with Helm or another add-on configuration, clean it up before applying this stack so `aws-ebs-csi-driver` can be created cleanly.
- If you already installed Karpenter or AWS Load Balancer Controller manually, remove the old releases before applying this stack.

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
