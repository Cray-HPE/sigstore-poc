# build-playground

Playground for building an example e2e pipeline using Tekton Pipelines / Chains
for Python.

**NOTE** sbom/trivy tasks do not work on arm without fetching a
[tekton pipelines update](https://github.com/tektoncd/pipeline/issues/4548)

**NOTE** We have to use --allow-insecure-registry due to this
[cosign bug](https://github.com/sigstore/cosign/issues/1405)

# Get started

Run this to get your cluster locally:
```shell
./hack/setup-kind.sh
```

This will setup a kind cluster on your machine with:

 * Knative serving
 * Sigstore (rekor, fulcio, etc.)
 * Tekton Chains / Pipelines
 * Tekton task for fetching github sources

**NOTE** For Macs the airplay receiver uses the 5000 port and may need to be
disabled, details [here](https://developer.apple.com/forums/thread/682332)).
Alternatively, you can manually modify the script and change the
[REGISTRY_PORT](https://github.com/vaikas/sigstore-scaffolding/blob/main/hack/setup-mac-kind.sh#L19)

*NOTE* You may have to uninstall the docker registry container between running
the above scripts because it spins up a registry container in a daemon mode.
To clean a previously running registry, you can do one of these:

YOLO:

```shell
docker rm -f `docker ps -a | grep 'registry:2' | awk -F " " '{print $1}'`
```

Or to check things first:

```shell
docker ps -a | grep registry
b1e3f3238f7a   registry:2                        "/entrypoint.sh /etc…"   15 minutes ago   Up 15 minutes               0.0.0.0:5000->5000/tcp, :::5000->5000/tcp   registry.local
```

So that's the running version of the registry, so remove it:
```shell
docker rm -f b1e3f3238f7a
```

# Overview

We also have an image that we create. Idea is that it's a blessed python-slim
version that will only be used to install the requirements. After the
installation completes, we grab the dependencies and just copy them to the
venv for the python that will then actually run them.

## Exercising the local cluster

Because all the pieces are running in the kind cluster, we need to make couple
of things to make it usable by normal cosign tooling from your local machine.

### Certificates

There are two certificates that we need, CT Log and Fulcio root certs. Note that
if you are switching back and forth between public / your instance, you might
not want to export these variables as hilarity will ensue.

CT Log:
```shell
kubectl -n ctlog-system get secrets ctlog-public-key -o=jsonpath='{.data.public}' | base64 -d > ./ctlog-public.pem
export SIGSTORE_CT_LOG_PUBLIC_KEY_FILE=./ctlog-public.pem
```

Fulcio root:
```shell
kubectl -n fulcio-system get secrets fulcio-secret -ojsonpath='{.data.cert}' | base64 -d > ./fulcio-root.pem
export SIGSTORE_ROOT_FILE=./fulcio-root.pem
```

### Network access

Setup port forwarding:

```shell
kubectl -n kourier-system port-forward service/kourier-internal 8080:80 &
```

### Adding localhost entries to make tools usable

Add the following entries to your `/etc/hosts` file

```
127.0.0.1 rekor.rekor-system.svc
127.0.0.1 fulcio.fulcio-system.svc
127.0.0.1 ctlog.ctlog-system.svc
```

This makes using tooling easier, for example:

```shell
rekor-cli --rekor_server http://rekor.rekor-system.svc:8080 loginfo
```

For example, this is what I get after smoke tests have successfully completed:
```shell
rekor-cli --rekor_server http://rekor.rekor-system.svc:8080 loginfo
No previous log state stored, unable to prove consistency
Verification Successful!
Tree Size: 1
Root Hash: 062e2fa50e2b523f9cfd4eadc4b67745436226d64bf9799d57c5dc023681c4b8
Timestamp: 2022-02-04T22:09:46Z
```

# Tekton tasks

Once you've installed the bits above, you can install the Tekton task and
pipeline pieces. This is very rough beginning of a proper Python pipeline and is
meant to demonstrate breaking the large build into multiple steps and providing
attestations at each level via Tekton Chains.

```shell
# Install Dockerfile that Kaniko will use to build the app image
kubectl create configmap dockerfile --from-file=./docker/build-python-app/Dockerfile


# Install kaniko task
kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/v1beta1/kaniko/kaniko.yaml

# Install all the tasks that we have produced
kubectl apply -f ./config/python-pipeline/list-dependencies-task.yaml
kubectl apply -f ./config/python-pipeline/install-dockerfile-task.yaml
kubectl apply -f ./config/python-pipeline/python-dependencies-task.yaml
kubectl apply -f ./config/python-pipeline/sbom-task.yaml
kubectl apply -f ./config/python-pipeline/trivy-task.yaml

# Then install the pipeline containing our tasks
kubectl apply -f ./config/python-pipeline/python-pipeline.yaml

# And then execute it.
kubectl apply -f ./config/python-pipeline/python-pipelinerun-kind.yaml
```

And then the pipeline should complete successfully, you can follow along:

```shell
kubectl get pipelineruns -w
```

# Inspect results

**NOTE** This is still in flux

Grab the image that was produced

```shell
IMAGE_ID=$(kubectl get taskruns bare-build-pipeline-run-source-to-image -o jsonpath='{.spec.params[0].value}' | sed 's/:0.1//')@$(kubectl get taskruns bare-build-pipeline-run-source-to-image -o jsonpath='{.status.taskResults[0].value}')
```

Get the SBOM:

```shell
SIGSTORE_ROOT_FILE=/tmp/fulcio-public.pem COSIGN_EXPERIMENTAL=1 cosign download sbom --allow-insecure-registry  $IMAGE_ID > /tmp/sbom
```

Get the trivy scan result:

```shell
SIGSTORE_ROOT_FILE=/tmp/fulcio-public.pem COSIGN_EXPERIMENTAL=1 cosign verify-attestation --rekor-url=http://rekor.rekor-system.svc:8080 --allow-insecure-registry  $IMAGE_ID > /tmp/attestations
```

Create your own attestation. For this to work you need to update cm fulcio-config
in fulcio-system by adding support for other oauth issuers. TODO(vaikas): Update sigstore-scaffolding to support them.
```shell
SIGSTORE_CT_LOG_PUBLIC_KEY_FILE=/tmp/ctlog-public.pem SIGSTORE_ROOT_FILE=/tmp/fulcio-public.pem COSIGN_EXPERIMENTAL=1 cosign attest --allow-insecure-registry --force --fulcio-url=http://fulcio.fulcio-system.svc:8080 --rekor-url=http://rekor.rekor-system.svc:8080 --predicate /tmp/registry.logs $IMAGE_ID
```
