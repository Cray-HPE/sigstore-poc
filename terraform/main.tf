resource "helm_release" "tekton" {
  name             = "tekton-pipelines"
  chart            = var.tk_pl_local
  version          = var.tk_pl_helm_chart_version
  namespace        = var.tk_pl_namespace
  create_namespace = true
  force_update     = true
}


resource "helm_release" "tekton-dashboard" {
  depends_on       = [helm_release.tekton]
  name             = "tekton-dashboard"
  chart            = var.tk_dashboard_local
  version          = var.tk_dashboard_helm_chart_version
  namespace        = var.tk_pl_namespace
  create_namespace = false
  force_update     = true
}


resource "helm_release" "tekton-chains" {
  depends_on       = [helm_release.tekton]
  name             = "tekton-chains"
  chart            = var.tk_chains_local
  version          = var.tk_chains_helm_chart_version
  namespace        = var.tk_chains_namespace
  create_namespace = true
  force_update     = true
}

