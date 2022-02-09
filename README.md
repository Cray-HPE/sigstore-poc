# build-playground

Playground for building an example e2e pipeline using Tekton Pipelines / Chains
for Python.

**NOTE** sbom/trivy tasks do not work on arm without fetching a
[tekton pipelines update](https://github.com/tektoncd/pipeline/issues/4548)

**NOTE** We have to use --allow-insecure-registry due to this
[cosign bug](https://github.com/sigstore/cosign/issues/1405)

# Get started

## Local Development 

```shell
./hack/kind/setup-kind.sh
```

This will set up a kind cluster on your machine with:

 * Knative serving
 * Sigstore (rekor, fulcio, etc.)
 * Tekton Chains / Pipelines
 * Tekton task for fetching GitHub sources

## GCP Development 

Create the GKE Cluster, install Tekton Pipelines, Dashboard and Chains

```bash
make tf_init tf_plan tf_apply
```

Let's make sure we are running on the GKE cluster we just created, switch kubectl context

```bash
gcloud auth login
gcloud container clusters list
NAME                 LOCATION    MASTER_VERSION   MASTER_IP       MACHINE_TYPE   NODE_VERSION     NUM_NODES  STATUS
chainguard-dev       us-east1-b  1.21.6-gke.1500  35.229.115.236  n1-standard-4  1.21.6-gke.1500  2          RUNNING
chainguard-dev-gke3  us-east1-b  1.21.6-gke.1500  35.185.98.163   n1-standard-4  1.21.6-gke.1500  2          RECONCILING


gcloud container clusters  get-credentials chainguard-dev-gke3

kubectl config get-contexts
CURRENT   NAME                                                CLUSTER                                             AUTHINFO                                            NAMESPACE
          gke_chainguard-dev_us-east1-b_chainguard-dev        gke_chainguard-dev_us-east1-b_chainguard-dev        gke_chainguard-dev_us-east1-b_chainguard-dev        
*         gke_chainguard-dev_us-east1-b_chainguard-dev-gke3   gke_chainguard-dev_us-east1-b_chainguard-dev-gke3   gke_chainguard-dev_us-east1-b_chainguard-dev-gke3   
          kind-kind                                           kind-kind                                           kind-kind                                           

kubectl config use-context gke_chainguard-dev_us-east1-b_chainguard-dev-gke3
Switched to context "gke_chainguard-dev_us-east1-b_chainguard-dev-gke3".
```

Run

    ./hack/setup-gcp.sh 

This will install knative services onto the cluster

Then 

Installs fulcio and rekor, with a mysql backend running the cluster via ./hack/gke/release-arm-gke.yaml

And finally test the installation with ./hack/gke/testrelease-gke.yaml which Runs two jobs, one for checking the 
ctlog tree and one for verifying OIDC signing.

```bash
 kubectl get pods
NAME               READY   STATUS      RESTARTS   AGE
check-oidc-sl42c   0/1     Completed   0          19m
checktree-828rg    0/1     Completed   0          19m
checktree-8kmxd    0/1     Error       0          19m
checktree-tvbkl    0/1     Error       0          19m
```

```bash
kubectl logs checktree-828rg
2022/02/04 14:37:09 Got Payload: map[9ea3cde144cf9277764e1c96b70d8fc03c2370ba25a3010a65d5dcf5535cae83:{Attestation:<nil> Body:BASE64DATA IntegratedTime:0xc000129688 LogID:0xc00010d1f0 LogIndex:0xc000129720 Verification:0xc0001344a0}]


kubectl logs check-oidc-sl42c

Generating ephemeral keys...
Retrieving signed certificate...
**Warning** Using a non-standard public key for verifying SCT: /var/run/sigstore-root/rootfile.pem
Successfully verified SCT...
tlog entry created with index: 0
Pushing signature to: chainguard-dev/nginx 
```

If there are any issues with the installation you can use ./hack/gke/test-gke-user.yaml 

Testing rekor 

```bash
 curl http://rekor.rekor-system.svc/api/v1/log/
{
  "rootHash":"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "signedTreeHead":"Rekor\n0\n47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=\nTimestamp: 1644340477773818665\n\n— rekor.sigstore.dev LJZ0/DBFAiBkWCXKJWbDUzwozFh0HO8flMJu40Bdd5wpf/p2yF0brgIhAMx+Csi20A25zziQuacUaCKWBXpkG52Br0eKgcNrKzjI\n",
  "treeSize":0
}
```

Verifying OIDC token 

```bash
cat /var/run/sigstore/cosign/oidc-token
SA_TOKEN_INFOMATION
```

# Tekton Overview
=======
**NOTE** For Macs the airplay receiver uses the 5000 port and may need to be
disabled, details [here](https://developer.apple.com/forums/thread/682332).
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

# Install Dockerfile that Kaniko will use to build the app image
```bash
kubectl create configmap dockerfile --from-file=./docker/python/Dockerfile
```

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

# Install all the tasks that we have produced
```shell
kubectl apply -f ./config/common/
```

GKE 
```shell
kubectl apply -f ./config/gke/
```

OR 

Local
```shell
kubectl apply -f ./config/kind/
```


And then the pipeline should complete successfully, you can follow along:

```shell
kubectl get pipelineruns -w
```

If you have tekton dashboard installed 

```bash
kubectl port-forward svc/tekton-dashboard 9097:9097 -n tekton-pipelines
```

![](images/tekton-dashboards.png)
=======

# Inspect results


Grab the image that was produced

Get the latest source-to-image task run that has completed successfully 
```bash
kubectl get  taskruns  -l  "tekton.dev/pipeline"="python-build-pipeline" -l "tekton.dev/pipelineTask"="source-to-image"
NAME                                         SUCCEEDED   REASON      STARTTIME   COMPLETIONTIME
build-pipeline-run-f57dc-source-to-image     True        Succeeded   3h32m       3h31m
build-pipeline-run-r-48wwv-source-to-image   False       Failed      3h53m       3h53m
build-pipeline-run-r-ld4qn-source-to-image   False       Failed      4h2m        4h
build-pipeline-run-r-pbpcg-source-to-image   True        Succeeded   3h47m       3h46m
build-pipeline-run-r-qtgfx-source-to-image   False       Failed      3h57m       3h57m
build-pipeline-run-r-s9qgp-source-to-image   True        Succeeded   3h44m       3h43m
build-pipeline-run-r-wp4rj-source-to-image   True        Succeeded   3h50m       3h49m
build-pipeline-run-rvn62-source-to-image     True        Succeeded   3h38m       3h37m
build-pipeline-run-source-to-image           False       Failed      4h12m       4h10m
```

The Source to image task will produce the image id of the container it built and push to the registry

```shell
IMAGE_ID=$(kubectl get taskruns build-pipeline-run-f57dc-source-to-image -o jsonpath='{.spec.params[0].value}' | sed 's/:0.1//')@$(kubectl get taskruns build-pipeline-run-f57dc-source-to-image -o jsonpath='{.status.taskResults[0].value}')
```

```bash
echo $IMAGE_ID
gcr.io/chainguard-dev/pythontest@sha256:c089acd03a21830c329d70f61cefa2a29c43e59ebc848581043b631451dfffa7
```

Get the SBOM:

Pull down the Root CA from fulcio 

```bash
curl http://fulcio.fulcio-system.svc:8080/api/v1/rootCert > ./fulcio-public.pem
```

Now download the SBOM 

```shell
SIGSTORE_ROOT_FILE=./fulcio-public.pem COSIGN_EXPERIMENTAL=1 cosign download sbom --allow-insecure-registry  $IMAGE_ID > /tmp/sbom
```

Get the trivy scan result:

```shell
SIGSTORE_ROOT_FILE=./fulcio-public.pem COSIGN_EXPERIMENTAL=1 cosign verify-attestation --rekor-url=http://rekor.rekor-system.svc:8080 --allow-insecure-registry  $IMAGE_ID > /tmp/attestations
```

if all goes well you'll see this output

```shell
Verification for gcr.io/chainguard-dev/pythontest@sha256:c089acd03a21830c329d70f61cefa2a29c43e59ebc848581043b631451dfffa7 --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - The claims were present in the transparency log
  - The signatures were integrated into the transparency log when the certificate was valid
  - Any certificates were verified against the Fulcio roots.
```