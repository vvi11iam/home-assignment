resource "null_resource" "apply_storageclass" {
  triggers = {
    cluster_name      = module.eks.cluster_name
    storageclass_hash = filesha256("${path.module}/files/storageclass.yaml")
  }

  provisioner "local-exec" {
    command = "kubectl apply -f ${path.module}/files/storageclass.yaml"
  }

  depends_on = [
    module.eks,
    null_resource.update_kubeconfig,
  ]
}

resource "null_resource" "apply_karpenter_manifests" {
  triggers = {
    cluster_name    = module.eks.cluster_name
    manifest_sha256 = filesha256("${path.module}/files/karpenter.yaml")
  }

  provisioner "local-exec" {
    command = "kubectl apply -f ${path.module}/files/karpenter.yaml"
  }

  depends_on = [
    helm_release.karpenter,
    null_resource.update_kubeconfig,
    null_resource.apply_storageclass,
  ]
}
