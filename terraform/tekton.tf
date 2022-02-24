resource "helm_release" "tekton_pipelines" {
  name             = "tekton-pipelines"
  depends_on       = [google_container_cluster.primary, helm_release.sigstore_scaffold]
  chart            = var.TK_PIPELINE_HELM_LOCAL_PATH
  version          = var.TK_PIPELINE_HELM_CHART_VERSION
  namespace        = var.TK_PIPELINE_NAMESPACE
  create_namespace = true
  recreate_pods    = true
  force_update     = true
  cleanup_on_fail  = true
  set {
    name  = "feature_flags.disable-affinity-assistant"
    value = "true"
  }
}

resource "helm_release" "tekton_dashboard" {
  depends_on       = [helm_release.tekton_pipelines, google_container_cluster.primary]
  name             = "tekton-dashboard"
  chart            = var.TK_DASHBOARD_HELM_LOCAL_PATH
  version          = var.TK_DASHBOARD_HELM_CHART_VERSION
  namespace        = var.TK_PIPELINE_NAMESPACE
  create_namespace = false
  force_update     = true
  recreate_pods    = true
  cleanup_on_fail  = true
}

resource "helm_release" "tekton_chains" {
  depends_on       = [helm_release.tekton_pipelines, google_container_cluster.primary, helm_release.sigstore_scaffold]
  name             = "tekton-chains"
  chart            = var.TK_CHAINS_HELM_LOCAL_PATH
  version          = var.TK_CHAINS_HELM_CHART_VERSION
  namespace        = var.TK_CHAINS_NAMESPACE
  create_namespace = true
  force_update     = true
  recreate_pods    = true
  cleanup_on_fail  = true
  set {
    name  = "tenantconfig.artifacts\\.oci\\.format"
    value = "simplesigning"
  }
  set {
    name  = "tenantconfig.artifacts\\.oci\\.storage"
    value = "oci"
  }
  set {
    name  = "tenantconfig.artifacts\\.taskrun\\.format"
    value = "in-toto"
  }
  set {
    name  = "tenantconfig.signers\\.x509\\.fulcio\\.address" # Connect chains to fulcio service
    value = "http://fulcio.fulcio-system.svc"
  }
  set {
    name  = "tenantconfig.signers\\.x509\\.fulcio\\.enabled"
    value = "true"
  }
  set {
    name  = "tenantconfig.transparency\\.enabled"
    value = "true"
  }
  set {
    name  = "tenantconfig.transparency\\.url" # Connect chains to rekor service
    value = "http://rekor-server.rekor-system.svc:3000"
  }
}

# Chains needs access to the ctlog public key, it is created in the ctlog-system namespace.
# This copies it into the default namespaces where the pipelines are ran.
data "kubernetes_secret" "ctlog-public-key" {
  depends_on = [helm_release.sigstore_scaffold]
  metadata {
    name      = "ctlog-public-key"
    namespace = "ctlog-system"
  }
}

resource "kubernetes_secret" "ctlog-public-key" {
  depends_on = [helm_release.sigstore_scaffold]
  metadata {
    name      = data.kubernetes_secret.ctlog-public-key.metadata[0].name
    namespace = "default"
  }
  data = data.kubernetes_secret.ctlog-public-key.data
}
