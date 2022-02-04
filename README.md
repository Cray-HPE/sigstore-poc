# build-playground

Playground for building an example e2e pipeline using Tekton Pipelines / Chains
for Python.

# Get started

If you have Mac, run this:

```shell
./hack/setup-mac-kind.sh
```

if not, run this:
```shell
./hack/setup-kind.sh
```

This will setup a kind cluster on your machine with:

 * Knative serving
 * Sigstore (rekor, fulcio, etc.)
 * Tekton Chains / Pipelines
 * Tekton task for fetching github sources

# Overview

We also have an image that we create. Idea is that it's a blessed python-slim
version that will only be used to install the requirements. After the
installation completes, we grab the dependencies and just copy them to the
venv for the python that will then actually run them.

# Once you've installed the bits above, you can install the config pieces.

```shell
kubectl apply -f ./config/list-dependencies-task.yaml
kubectl apply -f ./config/python-dependencies-task.yaml
kubectl apply -f ./config/python-pipeline.yaml
kubectl apply -f ./config/python-pipelinerun.yaml
```

And then the pipeline should complete successfully, you can follow along:

```shell
kubectl get pipelineruns -w
```
