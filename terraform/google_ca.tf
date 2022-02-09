resource "google_privateca_ca_pool" "default" {
  name     = "sigstore-poc-${var.workspace_id}"
  location = var.DEFAULT_LOCATION
  tier     = "DEVOPS"
  publishing_options {
    publish_ca_cert = true
    publish_crl     = false
  }
  issuance_policy {
    allowed_key_types {
      elliptic_curve {
        signature_algorithm = "ECDSA_P384"
      }
    }
    maximum_lifetime            = "50000s"
    allowed_issuance_modes {

      allow_csr_based_issuance    = true
      allow_config_based_issuance = true
    }
  }

}

resource "google_service_account_iam_member" "createcerts-account-iam" {
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.PROJECT_ID}.svc.id.goog[fulcio-system/createcerts]"
  service_account_id = google_service_account.gke-workload.name
  depends_on         = [google_service_account.gke-workload]
}


resource "google_service_account_iam_member" "fulcio-account-iam" {
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.PROJECT_ID}.svc.id.goog[fulcio-system/fulcio]"
  service_account_id = google_service_account.gke-workload.name
  depends_on         = [google_service_account.gke-workload]
}

output "gcp_private_ca_parent" {
  value = google_privateca_ca_pool.default.id
}