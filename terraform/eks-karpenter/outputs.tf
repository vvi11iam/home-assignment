output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "The endpoint of the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "update_kubeconfig_command" {
  description = "The command to update kubeconfig for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${local.region} --name ${module.eks.cluster_name}"
}

output "ebs_csi_driver_role_arn" {
  description = "IAM role ARN for the EBS CSI controller service account"
  value       = aws_iam_role.ebs_csi_driver.arn
}

output "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller service account"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "aws_load_balancer_controller_policy_arn" {
  description = "Custom IAM policy ARN for the AWS Load Balancer Controller"
  value       = aws_iam_policy.aws_load_balancer_controller.arn
}
