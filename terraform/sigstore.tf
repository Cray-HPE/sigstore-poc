variable "trillian_sa_names" {
  type    = list(string)
  default = ["trillian-checktree", "trillian-logsigner", "trillian-createdb", "trillian-logserver"]
}

resource "helm_release" "sigstore_scaffold" {
  depends_on        = [google_sql_database.database_trillian, google_container_cluster.primary]
  timeout           = "300"
  name              = "sigstore-scaffold"
  chart             = "${var.SIGSTORE_HELM_LOCAL_PATH}/charts/scaffold"
  version           = var.SIGSTORE_HELM_VERSION
  force_update      = true
  cleanup_on_fail   = true
  dependency_update = true
  set {
    name  = "trillian.mysql.gcp.enabled"
    value = "true"
  }
  set {
    name  = "trillian.mysql.gcp.instance"
    value = google_sql_database_instance.trillian.connection_name
  }
  set {
    name  = "trillian.mysql.hostname"
    value = "localhost"
  }
  set {
    name  = "trillian.logServer.serviceAccount.annotations.iam\\.gke\\.io\\/gcp-service-account"
    value = google_service_account.dbuser_trillian.email
  }
  set {
    name  = "trillian.logSigner.serviceAccount.annotations.iam\\.gke\\.io\\/gcp-service-account"
    value = google_service_account.dbuser_trillian.email
  }
  set {
    name  = "trillian.createdb.serviceAccount.annotations.iam\\.gke\\.io\\/gcp-service-account"
    value = google_service_account.dbuser_trillian.email
  }
  set {
    name  = "trillian.mysql.enabled"
    value = "false"
  }
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
    value = google_privateca_ca_pool.default.id
  }
  set {
    name  = "fulcio.server.serviceAccount.mountToken"
    value = "true"
  }
  set { #Requires for SA to assume to GCP SA
    name  = "fulcio.server.serviceAccount.annotations.iam\\.gke\\.io\\/gcp-service-account"
    value = google_service_account.gke_workload.email
  }
  set {
    name  = "fulcio.createcerts.serviceAccount.annotations.iam\\.gke\\.io\\/gcp-service-account"
    value = google_service_account.gke_workload.email
  }
}
