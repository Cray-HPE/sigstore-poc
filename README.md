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

Read full guidance for local development via the [local tutorial](/docs/local-development.md).

Read full guidance for GCP development via the [GCP tutorial](/docs/GCP-development.md).

_TODO AWS tutorial._