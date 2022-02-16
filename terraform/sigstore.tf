resource "helm_release" "sigstore_scaffold" {
  timeout = "300"
  name             = "sigstore-scaffold"
  chart            = "${var.SIGSTORE_HELM_PATH}/charts/scaffold"
  version          = "0.1.1"
  force_update     = true
  cleanup_on_fail  = true
  dependency_update = true
  set {
    name  = "rekor.server.ingress.enabled"
    value = "false"
  }
  set {
    name  = "fulcio.server.ingress.enabled"
    value = "false"
  }
  set {
    name  = "fulcio.server.args.certificateAuthority"
    value = "googleca"
  }
  set {
    name  = "fulcio.server.args.gcp_private_ca_parent"
    value = google_privateca_certificate_authority.default.name
  }
  set {
    name  = "fulcio.server.serviceAccount.mountToken"
    value = "true"
  }
  set {
    name  = "fulcio.server.serviceAccount.annotations.iam\\.gke\\.io\\/gcp-service-account"
    value = google_service_account.gke_workload.email
  }
  set {
    name  = "fulcio.createcerts.serviceAccount.annotations.iam\\.gke\\.io\\/gcp-service-account"
    value = google_service_account.gke_workload.email
  }
}
