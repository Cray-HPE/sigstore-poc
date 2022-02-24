variable "WORKSPACE_ID" {
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

variable "K8S_CONTEXT" {
  default     = "kind-tekton-tf-dev"
  description = "Name of local kubectl context to use for local dev"
}

variable "TK_PIPELINE_HELM_CHART_VERSION" {
  default     = "v0.1.0"
  type        = string
  description = "Helm chart version of tekton pipeline helm chart"
}

variable "TK_PIPELINE_NAMESPACE" {
  default     = "tekton-pipelines"
  type        = string
  description = "Namespace to deploy tekton charts"
}

variable "TK_PIPELINE_HELM_LOCAL_PATH" {
  type        = string
  description = "Path to local tekton pipeline helm chart"
}

variable "TK_DASHBOARD_HELM_CHART_VERSION" {
  default     = "v0.1.0"
  type        = string
  description = "Tekton Dashboard of the helm chart to deploy"
}

variable "TK_DASHBOARD_HELM_LOCAL_PATH" {
  type        = string
  description = "Path to local tekton dashboard helm chart"
}

variable "TK_CHAINS_NAMESPACE" {
  default     = "tekton-chains"
  type        = string
  description = "Namespace to deploy tekton chains"
}

variable "TK_CHAINS_HELM_CHART_VERSION" {
  default     = "v0.1.0"
  type        = string
  description = "Helm chart version of tekton chains to deploy"
}

variable "TK_CHAINS_HELM_LOCAL_PATH" {
  type        = string
  description = "Path to local tekton chains helm chart"
}

variable "SIGSTORE_HELM_LOCAL_PATH" {
  type        = string
  description = "Path to local sigstore helm chart"
}

variable "SIGSTORE_HELM_VERSION" {
  default     = "v0.1.0"
  type        = string
  description = "Helm chart version of sigstore scaffolding deploy"
}
