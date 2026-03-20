locals {
  karpenter_manifest_documents = [
    for document in split("\n---\n", trimspace(file("${path.module}/files/karpenter.yaml"))) : yamldecode(document)
  ]
}

resource "kubernetes_manifest" "karpenter" {
  for_each = {
    for manifest in local.karpenter_manifest_documents :
    "${manifest.kind}-${manifest.metadata.name}" => manifest
  }

  manifest = each.value

  depends_on = [
    helm_release.karpenter,
    module.karpenter,
  ]
}

resource "kubernetes_manifest" "storageclass" {
  manifest = yamldecode(file("${path.module}/files/storageclass.yaml"))

  depends_on = [
    module.eks,
  ]
}
