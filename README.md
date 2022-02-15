# Sigstore HPE POC

Playground for building an example e2e pipeline using Tekton Pipelines, Chains, Dashboard, Sigstore Rekor, Cosign and Fulcio
for Python and Kind and/or GCP/GKE.

**NOTE** We have to use --allow-insecure-registry due to this
[cosign bug](https://github.com/sigstore/cosign/issues/1405)

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

## Kubernetes Cluster

### Local Development


**Note** you may hit file limits on the mac `sudo launchctl limit maxfiles 65536 200000` to remediate that issue

**NOTE** For Macs the airplay receiver uses the 5000 port and may need to be
disabled, details [here](https://developer.apple.com/forums/thread/682332).
Alternatively, you can manually modify the script and change the
[REGISTRY_PORT](https://github.com/vaikas/sigstore-scaffolding/blob/main/hack/setup-mac-kind.sh#L19)

```shell
./hack/kind/setup-kind.sh
```

This will set up a kind cluster on your machine with:

 * Knative serving
 * Sigstore (rekor, fulcio, etc.)
 * Tekton Chains / Pipelines
 * Tekton task for fetching GitHub sources

**Note** You may see some errors of the form:
```
Error from server (InternalError): error when creating "https://storage.googleapis.com/tekton-releases/chains/latest/release.yaml": Internal error occurred: failed calling webhook "config.webhook.pipeline.tekton.dev": Post "https://tekton-pipelines-webhook.tekton-pipelines.svc:443/config-validation?timeout=10s": dial tcp 10.96.244.5:443: connect: connection refused
```

They are due to some race conditions when installing Tekton components. There
are retries there so as long things finish, it's ok. Cleaning those up will
require some upstream work.

### GCP Development

Create the GKE Cluster, install Tekton Pipelines, Dashboard and Chains

We are doing a terraform targeted plan/apply because the GKE cluster has to be up and running before helm can apply,
since we are directly pointing the helm provider to the GKE cluster.

Set the GOOGLE_APPLICATION_CREDENTIALS path to where `gcloud auth application-default login` places your credentials file

```bash
make tf_init tf_target_plan tf_target_apply tf_plan tf_apply
```

Let's make sure we are running on the GKE cluster we just created, switch kubectl context

```bash
gcloud auth application-default login # if need be
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

    ./hack/gke/setup-gcp.sh

This will install knative services onto the cluster

Then

Installs fulcio and rekor, with a mysql backend running the cluster via ./hack/gke/release-arm-gke.yaml

And finally test the installation with ./hack/gke/testrelease-gke.yaml which Runs two jobs, one for checking the
ctlog tree and one for verifying OIDC signing.


### Verify Sigstore installs

There are two jobs that run to verify the installation. One (check-oidc) signs
an image with cosign, and checktree ensures it's properly added to Rekor
transparency log. Both of them should show `1/1` completions.

```bash
kubectl get jobs
NAME         COMPLETIONS   DURATION   AGE
check-oidc   1/1           40s        9m19s
checktree    1/1           59s        9m19s
```

```bash
for i in `kubectl get pods | grep Completed | awk -F " " '{print $1}'`
do
kubectl logs $i
done
```
As an example (little snipped for readability), I saw this:

```
Generating ephemeral keys...
Retrieving signed certificate...
**Warning** Using a non-standard public key for verifying SCT: /var/run/sigstore-root/rootfile.pem
Successfully verified SCT...
tlog entry created with index: 0
Pushing signature to: knative
2022/02/10 22:57:56 Got Payload: map[e0beca4...vdExTMHRMVVZPUkNCRFJWSlVTVVpKUTBGVVJTMHRMUzB0Q2c9PSJ9fX19 IntegratedTime:0x4000135588 LogID:0x400001e8e0 LogIndex:0x40001355a0 Verification:0x400002a860}]
2022/02/10 22:57:56 Found UUID: e0beca412f78687deef90f1e7aacbe022d0968ec9c12dd36fb7374f0102e08a8
2022/02/10 22:57:56 Checking for type: hashedrekord version 0.0.1
2022/02/10 22:57:56 Got TYPE: &{HashedRekordObj:{Data:0x400012e980 Signature:0x4000591f00} keyObj:0x4000126d20 sigObj:0x4000126c90}
2022/02/10 22:57:56 Searching for sha256:cad43a8a48728336a6606d7bfecc7aa84b032b1dd951b5ec287cfd4597b22603
2022/02/10 22:57:56 Found index entry: e0beca412f78687deef90f1e7aacbe022d0968ec9c12dd36fb7374f0102e08a8
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

**NOTE** You may have to uninstall the docker registry container between running
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

### <a name="network"></a> Network access

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

#### Install all the tasks that our needed for the pipeline
```shell
kubectl apply -f ./config/common/
kubectl apply -f ./config/python/
kubectl apply -f ./config/go/
```

After this, you should have the following tasks and pipelines
installed:

```shell
kubectl get tasks,pipelines
NAME                                          AGE
task.tekton.dev/git-clone                     91m
task.tekton.dev/install-go-dependencies       91m
task.tekton.dev/install-python-dependencies   91m
task.tekton.dev/kaniko                        91m
task.tekton.dev/ko-build-image                91m
task.tekton.dev/list-dependencies             91m
task.tekton.dev/sbom-syft                     91m
task.tekton.dev/scan-trivy                    91m

NAME                                        AGE
pipeline.tekton.dev/go-build-pipeline       91m
pipeline.tekton.dev/python-build-pipeline   91m
```

Then run the Python pipeline with

GKE
```shell
kubectl apply -f ./config/gke/python-pipelinerun-gke.yaml
```

OR

Local
```shell
kubectl apply -f ./config/kind/python-pipelinerun-kind.yaml
```

And then the pipeline should complete successfully, you can follow along:

```shell
kubectl get pipelineruns
NAME                      SUCCEEDED   REASON    STARTTIME   COMPLETIONTIME
build-pipeline-run        Unknown     Running   29s
```

You can view the logs of the pipeline run with [tkn cli](https://tekton.dev/docs/cli/)
```shell
tkn pipelineruns logs build-pipeline-run -f
```

If you have tekton dashboard installed

```bash
kubectl port-forward svc/tekton-dashboard 9097:9097 -n tekton-pipelines
```

![](images/tekton-dashboards.png)

When the pipeline finishes you see this in the logs

```shell
[source-to-image : build-and-push] INFO[0008] Pushing image to registry.local:5000/knative/pythontest:0.1
[source-to-image : build-and-push] INFO[0010] Pushed image to 1 destinations


[source-to-image : digest-to-results] sha256:824e9a8a00d5915bc87e25316dfbb19dbcae292970b02a464e2da1a665c7d54b
```

![](images/tekton-pipeline.png)

# Inspect results

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

```shell
TASK_NAME=build-pipeline-run-f57dc-source-to-image
```
The Source to image task will produce the image id of the container it built and push to the registry

```shell
IMAGE_ID=$(kubectl get taskruns ${TASK_NAME} -o jsonpath='{.spec.params[0].value}' | sed 's/:0.1//')@$(kubectl get taskruns ${TASK_NAME} -o jsonpath='{.status.taskResults[0].value}')
```

Example image id

```bash
echo $IMAGE_ID
gcr.io/chainguard-dev/pythontest@sha256:c089acd03a21830c329d70f61cefa2a29c43e59ebc848581043b631451dfffa7
```

Get the SBOM:

Pull down the Root CA from fulcio , Make sure you have set up [Network Access](#network)

```bash
curl http://fulcio.fulcio-system.svc:8080/api/v1/rootCert > ./fulcio-root.pem
```

Ensure the image was Signed:

```shell
SIGSTORE_ROOT_FILE=./fulcio-root.pem COSIGN_EXPERIMENTAL=1 cosign verify --allow-insecure-registry --rekor-url=http://rekor.rekor-system.svc:8080 --allow-insecure-registry $IMAGE_ID
```

And you should see something like this:
```
Verification for registry.local:5000/knative/pythontest@sha256:63ac5cfea7d421d92635f97e9e014b5ceed0613566d52111f990b6076e564905 --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - The claims were present in the transparency log
  - The signatures were integrated into the transparency log when the certificate was valid
  - Any certificates were verified against the Fulcio roots.

  [{"critical":{"identity":{"docker-reference":"registry.local:5000/knative/pythontest"},"image":{"docker-manifest-digest":"sha256:63a<SNIPPED HERE FOR READABILITY>
```


Now download the SBOM

```shell
COSIGN_EXPERIMENTAL=1 cosign download sbom --allow-insecure-registry  $IMAGE_ID > /tmp/sbom
```

Get the trivy scan result:

```shell
SIGSTORE_ROOT_FILE=./fulcio-root.pem COSIGN_EXPERIMENTAL=1 cosign verify-attestation --rekor-url=http://rekor.rekor-system.svc:8080 --allow-insecure-registry  $IMAGE_ID > /tmp/attestations
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

## Clean up

GKE
```shell
make tf_destroy
```

Local

```shell
kind delete cluster --name sigstore`
docker rm -f `docker ps -a | grep 'registry:2' | awk -F " " '{print $1}'
```
