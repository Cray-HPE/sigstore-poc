terraform {
  backend "local" {
  }
}

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 2.3.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.4.1"
    }
  }
}