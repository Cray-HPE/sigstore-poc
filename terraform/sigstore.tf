variable "trillian_sa_names" {
  type    = list(string)
  default = ["trillian-checktree", "trillian-logsigner", "trillian-createdb", "trillian-logserver"]
}

resource "helm_release" "sigstore_scaffold" {
  depends_on        = [google_sql_database.database_trillian, google_container_cluster.primary]
  timeout           = "360"
  name              = "sigstore-scaffold"
  chart             = "${var.SIGSTORE_HELM_LOCAL_PATH}/charts/scaffold"
  version           = var.SIGSTORE_HELM_VERSION
  force_update      = true
  cleanup_on_fail   = true
  dependency_update = true
  set {
    name  = "trillian.mysql.gcp.cloudsql.registry"
    value = "gcr.io"
  }
  set {
    name  = "trillian.mysql.gcp.cloudsql.repository"
    value = "chainguard-dev/sqlproxy"
  }
  set {
    name  = "trillian.mysql.gcp.cloudsql.version"
    value = "sha256:a0c3892b23e4d5e0e8edd442bc5de46ab08b1a9668cd4d4bd641eff3d7d2f3ad"
  }
  set {
    name  = "trillain.createdb.image.registry"
    value = "gcr.io"
  }
  set {
    name  = "trillain.createdb.image.repository"
    value = "chainguard-dev/createdb"
  }
  set {
    name  = "trillain.createdb.image.version"
    value = "sha256:718839372b7e35f5f96c5c228e72385374a92dcab57def1cad49cb235e186225"
  }
  set {
    name  = "trillian.mysql.auth.rootPassword"
    value = var.TRILLIAN_PASSWORD
  }
  set {
    name  = "trillian.mysql.auth.password"
    value = var.TRILLIAN_PASSWORD
  }
  set {
    name  = "trillian.mysql.auth.username"
    value = var.TRILLIAN_USERNAME
  }
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
