_TODO: Need to update_

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

## GCP Development

### Kubernetes Cluster

Terraform will create the Trillian MySQL database, the Google CA, GKE Cluster and 
install Tekton Pipelines, Dashboard and Chains via Helm and Sigstore via helm

We are doing a terraform targeted plan/apply because the GKE cluster has to be up and running before helm can apply,
since we are directly pointing the helm provider to the GKE cluster.

You will need to have gcloud [installed](https://cloud.google.com/sdk/docs/install)

Set the GOOGLE_APPLICATION_CREDENTIALS path to where `gcloud auth application-default login` places your credentials file

Usually that is `$HOME/.config/gcloud/application_default_credentials.json` 

Let's build the GKE Cluster, Roles and GCR Repo

```bash
make tf_init tf_target_plan tf_target_apply 
```


**NOTE** Since we are using GCP SQL instance, we need to use CloudSQL Proxy, now that cuases issues with a sidecars and 
Kubernetes Jobs, see this [KEP for more information](https://github.com/kubernetes/enhancements/issues/2872). 
So we have own process for dealing with this, we can use the images stored in the defaults. Or rebuild your own and use those.
[SQLproxy is here](cmd/trillian/sqlproxy)

We can use `ko` to build and push those images to gcr. https://github.com/google/ko

```shell
KO_DOCKER_REPO=gcr.io/YOURPROJECT/sqlproxy ko build --platform=all sigstore-poc/cmd/trillian/sqlproxy/cmd -B
KO_DOCKER_REPO=gcr.io/YOURPROJECT/ ko build --platform=all sigstore-poc/cmd/trillian/createdb/ -B
```

We need to make sure we have the helm charts locally as they are not stored in Artifactory hub.

```bash
git clone git@github.com:Cray-HPE/sigstore-charts.git $PWD/sigstore-charts
git checkout gke-hpe
```

```bash
git clone git@github.com:Cray-HPE/tekton-helm-charts.git $PWD/tekton-helm-chart
git checkout templates
```

Created an .env file with the following vars

```bash
TK_PIPELINE_HELM_LOCAL_PATH=$PWD/tekton-helm-chart/charts/tekton-pipelines
TK_CHAINS_HELM_LOCAL_PATH=$PWD/tekton-helm-chart/charts/tekton-chains
TK_DASHBOARD_HELM_LOCAL_PATH=$PWD/tekton-helm-chart/charts/tekton-dashboard
GOOGLE_APPLICATION_CREDENTIALS=$HOME/.config/gcloud/application_default_credentials.json
SIGSTORE_HELM_LOCAL_PATH=/Users/strongjz/Documents/code/go/src/github.com/sabre1041/sigstore-charts
TRILLIAN_PASSWORD=trillian
```

Now we can deploy everything with Terraform

```bash
make tf_plan tf_apply

Apply complete! Resources: 29 added, 29 changed, 0 destroyed.

Outputs:

ca_certificate = tolist([
  <<-EOT
  -----BEGIN CERTIFICATE-----
  -----END CERTIFICATE-----
  
  EOT,
])
database_connection_string = "chainguard-dev:us-east1:terraform-20220223171632604900000001"
gcp_private_ca_parent = "projects/chainguard-dev/locations/us-east1/caPools/sigstore-poc-default"
```

Let's make sure we are running on the GKE cluster we just created, switch kubectl context

```bash
gcloud auth application-default login # if need be
gcloud container clusters list
NAME                 LOCATION    MASTER_VERSION   MASTER_IP       MACHINE_TYPE   NODE_VERSION     NUM_NODES  STATUS
chainguard-dev       us-east1-b  1.21.6-gke.1500  35.229.115.236  n1-standard-4  1.21.6-gke.1500  2          RUNNING


gcloud container clusters  get-credentials chainguard-dev

kubectl config get-contexts
CURRENT   NAME                                                CLUSTER                                             AUTHINFO                                    
*         gke_chainguard-dev_us-east1-b_chainguard-dev        gke_chainguard-dev_us-east1-b_chainguard-dev        gke_chainguard-dev_us-east1-b_chainguard-dev
          kind-kind                                           kind-kind                                           kind-kind

kubectl config use-context gke_chainguard-dev_us-east1-b_chainguard-dev
Switched to context "gke_chainguard-dev_us-east1-b_chainguard-dev".
```

### Verify Sigstore installs

Verifying Fulcio server deployment

```bash
kubectl logs deployment/fulcio -n fulcio-system
2022-02-23T18:29:20.345Z        INFO    app/serve.go:172        0.0.0.0:5555
```

Verifying Rekor server deployment 

```shell
k logs deployment/rekor-server -n rekor-system
2022-02-23T18:29:56.374Z        INFO    app/serve.go:70 starting rekor-server @ {
  "GitVersion": "v0.5.0",
  "GitCommit": "09ecf71dff57de24ec5e779b4077b187956edf0e",
  "GitTreeState": "clean",
  "BuildDate": "'2022-02-04T12:25:24Z'",
  "GoVersion": "go1.17.6",
  "Compiler": "gc",
  "Platform": "linux/amd64"
}
2022-02-23T18:29:56.397Z        INFO    app/serve.go:97 Loading support for pluggable type 'helm'
2022-02-23T18:29:56.397Z        INFO    app/serve.go:98 Loading version '0.0.1' for pluggable type 'helm'
2022-02-23T18:29:56.397Z        INFO    app/serve.go:97 Loading support for pluggable type 'hashedrekord'
2022-02-23T18:29:56.397Z        INFO    app/serve.go:98 Loading version '0.0.1' for pluggable type 'hashedrekord'
2022-02-23T18:29:56.397Z        INFO    app/serve.go:97 Loading support for pluggable type 'rpm'
2022-02-23T18:29:56.397Z        INFO    app/serve.go:98 Loading version '0.0.1' for pluggable type 'rpm'
2022-02-23T18:29:56.397Z        INFO    app/serve.go:97 Loading support for pluggable type 'jar'
2022-02-23T18:29:56.397Z        INFO    app/serve.go:98 Loading version '0.0.1' for pluggable type 'jar'
2022-02-23T18:29:56.397Z        INFO    app/serve.go:97 Loading support for pluggable type 'alpine'
2022-02-23T18:29:56.397Z        INFO    app/serve.go:98 Loading version '0.0.1' for pluggable type 'alpine'
2022-02-23T18:29:56.397Z        INFO    app/serve.go:97 Loading support for pluggable type 'tuf'
2022-02-23T18:29:56.397Z        INFO    app/serve.go:98 Loading version '0.0.1' for pluggable type 'tuf'
2022-02-23T18:29:56.397Z        INFO    app/serve.go:97 Loading support for pluggable type 'rekord'
2022-02-23T18:29:56.397Z        INFO    app/serve.go:98 Loading version '0.0.1' for pluggable type 'rekord'
2022-02-23T18:29:56.397Z        INFO    app/serve.go:97 Loading support for pluggable type 'intoto'
2022-02-23T18:29:56.397Z        INFO    app/serve.go:98 Loading version '0.0.1' for pluggable type 'intoto'
2022-02-23T18:29:56.397Z        INFO    app/serve.go:97 Loading support for pluggable type 'rfc3161'
2022-02-23T18:29:56.397Z        INFO    app/serve.go:98 Loading version '0.0.1' for pluggable type 'rfc3161'
2022-02-23T18:29:56.401Z        INFO    storage/storage.go:40   Configuring attestation storage at file:///var/run/attestations
2022-02-23T18:29:56.420Z        INFO    restapi/server.go:234   Serving rekor server at http://[::]:3000
```

We didn't deploy the sigstore pieces with ingress so let's use kubectl port-forward to make requests to rekor and fulcio

```bash
kubectl port-forward svc/fulcio 8081:80 -n fulcio-system &
kubectl port-forward svc/rekor-server 8080:3000 -n rekor-system &
```

Add the following entries to your `/etc/hosts` file
```
127.0.0.1 rekor.rekor-system.svc
127.0.0.1 fulcio.fulcio-system.svc
127.0.0.1 ctlog.ctlog-system.svc
```

Testing Fulcio

```bash
curl -s http://fulcio.fulcio-system.svc:8081/api/v1/rootCert |  openssl x509 -noout -subject
subject= /O=Example, Org./CN=Example Authority
```

This will match the Subject from Terraform Google CA deployment 

Testing Rekor

```bash
 curl http://rekor.rekor-system.svc/api/v1/log/
```

```
rootHash: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
signedTreeHead: |
  Rekor
  0
  47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=
  Timestamp: 1645640664017031120

  — rekor.sigstore.dev H2kZmzBFAiEA3PYwgkv2MMtRpbENLWgjVfddgdnbyxBo9hArYv43erMCIErMVAYmxsT9IgeT3U841wb9DWRYKWHoKMTvIJufE03/
treeSize: 0
```

If there are any issues with the OIDC you can verify the [OIDC setup](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)

```bash
kubectl apply -f ./hack/gke/test-gke-user.yaml
kubectl exec -it workload-identity-test -- curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/service-accounts/

default-user-workload@chainguard-dev.iam.gserviceaccount.com/
default/
```


# Tekton Overview

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
kubectl apply -f ./config/gke/
```

And then the pipeline should complete successfully, you can follow along:

```shell
kubectl get pipelineruns
```

```
NAME                      SUCCEEDED   REASON    STARTTIME   COMPLETIONTIME
build-pipeline-run        Unknown     Running   29s
```

You can view the logs of the pipeline run with [tkn cli](https://tekton.dev/docs/cli/)

```shell
tkn pipelineruns logs build-pipeline-run -f
```

If you have tekton dashboard installed

```bash
kubectl port-forward svc/tekton-dashboard 9097:9097 -n tekton-pipelines &
```

![Tekton dashboard](../images/tekton-dashboards.png)

When the pipeline finishes you see this in the logs

```shell
[source-to-image : build-and-push] INFO[0008] Pushing image to registry.local:5000/knative/pythontest:0.1
[source-to-image : build-and-push] INFO[0010] Pushed image to 1 destinations


[source-to-image : digest-to-results] sha256:824e9a8a00d5915bc87e25316dfbb19dbcae292970b02a464e2da1a665c7d54b
```

![Tekton pipeline](../images/tekton-pipeline.png)

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
curl http://fulcio.fulcio-system.svc:8081/api/v1/rootCert > fulcio-root.pem
export SIGSTORE_ROOT_FILE=./fulcio-root.pem
```

Grab the image that was produced

Get the latest source-to-image task run that has completed successfully

```bash
kubectl get  taskruns  -l  "tekton.dev/pipeline"="python-build-pipeline" -l "tekton.dev/pipelineTask"="source-to-image"
```

```
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

Pull down the Root CA from fulcio, Make sure you have set up Network Access

```bash
curl http://fulcio.fulcio-system.svc:8081/api/v1/rootCert > ./fulcio-root.pem
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