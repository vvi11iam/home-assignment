terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }

  backend "s3" {
    bucket       = "home-assignment-terraform-backend"
    key          = "eks-karpenter.tfstate"
    region       = "ap-southeast-1"
    use_lockfile = false
    encrypt      = true
  }
}
