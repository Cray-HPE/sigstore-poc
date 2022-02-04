resource "google_container_registry" "registry" {
  project  = var.PROJECT_ID
  location = "US"
}

resource "google_service_account" "gke-user" {
  account_id   = "gke-user-${var.workspace_id}"
  display_name = "GKE Service Account"
  project      = var.PROJECT_ID
}

resource "google_project_iam_member" "gcr_member" {
  project = var.PROJECT_ID
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.gke-user.email}"
}

resource "google_service_account" "gke-workload" {
  account_id   = "${var.workspace_id}-user-workload"
  display_name = "GKE Service Account Workload user"
  project      = var.PROJECT_ID
}

resource "google_service_account_iam_member" "workload-account-iam" {
  role    = "roles/iam.workloadIdentityUser"
  member  = "serviceAccount:${var.PROJECT_ID}.svc.id.goog[default/gke-user]"
  service_account_id = google_service_account.gke-workload.name
  depends_on = [google_service_account.gke-workload]
}

resource "google_project_iam_member" "storage_admin_member" {
  project = var.PROJECT_ID
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.gke-workload.email}"
  depends_on = [google_service_account.gke-workload]
}

resource "kubernetes_service_account" "gcr" {
  metadata {
    name = "gke-user"
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.gke-workload.email
    }
  }
}

variable "workspace_id" {
  type = string
}
resource "google_container_cluster" "primary" {
  name               = "chainguard-dev-${var.workspace_id}"
  location           = var.CLUSTER_LOCATION != "" ? var.CLUSTER_LOCATION : var.DEFAULT_LOCATION
  project            = var.PROJECT_ID
  initial_node_count = 2
  node_config {
    machine_type = "n1-standard-4"
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.gke-user.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  timeouts {
    create = "30m"
    update = "40m"
  }
  workload_identity_config {
    workload_pool = "${var.PROJECT_ID}.svc.id.goog"
  }
}

variable "PROJECT_ID" {
  type    = string
  default = "chainguard-dev"
  validation {
    condition     = length(var.PROJECT_ID) > 0
    error_message = "Must specify PROJECT_ID variable."
  }
}

variable "DEFAULT_LOCATION" {
  type        = string
  description = "Default location for to create Cloud SQL instance in."
  default     = "us-east1"
}

variable "CLUSTER_LOCATION" {
  type        = string
  description = "Zone or Region to create cluster in."
  default     = "us-east1-b"
}
