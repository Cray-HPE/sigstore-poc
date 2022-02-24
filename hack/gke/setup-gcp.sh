#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2021-2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
.
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o nounset
set -o pipefail

# Defaults
K8S_VERSION="v1.21.x"
KNATIVE_VERSION="1.1.0"
REGISTRY_NAME="registry.local"
REGISTRY_PORT="5000"
CLUSTER_SUFFIX="cluster.local"
PRIVATE_CA=false
NODE_COUNT="1"

while [[ $# -ne 0 ]]; do
  parameter="$1"
  case "${parameter}" in
    --k8s-version)
      shift
      K8S_VERSION="$1"
      ;;
    --private-ca)
          shift
          PRIVATE_CA=true
      ;;
    --knative-version)
      shift
      KNATIVE_VERSION="$1"
      ;;
    --registry-url)
      shift
      REGISTRY_NAME="$(echo "$1" | cut -d':' -f 1)"
      REGISTRY_PORT="$(echo "$1" | cut -d':' -f 2)"
      ;;
    --cluster-suffix)
      shift
      CLUSTER_SUFFIX="$1"
      ;;
    *) echo "unknown option ${parameter}"; exit 1 ;;
  esac
  shift
done


echo '::group:: Expose OIDC Discovery'

# From: https://banzaicloud.com/blog/kubernetes-oidc/
# To be able to fetch the public keys and validate the JWT tokens against
# the Kubernetes cluster’s issuer we have to allow external unauthenticated
# requests. To do this, we bind this special role with a ClusterRoleBinding
# to unauthenticated users (make sure that this is safe in your environment,
# but only public keys are visible on this URL)
kubectl create clusterrolebinding oidc-reviewer \
  --clusterrole=system:service-account-issuer-discovery \
  --group=system:unauthenticated --dry-run=client -o yaml | kubectl apply -f -

echo '::endgroup::'


#############################################################
#
#    Install Knative Serving
#
#############################################################
echo '::group:: Install Knative Serving'

# Eliminates the resources blocks in a release yaml
function resource_blaster() {
  local REPO="${1}"
  local FILE="${2}"

  curl -L -s "https://github.com/knative/${REPO}/releases/download/knative-v${KNATIVE_VERSION}/${FILE}" \
    | yq e 'del(.spec.template.spec.containers[]?.resources)' - \
    `# Filter out empty objects that come out as {} b/c kubectl barfs` \
    | grep -v '^{}$'
}

resource_blaster serving serving-crds.yaml | kubectl apply -f -
sleep 3 # Avoid the race creating CRDs then instantiating them...
resource_blaster serving serving-core.yaml | kubectl apply -f -
resource_blaster net-kourier kourier.yaml | kubectl apply -f -
kubectl patch configmap/config-network \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"ingress.class":"kourier.ingress.networking.knative.dev"}}'

# Wait for Knative to be ready (or webhook will reject SaaS)
for x in $(kubectl get deploy --namespace knative-serving -oname); do
  kubectl rollout status --timeout 5m --namespace knative-serving $x
done

# Enable the features we need that are currently feature-flagged in Knative.
# We do this last to ensure the webhook is up.
while ! kubectl patch configmap/config-features \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"kubernetes.podspec-fieldref":"enabled", "kubernetes.podspec-volumes-emptydir":"enabled", "multicontainer":"enabled"}}'
do
    echo Waiting for webhook to be up.
    sleep 1
done

# Adjust some default values.
#  - revision-timeout-seconds: reduces the default pod grace period from 5m to 30s
#   (so that things scale down faster).
#  - container-concurrency: sets the default request concurrency to match the default
#   GRPC concurrent streams: https://github.com/grpc/grpc-go/blob/87eb5b7/internal/transport/defaults.go#L34
while ! kubectl patch configmap/config-defaults \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"revision-timeout-seconds":"30","container-concurrency":"100"}}'
do
    echo Waiting for webhook to be up.
    sleep 1
done

# Use min-scale: 1 during tests to preserve logs, use max-scale: 1 to avoid crowding the cluster.
while ! kubectl patch configmap/config-autoscaler \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"min-scale":"1","max-scale":"1"}}'
do
    echo Waiting for webhook to be up.
    sleep 1
done

# Enable magic dns so we can interact with minio from our scripts.
# TODO(vaikas): Wire up minio for Rekor attestation storage.
resource_blaster serving serving-default-domain.yaml | kubectl apply -f -

# Wait for the job to complete, so we can reliably use ksvc hostnames.
kubectl wait -n knative-serving --timeout=60s --for=condition=Complete jobs --all || true
echo '::endgroup::'


echo '::group:: Install Sigstore scaffolding'

echo 'Deploying with Private CA'
kubectl apply -f ./hack/gke/release-arm-gke-private-ca.yaml

# Delete check jobs from previous runs just in case
kubectl delete -f ./hack/gke/testrelease-gke.yaml || true

echo "waiting for sigstore pieces to come up"
kubectl wait --timeout=15m -A --for=condition=Complete jobs --all

echo "Sleeping before starting smoke tests"
secs=$((60))
while [ $secs -gt 0 ]; do
   echo -ne "$secs\033[0K\r"
   sleep 1
   : $((secs--))
done

echo "Running smoke test"

kubectl delete secret/ctlog-public-key || true
kubectl -n ctlog-system get secrets ctlog-public-key -oyaml | sed 's/namespace: .*/namespace: default/' | kubectl apply -f -
kubectl apply -f ./hack/gke/testrelease-gke.yaml
echo "Waiting on checktree check-oidc to complete"
kubectl wait --timeout=10m --for=condition=Complete jobs checktree
echo '::endgroup:: Install Sigstore scaffolding'


# Disable affinity-assistance so that we can mount multiple volumes for in/out
kubectl patch configmap/feature-flags \
--namespace tekton-pipelines \
--type merge \
--patch '{"data":{"disable-affinity-assistant": "true"}}'

# Restart so picks up the changes.
kubectl -n tekton-pipelines delete po -l app=tekton-pipelines-controller

kubectl patch configmap/chains-config \
--namespace tekton-chains \
--type merge \
--patch '{"data":{"artifacts.oci.format": "simplesigning", "artifacts.oci.storage": "tekton", "artifacts.taskrun.format": "in-toto", "signers.x509.fulcio.address": "http://fulcio.fulcio-system.svc", "signers.x509.fulcio.enabled": "true", "transparency.enabled": "true", "transparency.url": "http://rekor.rekor-system.svc"}}'

# Restart so picks up the changes.
kubectl -n tekton-chains delete po -l app=tekton-chains-controller
echo '::endgroup::'
