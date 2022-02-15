resource "helm_release" "sigstore_scaffold" {
  timeout = "300"
  name             = "sigstore-scaffold"
  chart            = "${var.SIGSTORE_HELM_PATH}/charts/scaffold"
  version          = "0.1.0"
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
}

#resource "helm_release" "trillian" {
#  timeout = "600"
#  name             = "trillian"
#  chart            = "${var.SIGSTORE_HELM_PATH}/charts/trillian"
#  version          = "0.1.0"
#  namespace        = "trillian-system"
#  create_namespace = true
#  force_update     = true
#  cleanup_on_fail  = true
#}
#
#resource "helm_release" "rekor" {
#  timeout = "600"
#  depends_on = [helm_release.trillian]
#  name             = "rekor"
#  chart            = "${var.SIGSTORE_HELM_PATH}/charts/rekor"
#  version          = "0.1.0"
#  namespace        = "rekor-system"
#  create_namespace = true
#  force_update     = true
#  cleanup_on_fail  = true
#  set {
#    name  = "server.ingress.enabled"
#    value = "false"
#  }
#  set {
#    name  = "trillian.logServer.name"
#    value = "trillian-trillian-log-server"
#  }
#}
#
#resource "helm_release" "fulcio" {
#  timeout = "600"
#  name             = "fulcio"
#  chart            = "${var.SIGSTORE_HELM_PATH}/charts/fulcio"
#  version          = "0.1.0"
#  namespace        = "fulcio-system"
#  create_namespace = true
#  force_update     = true
#  cleanup_on_fail  = true
#  set {
#    name  = "server.ingress.enabled"
#    value = "false"
#  }
#}
#
#resource "kubernetes_config_map" "fulcio" {
#  depends_on = [helm_release.fulcio]
#  metadata {
#      annotations = {
#        "meta.helm.sh/release-name" = "fulcio"
#        "meta.helm.sh/release-namespace" = "fulcio-system"
#      }
#    data = {
#      "config.json" = <<-EOT
#    {
#      "OIDCIssuers": {
#        "https://accounts.google.com": {
#          "IssuerURL": "https://accounts.google.com",
#          "ClientID": "sigstore",
#          "Type": "email"
#        },
#        "https://token.actions.githubusercontent.com": {
#          "IssuerURL": "https://token.actions.githubusercontent.com",
#          "ClientID": "sigstore",
#          "Type": "github-workflow"
#        }
#      },
#      "MetaIssuers": {
#        "https://container.googleapis.com/v1/projects/*/locations/*/clusters/*": {
#          "ClientID": "sigstore",
#          "Type": "kubernetes"
#        }
#      }
#    }
#    EOT
#    }
#      labels = {
#        "app.kubernetes.io/instance" = "fulcio"
#        "app.kubernetes.io/managed-by" = "Helm"
#        "app.kubernetes.io/name" = "fulcio"
#        "helm.sh/chart" = "fulcio-0.1.0"
#      }
#      name = "fulcio-config"
#    }
#  }
#
#
#resource "helm_release" "ctlog" {
#  depends_on = ["helm_release.trillian"]
#  timeout = "600"
#  name             = "ctlog"
#  chart            = "${var.SIGSTORE_HELM_PATH}/charts/ctlog"
#  version          = "0.1.0"
#  namespace        = "ctlog-system"
#  create_namespace = true
#  force_update     = true
#  cleanup_on_fail  = true
#  set {
#    name  = "trillian.logServer.name"
#    value = "trillian-trillian-log-server"
#  }
#}