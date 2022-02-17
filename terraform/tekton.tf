resource "helm_release" "tekton_pipelines" {
  name             = "tekton-pipelines"
  depends_on       = [google_container_cluster.primary]
  chart            = var.TK_PIPELINE_HELM_LOCAL_PATH
  version          = var.TK_PIPELINE_HELM_CHART_VERSION
  namespace        = var.TK_PIPELINE_NAMESPACE
  create_namespace = true
  force_update     = true
  cleanup_on_fail  = true
}

resource "helm_release" "tekton_dashboard" {
  depends_on       = [helm_release.tekton_pipelines, google_container_cluster.primary]
  name             = "tekton-dashboard"
  chart            = var.TK_DASHBOARD_HELM_LOCAL_PATH
  version          = var.TK_DASHBOARD_HELM_CHART_VERSION
  namespace        = var.TK_PIPELINE_NAMESPACE
  create_namespace = false
  force_update     = true
  cleanup_on_fail  = true
}

resource "helm_release" "tekton_chains" {
  depends_on       = [helm_release.tekton_pipelines, google_container_cluster.primary]
  name             = "tekton-chains"
  chart            = var.TK_CHAINS_HELM_LOCAL_PATH
  version          = var.TK_CHAINS_HELM_CHART_VERSION
  namespace        = var.TK_CHAINS_NAMESPACE
  create_namespace = true
  force_update     = true
  cleanup_on_fail  = true
}
