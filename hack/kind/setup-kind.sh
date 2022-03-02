#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2022 Hewlett Packard Enterprise Development LP
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

set -o errexit
set -o nounset
set -o pipefail

THIS_OS="$(uname -s)"
THIS_HW="$(uname -m)"

RUNNING_ON_MAC="false"
RUNNING_ON_WINDOWS="false"
RUNNING_ON_LINUX="true"
# We need to do couple of things different on Mac
if [ "${THIS_OS}" == "Darwin" ]; then
  echo "Running on Mac"
  RUNNING_ON_MAC="true"
  RUNNING_ON_LINUX="false"
fi
# We need to do couple of things different on Windows running WSL.
if uname -r | grep --quiet microsoft ; then
  echo "Running on Windows"
  RUNNING_ON_WINDOWS="true"
  RUNNING_ON_LINUX="false"
fi

SIGSTORE_SCAFFOLDING_RELEASE="https://github.com/vaikas/sigstore-scaffolding/releases/download/v0.1.19/release.yaml"

SIGSTORE_SCAFFOLDING_TEST="https://github.com/vaikas/sigstore-scaffolding/releases/download/v0.1.19/testrelease.yaml"

TEKTON_CHAINS_RELEASE="https://storage.googleapis.com/tekton-releases/chains/latest/release.yaml"
TEKTON_PIPELINES_RELEASE="https://storage.googleapis.com/tekton-releases-nightly/pipeline/latest/release.yaml"
TEKTON_DASHBOARD_RELEASE="https://storage.googleapis.com/tekton-releases/dashboard/latest/tekton-dashboard-release.yaml"

# Defaults
K8S_VERSION="v1.21.x"
KNATIVE_VERSION="1.1.0"
REGISTRY_NAME="registry.local"
REGISTRY_PORT="5000"
CLUSTER_SUFFIX="cluster.local"
NODE_COUNT="2"
SIGSTORE_ONLY="false"

while [[ $# -ne 0 ]]; do
  parameter="$1"
  case "${parameter}" in
    --k8s-version)
      shift
      K8S_VERSION="$1"
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
    --sigstore-only)
      SIGSTORE_ONLY="true"
      ;;
    *) echo "unknown option ${parameter}"; exit 1 ;;
  esac
  shift
done

docker stop "${REGISTRY_NAME}" && docker rm "${REGISTRY_NAME}"

# The version map correlated with this version of KinD
KIND_VERSION="v0.11.1"
case ${K8S_VERSION} in
  v1.19.x)
    K8S_VERSION="1.19.11"
    KIND_IMAGE_SHA="sha256:07db187ae84b4b7de440a73886f008cf903fcf5764ba8106a9fd5243d6f32729"
    KIND_IMAGE="kindest/node:${K8S_VERSION}@${KIND_IMAGE_SHA}"
    ;;
  v1.20.x)
    K8S_VERSION="1.20.7"
    KIND_IMAGE_SHA="sha256:cbeaf907fc78ac97ce7b625e4bf0de16e3ea725daf6b04f930bd14c67c671ff9"
    KIND_IMAGE="kindest/node:${K8S_VERSION}@${KIND_IMAGE_SHA}"
    ;;
  v1.21.x)
    K8S_VERSION="1.21.1"
    KIND_IMAGE_SHA="sha256:69860bda5563ac81e3c0057d654b5253219618a22ec3a346306239bba8cfa1a6"
    KIND_IMAGE="kindest/node:${K8S_VERSION}@${KIND_IMAGE_SHA}"
    ;;
  *) echo "Unsupported version: ${K8S_VERSION}"; exit 1 ;;
esac

#############################################################
#
#    Install KinD
#
#############################################################
echo '::group:: Install KinD'

EXTRA_MOUNT=""
# This does not work on Mac, or Windows so skip.
if [ ${RUNNING_ON_LINUX} == "true" ]; then
  # Disable swap otherwise memory enforcement does not work
  # See: https://kubernetes.slack.com/archives/CEKK1KTN2/p1600009955324200
  sudo swapoff -a
  sudo rm -f /swapfile
  # Use in-memory storage to avoid etcd server timeouts.
  # https://kubernetes.slack.com/archives/CEKK1KTN2/p1615134111016300
  # https://github.com/kubernetes-sigs/kind/issues/845
  sudo mkdir -p /tmp/etcd
  sudo mount -t tmpfs tmpfs /tmp/etcd
fi

if ! command -v kind &> /dev/null; then
  echo ":: Installing Kind ::"
  curl -Lo ./kind "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-$(uname)-$(THIS_HW)"
  chmod +x ./kind
  sudo mv kind /usr/local/bin
fi

echo '::endgroup::'

#############################################################
#
#    Setup KinD cluster.
#
#############################################################
echo '::group:: Build KinD Config'

if [ ${RUNNING_ON_LINUX} == "true" ]; then
  cat > kind.yaml <<EOF_LINUX
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
name: sigstore
nodes:
- role: control-plane
  image: "${KIND_IMAGE}"
  extraMounts:
  - containerPath: /var/lib/etcd
    hostPath: /tmp/etcd
- role: worker
  image: "${KIND_IMAGE}"
EOF_LINUX
fi

if [ ${RUNNING_ON_MAC} == "true" ]; then
  cat > kind.yaml <<EOF_MAC
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
name: sigstore
nodes:
- role: control-plane
  image: "${KIND_IMAGE}"
- role: worker
  image: "${KIND_IMAGE}"
EOF_MAC
fi

if [ ${RUNNING_ON_WINDOWS} == "true" ]; then
  cat > kind.yaml <<EOF_WINDOWS
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
name: sigstore
nodes:
- role: control-plane
  image: "${KIND_IMAGE}"
- role: worker
  image: "${KIND_IMAGE}"
