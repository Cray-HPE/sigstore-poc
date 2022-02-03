variable "tk_pl_helm_chart_version" {
  default     = "v0.1.0"
  type        = string
  description = "Helm chart version of tekton pipeline helm chart"
}

variable "tk_pl_namespace" {
  default     = "tekton-pipelines"
  type        = string
  description = "Namespace to deploy tekton charts"
}

variable "tk_pl_local" {
  type        = string
  description = "Path to local tekton pipeline helm chart"
}

variable "tk_dashboard_helm_chart_version" {
  default = "v0.1.0"
  type    = string
}

variable "tk_dashboard_local" {
  type        = string
  description = "Path to local tekton dashboard helm chart"
}

variable "tk_chains_namespace" {
  default     = "tekton-chains"
  type        = string
  description = "Namespace to deploy tekton chains"
}

variable "tk_chains_helm_chart_version" {
  default = "v0.1.0"
  type    = string
}

variable "tk_chains_local" {
  type        = string
  description = "Path to local tekton chains helm chart"
}


