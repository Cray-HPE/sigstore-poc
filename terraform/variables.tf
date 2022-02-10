variable "workspace_id" {
  type        = string
  description = "Terraform workspace name"
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

variable "PROJECT_ID" {
  type        = string
  default     = "chainguard-dev"
  description = "Google Project ID"
  validation {
    condition     = length(var.PROJECT_ID) > 0
    error_message = "Must specify PROJECT_ID variable."
  }
}

variable "config_context" {
  default     = "kind-tekton-tf-dev"
  description = "Name of local kubectl context to use for local dev"
}

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
  default     = "v0.1.0"
  type        = string
  description = "Tekton Dashboard of the helm chart to deploy"
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
  default     = "v0.1.0"
  type        = string
  description = "Helm chart version of tekton chains to deploy"
}

variable "tk_chains_local" {
  type        = string
  description = "Path to local tekton chains helm chart"
}