EOF_WINDOWS
fi

cat >> kind.yaml <<EOF_SHARED
# Configure registry for KinD.
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."$REGISTRY_NAME:$REGISTRY_PORT"]
    endpoint = ["http://$REGISTRY_NAME:$REGISTRY_PORT"]

# This is needed in order to support projected volumes with service account tokens.
# See: https://kubernetes.slack.com/archives/CEKK1KTN2/p1600268272383600
kubeadmConfigPatches:
  - |
    apiVersion: kubeadm.k8s.io/v1beta2
    kind: ClusterConfiguration
    metadata:
      name: config
    apiServer:
      extraArgs:
        "service-account-issuer": "https://kubernetes.default.svc"
        "service-account-key-file": "/etc/kubernetes/pki/sa.pub"
        "service-account-signing-key-file": "/etc/kubernetes/pki/sa.key"
        "service-account-api-audiences": "api,spire-server"
        "service-account-jwks-uri": "https://kubernetes.default.svc/openid/v1/jwks"
    networking:
      dnsDomain: "${CLUSTER_SUFFIX}"
EOF_SHARED

cat kind.yaml
echo '::endgroup::'

kind delete cluster --name sigstore
echo '::group:: Create KinD Cluster'
kind create cluster --config kind.yaml --wait 5m

kubectl describe nodes
echo '::endgroup::'

echo '::group:: Expose OIDC Discovery'

# From: https://banzaicloud.com/blog/kubernetes-oidc/
# To be able to fetch the public keys and validate the JWT tokens against
# the Kubernetes cluster’s issuer we have to allow external unauthenticated
# requests. To do this, we bind this special role with a ClusterRoleBinding
# to unauthenticated users (make sure that this is safe in your environment,
# but only public keys are visible on this URL)
kubectl create clusterrolebinding oidc-reviewer \
  --clusterrole=system:service-account-issuer-discovery \
  --group=system:unauthenticated

echo '::endgroup::'


#############################################################
#
#    Setup metallb
#
#############################################################
echo '::group:: Setup metallb'

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

network=$(docker network inspect kind -f "{{(index .IPAM.Config 0).Subnet}}" | cut -d '.' -f1,2)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - $network.255.1-$network.255.250
EOF

echo '::endgroup::'


#############################################################
#
#    Setup container registry
#
#############################################################
echo '::group:: Setup container registry'


docker run -d --restart=always \
       -p "$REGISTRY_PORT:$REGISTRY_PORT" --name "$REGISTRY_NAME" registry:2

# Connect the registry to the KinD network.
docker network connect "kind" "$REGISTRY_NAME"

# Make the $REGISTRY_NAME -> 127.0.0.1, to tell `ko` to publish to
# local reigstry, even when pushing $REGISTRY_NAME:$REGISTRY_PORT/some/image
sudo echo "127.0.0.1 $REGISTRY_NAME" | sudo tee -a /etc/hosts

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
  kubectl rollout status --timeout 5m --namespace knative-serving "${x}"
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
kubectl wait -n knative-serving --timeout=90s --for=condition=Complete jobs --all

echo '::endgroup::'

echo '::group:: Install Sigstore scaffolding'
curl -L ${SIGSTORE_SCAFFOLDING_RELEASE} | kubectl apply -f -
echo 'waiting for sigstore pieces to come up. This might take a few minutes'
kubectl wait --timeout=15m -A --for=condition=Complete jobs --all

echo 'Running smoke test'
# Make a copy of the CT Log public key so that we can use it to
# validate the SCT coming from Fulcio.
echo 'Removing a possibly already existing ctlog public secret. If this errors, this is ok'
kubectl delete secret/ctlog-public-key || true
kubectl -n ctlog-system get secrets ctlog-public-key -oyaml | sed 's/namespace: .*/namespace: default/' | kubectl apply -f -
kubectl apply -f ${SIGSTORE_SCAFFOLDING_TEST}
echo "Waiting on checktree check-oidc to complete"
kubectl wait --timeout=15m --for=condition=Complete jobs checktree check-oidc --namespace default
echo '::endgroup:: Install Sigstore scaffolding'

if [ $SIGSTORE_ONLY == "true" ]; then
  echo "Not installing Tekton components due to --sigstore-only flag"
  exit 0
fi

echo '::group:: Install Tekton Pipelines and chains'
while ! kubectl apply --filename "${TEKTON_PIPELINES_RELEASE}"
do
  echo "waiting for tekton pipelines to get installed"
  sleep 2
done

# Disable affinity-assistance so that we can mount multiple volumes for in/out
kubectl patch configmap/feature-flags \
--namespace tekton-pipelines \
--type merge \
--patch '{"data":{"disable-affinity-assistant": "true"}}'

# Restart so picks up the changes.
kubectl -n tekton-pipelines delete po -l app=tekton-pipelines-controller

while ! kubectl apply --filename "${TEKTON_CHAINS_RELEASE}"
do
  echo "waiting for tekton chains to get installed"
  sleep 2
done

kubectl patch configmap/chains-config \
--namespace tekton-chains \
--type merge \
--patch '{"data":{"artifacts.oci.format": "simplesigning", "artifacts.oci.storage": "oci", "artifacts.taskrun.format": "in-toto", "signers.x509.fulcio.address": "http://fulcio.fulcio-system.svc", "signers.x509.fulcio.enabled": "true", "transparency.enabled": "true", "transparency.url": "http://rekor.rekor-system.svc"}}'

# Restart so picks up the changes.
kubectl -n tekton-chains delete po -l app=tekton-chains-controller

while ! kubectl apply --filename "${TEKTON_DASHBOARD_RELEASE}"
do
  echo "waiting for tekton dashboard to get installed"
  sleep 2
done
echo '::endgroup::'
