resource "null_resource" "update_kubeconfig" {
  triggers = {
    cluster_name     = module.eks.cluster_name
    cluster_endpoint = module.eks.cluster_endpoint
    region           = local.region
  }

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name}"
  }

  depends_on = [
    module.eks,
  ]
}
