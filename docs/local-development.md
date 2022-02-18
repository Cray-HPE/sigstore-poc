# Sigstore HPE POC

Playground for building an example e2e pipeline using Tekton Pipelines, Chains, Dashboard, Sigstore, Rekor, Cosign, and Fulcio for Python and Kind, and/or GCP/GKE.

**NOTE** We have to use `--allow-insecure-registry` due to this [cosign bug](https://github.com/sigstore/cosign/issues/1405).

## Notes for macOS

You may hit file limits; you can run `sudo launchctl limit maxfiles 65536 200000` to remediate that issue.

The airplay receiver uses port 5000, which may need to be disabled. Further details via [Apple's developer forum](https://developer.apple.com/forums/thread/682332). Alternatively, you can manually modify the script and change the [REGISTRY_PORT](https://github.com/vaikas/sigstore-scaffolding/blob/main/hack/setup-mac-kind.sh#L19)

# Set up Kubernetes cluster

We will set up the local Kubernetes cluster by running the `/hack/kind/setup-kind.sh` script.

```shell
./hack/kind/setup-kind.sh
```

This setup will take a few minutes. Note that you will be prompted for your root password while running the setup script. 

This script will set up a local Kubernetes kind cluster on your machine with:

 * Knative serving
 * sigstore (Rekor, Fulcio, etc.)
 * Tekton Chains / Pipelines
 * Tekton task for fetching GitHub sources

**Note**: You may receive some errors similar to the following:

```
Error from server (InternalError): error when creating "https://storage.googleapis.com/tekton-releases/chains/latest/release.yaml": Internal error occurred: failed calling webhook "config.webhook.pipeline.tekton.dev": Post "https://tekton-pipelines-webhook.tekton-pipelines.svc:443/config-validation?timeout=10s": dial tcp 10.96.244.5:443: connect: connection refused
```

They are due to some race conditions when installing Tekton components. There are retries built in, so as long things finish, it's ok. Cleaning those up will require some upstream work.

Once you get output that ends in the `::endgroup::` line, you'll know this initial setup is completed. The last few lines of the output should resemble the following.

```
...
configmap/dashboard-info created
service/tekton-dashboard created
deployment.apps/tekton-dashboard created
clusterrolebinding.rbac.authorization.k8s.io/tekton-dashboard-tenant created
::endgroup::
```

If you run `docker ps -a` at this point, you should have 3 containers, including a `registry.local`, a `sigstore-worker`, and a `sigstore-control-plane`. 

### Verify sigstore installs

There are two jobs that run to verify the installation. The first is `check-oidc` which signs an image with Cosign, and the second is `checktree` which ensures it's properly added to the Rekor transparency log. Both of them should show `1/1` completions.

```bash
kubectl get jobs
```

```
NAME         COMPLETIONS   DURATION   AGE
check-oidc   1/1           40s        9m19s
checktree    1/1           59s        9m19s
```

You can get the completed pod logs next.

```bash
for i in `kubectl get pods | grep Completed | awk -F " " '{print $1}'`
do
kubectl logs $i
done
```

A small snippet of the output you get should be similar to the following. 

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

We will need to set up port forwarding at this point. 

```shell
kubectl -n kourier-system port-forward service/kourier-internal 8080:80 &
```

Now, you'll be able to test Rekor. 

```bash
curl http://rekor.rekor-system.svc:8080/api/v1/log/
```

Running the above should generate the output that resembles the following. 

```
{
  "rootHash":"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "signedTreeHead":"Rekor\n0\n47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=\nTimestamp: 1644340477773818665\n\n— rekor.sigstore.dev LJZ0/DBFAiBkWCXKJWbDUzwozFh0HO8flMJu40Bdd5wpf/p2yF0brgIhAMx+Csi20A25zziQuacUaCKWBXpkG52Br0eKgcNrKzjI\n",
  "treeSize":0
}
```

At this point, we can move onto Tekton. 

# Tekton overview

> **Note** You may have to uninstall the Docker registry container between running the above scripts and the next because it spins up a registry container in a daemon mode. To clean a previously running registry, you can do one of these:

> YOLO:

> ```shell
> docker rm -f `docker ps -a | grep 'registry:2' | awk -F " " '{print $1}'`
> ```

> Or, to check things first:

> ```shell
> > docker ps -a | grep registry
```

> You'll get ther running version of the registry, so remove it: 

```
> b1e3f3238f7a   registry:2                        "/entrypoint.sh /etc…"   15 minutes ago   Up 15 minutes               0.0.0.0:5000->5000/tcp, :::5000->5000/tcp   registry.local
> ```

> ```shell
> docker rm -f b1e3f3238f7a
> ```

## Network access

### Adding localhost entries to make tools usable

First, add the following entries to your `/etc/hosts` file:

```
127.0.0.1 rekor.rekor-system.svc
127.0.0.1 fulcio.fulcio-system.svc
127.0.0.1 ctlog.ctlog-system.svc
```

This makes using tooling easier, for example:

```shell
rekor-cli --rekor_server http://rekor.rekor-system.svc:8080 loginfo
```

After smoke tests have successfully completed, you'll receive output similar to this: 

```
No previous log state stored, unable to prove consistency
Verification Successful!
Tree Size: 1
Root Hash: 062e2fa50e2b523f9cfd4eadc4b67745436226d64bf9799d57c5dc023681c4b8
Timestamp: 2022-02-04T22:09:46Z
```

If you run through this example more than once, you can remove the `~/.rekor/state.json` file in order to get verification output again. 

# Tekton tasks

Once you've installed the above, you can install the Tekton task and pipeline pieces. This is a very rough beginning of a proper Python pipeline and is meant to demonstrate breaking the large build into multiple steps and providing attestations at each level via Tekton Chains.

## Install tasks for pipeline

Run the following with `kubectl` to install all the tasks that are needed for the pipeline. After each command, you should receive output of tasks being created. 

```shell
kubectl apply -f ./config/common/
kubectl apply -f ./config/python/
kubectl apply -f ./config/go/
```

After these tasks are created, check to ensure what is installed.

```shell
kubectl get tasks,pipelines
```

Ensure that your output matches the following tasks and pipelines.

```
NAME                                          AGE
task.tekton.dev/git-clone                     61s
task.tekton.dev/install-go-dependencies       38s
task.tekton.dev/install-python-dependencies   44s
task.tekton.dev/kaniko                        61s
task.tekton.dev/ko-build-image                38s
task.tekton.dev/list-dependencies             61s
task.tekton.dev/sbom-syft                     61s
task.tekton.dev/scan-trivy                    61s
task.tekton.dev/sign-image                    61s

NAME                                        AGE
pipeline.tekton.dev/go-build-pipeline       38s
pipeline.tekton.dev/python-build-pipeline   44s
```

Next, run the Python pipeline.

```shell
kubectl apply -f ./config/kind/python-pipelinerun-kind.yaml
```

The pipeline should complete successfully, which you can follow along by checking the pipeline runs.

```shell
kubectl get pipelineruns
```

```
NAME                      SUCCEEDED   REASON    STARTTIME   COMPLETIONTIME
bare-build-pipeline-run   Unknown     Running   11s
```

You can view the logs of the pipeline run with the [tkn cli](https://tekton.dev/docs/cli/).

```shell
tkn pipelineruns logs bare-build-pipeline-run -f
```

If you have Tekton dashboard installed, you can run the below to view it. 

```bash
kubectl port-forward svc/tekton-dashboard 9097:9097 -n tekton-pipelines
```

![Screenshot of Tekton dashboard](../images/tekton-dashboards.png)

When the pipeline finishes, you'll receive the following output in the logs.

```shell
[source-to-image : build-and-push] INFO[0008] Pushing image to registry.local:5000/knative/pythontest:0.1
[source-to-image : build-and-push] INFO[0010] Pushed image to 1 destinations


[source-to-image : digest-to-results] sha256:824e9a8a00d5915bc87e25316dfbb19dbcae292970b02a464e2da1a665c7d54b
```

![Tekton pipeline](../images/tekton-pipeline.png)

## Inspect results

We also have an image that we create. This is a Python slim version that will only be used to install the requirements. After the installation completes, we grab the dependencies and copy them to `venv` for the Python script that will then run them.

### Certificates

There are two certificates that we need; the CT Log and Fulcio root certs. Note that if you are switching back and forth between public and your instance, you may not want to export these variables.

Get the CT Log: 

```shell
kubectl -n ctlog-system get secrets ctlog-public-key -o=jsonpath='{.data.public}' | base64 -d > ./ctlog-public.pem
export SIGSTORE_CT_LOG_PUBLIC_KEY_FILE=./ctlog-public.pem
```

Now get the Fulcio root:

```shell
kubectl -n fulcio-system get secrets fulcio-secret -ojsonpath='{.data.cert}' | base64 -d > ./fulcio-root.pem
export SIGSTORE_ROOT_FILE=./fulcio-root.pem
```

Next, grab the image that was produced by getting the latest source-to-image task run that has successfully completed.

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

The source to image task will produce the image ID of the container it built and push to the registry.

```shell
IMAGE_ID=$(kubectl get taskruns ${TASK_NAME} -o jsonpath='{.spec.params[0].value}' | sed 's/:0.1//')@$(kubectl get taskruns ${TASK_NAME} -o jsonpath='{.status.taskResults[0].value}')
```

Example image id:

```bash
echo $IMAGE_ID
```

```
gcr.io/chainguard-dev/pythontest@sha256:c089acd03a21830c329d70f61cefa2a29c43e59ebc848581043b631451dfffa7
```

Now, get the SBOM. We'll pull down the Root CA from Fulcio. Make sure you have set up [Network Access](#network-access).

```bash
curl http://fulcio.fulcio-system.svc:8080/api/v1/rootCert > ./fulcio-root.pem
```

Ensure that the image was signed.

```shell
SIGSTORE_ROOT_FILE=./fulcio-root.pem COSIGN_EXPERIMENTAL=1 cosign verify --allow-insecure-registry --rekor-url=http://rekor.rekor-system.svc:8080 --allow-insecure-registry $IMAGE_ID
```

After running the above, you should get output similar to this.

```
Verification for registry.local:5000/knative/pythontest@sha256:63ac5cfea7d421d92635f97e9e014b5ceed0613566d52111f990b6076e564905 --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - The claims were present in the transparency log
  - The signatures were integrated into the transparency log when the certificate was valid
  - Any certificates were verified against the Fulcio roots.

  [{"critical":{"identity":{"docker-reference":"registry.local:5000/knative/pythontest"},"image":{"docker-manifest-digest":"sha256:63a<SNIPPED HERE FOR READABILITY>
```

Now you can download the SBOM.

```shell
COSIGN_EXPERIMENTAL=1 cosign download sbom --allow-insecure-registry  $IMAGE_ID > /tmp/sbom
```

Get the Trivy scan result.

```shell
SIGSTORE_ROOT_FILE=./fulcio-root.pem COSIGN_EXPERIMENTAL=1 cosign verify-attestation --rekor-url=http://rekor.rekor-system.svc:8080 --allow-insecure-registry  $IMAGE_ID > /tmp/attestations
```

Finally, you should get this output that verifies everything was validated. 

```shell
Verification for gcr.io/chainguard-dev/pythontest@sha256:c089acd03a21830c329d70f61cefa2a29c43e59ebc848581043b631451dfffa7 --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - The claims were present in the transparency log
  - The signatures were integrated into the transparency log when the certificate was valid
  - Any certificates were verified against the Fulcio roots.
```

At this point we can clean up our work. 

```shell
kind delete cluster --name sigstore
docker rm -f `docker ps -a | grep 'registry:2' | awk -F " " '{print $1}'
```
