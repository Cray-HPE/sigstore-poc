# Sigstore HPE POC

Playground for building an example e2e pipeline using Tekton Pipelines, Chains, Dashboard, Sigstore,  Rekor, Cosign, and Fulcio for Python and Kind and/or GCP/GKE.

# Get started

1. Setup Kubernetes Cluster
2. Install Tekton Pipelines, Chains, and Dashboards
3. Install Rekor and Fulcio
4. Run Python builds through Pipelines
   1. Build, Dependencies
   2. Container creation
   3. SBOM creation
   4. Trivy CVE Scanning
5. Verify results with Cosign

# Prerequisites

In order to run through this example, you will need the following installed:

* [Docker](https://docs.docker.com/get-docker/)
* [tkn cli](https://tekton.dev/docs/cli/)
* [kubectl](https://kubernetes.io/docs/tasks/tools/)
* [rekor-cli](https://github.com/sigstore/rekor/releases)
* [cosign](https://github.com/sigstore/cosign/releases)
* [openssl cli](https://www.openssl.org/source/)
* **GCP Only** [Terraform](https://www.terraform.io/downloads)
* **Windows Only** [WSL](https://docs.microsoft.com/en-us/windows/wsl/install)
* [yq](https://github.com/mikefarah/yq#install)
* [jq](https://stedolan.github.io/jq/download/)

Read full guidance for local development via the [local tutorial](/docs/local-development.md).

Read full guidance for GCP development via the [GCP tutorial](/docs/GCP-development.md).

_TODO AWS tutorial._