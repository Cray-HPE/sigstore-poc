variable "config_context" {
  default = "kind-tekton-tf-dev"
}

data "google_container_cluster" "primary" {
  depends_on = [google_container_cluster.primary]
  name = google_container_cluster.primary.name
}
provider "helm" {
  kubernetes {
    host                   = data.google_container_cluster.primary.endpoint
    token                  = data.google_client_config.provider.access_token

    client_certificate     = base64decode(data.google_container_cluster.primary.master_auth.0.client_certificate)
    client_key             = base64decode(data.google_container_cluster.primary.master_auth.0.client_key)
    cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
  }
}

data "google_client_config" "provider" {}

provider "google" {
  project = var.PROJECT_ID
  region  = var.DEFAULT_LOCATION
  zone    = var.CLUSTER_LOCATION
}

provider "kubernetes" {
  host                   = google_container_cluster.primary.endpoint
  token                  = data.google_client_config.provider.access_token

  client_certificate     = base64decode(google_container_cluster.primary.master_auth.0.client_certificate)
  client_key             = base64decode(google_container_cluster.primary.master_auth.0.client_key)
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
}