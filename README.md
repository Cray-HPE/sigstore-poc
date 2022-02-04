# build-playground

Playground for building an example e2e pipeline using Tekton Pipelines / Chains
for Python.

# Get started


## Local Development 

If you have Mac, run this:

```shell
./hack/setup-mac-kind.sh
```

if not, run this:
```shell
./hack/setup-kind.sh
```

This will set up a kind cluster on your machine with:

 * Knative serving
 * Sigstore (rekor, fulcio, etc.)
 * Tekton Chains / Pipelines
 * Tekton task for fetching github sources

## GCP Development 

Create the GKE Cluster, install Tekton Pipelines, Dashboard and Chains

```bash
make tf_init tf_plan tf_apply
```

Let's make sure we are running on the GKE cluster we just created, switch kubectl context

```bash
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

Installs fulcio and rekor, with a mysql backend running the cluster via ./hack/release-arm-gke.yaml

And finally test the installs with ./hack/testrelease-gke.yaml

Runs two jobs, one for checking the ctlog tree and one for verifying OIDC signing

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

kubectl logs checktree-828rg
2022/02/04 14:37:09 Got Payload: map[9ea3cde144cf9277764e1c96b70d8fc03c2370ba25a3010a65d5dcf5535cae83:{Attestation:<nil> Body:eyJhcGlWZXJzaW9uIjoiMC4wLjEiLCJraW5kIjoiaGFzaGVkcmVrb3JkIiwic3BlYyI6eyJkYXRhIjp7Imhhc2giOnsiYWxnb3JpdGhtIjoic2hhMjU2IiwidmFsdWUiOiJkMWI0NTBkZTA1MWEyYWE0ZDMzYTBlMzMxYjc5Y2RmMjY1YjM3MWRlOWMzYTk0NDUxM2I1NzgxODc0ZWE0N2Y4In19LCJzaWduYXR1cmUiOnsiY29udGVudCI6Ik1FWUNJUURiWW5NK3lUUkdlMWJtK2ppeGt3Tzl1UzAybThLU3MxMlRpODMvMlh1YlRBSWhBSVM2b0U0dnhZY0FJU0M0a0syaWRoT0xSSWdzcElycEhXQ3NCeUJzR1kzUCIsInB1YmxpY0tleSI6eyJjb250ZW50IjoiTFMwdExTMUNSVWRKVGlCRFJWSlVTVVpKUTBGVVJTMHRMUzB0Q2sxSlNVVldSRU5EUVdwNVowRjNTVUpCWjBsU1FVOWtTbE41YVRsaFZVZHZhMk5hUTNWWWFsWXdka0YzUkZGWlNrdHZXa2xvZG1OT1FWRkZURUpSUVhjS1lXcEZUVTFCYjBkQk1WVkZRbWhOUkZaV1RrSk5VWE4zUTFGWlJGWlJVVWxGZDBwWVVWUkZVazFCT0VkQk1WVkZRbmhOU1ZNeWJIbGhNbmhvWW0xUmVBcEdWRUZVUW1kT1ZrSkJhMVJFUkdNeVRubEJNbVJIWjJkVk0xRm5WWHBGVDAxQmQwZEJNVlZGUlZKTlJrOVVaM2ROZWsxNFJYcEJVa0puVGxaQ1FXOVVDa050VG05WlYyeDFXak5XYUdOdFVYZElhR05PVFdwSmQwMXFRVEJOVkZGNlRtcFZOVmRvWTA1TmFrbDNUV3BCTUUxVVVUQk9hbFUxVjJwQlFVMUdhM2NLUlhkWlNFdHZXa2w2YWpCRFFWRlpTVXR2V2tsNmFqQkVRVkZqUkZGblFVVTNSV2QwU1dKb1pWQTVlbkowVVV4NWJWSlBkREZwVXpCRVNHSnVkbmRxY1FwbmRYQkdUbmhrTm1neVNqRmtMMDlVU1ZWMWNuVkRlalp5YlV0d1YyY3hkRTV4VVZoaVZHOWFZWFZHUm0wMU9TdGtNbXBUTjNGUFEwRlRaM2RuWjBWckNrMUJORWRCTVZWa1JIZEZRaTkzVVVWQmQwbERRa1JCVkVKblRsWklVMVZGUkVSQlMwSm5aM0pDWjBWR1FsRmpSRUY2UVU5Q1owNVdTRkUwUlVKM1VVWUtRVkZKUkVKQldYZElkMWxFVmxJd2FrSkNaM2RHYjBGVlIyczJibEZyU210YVpHOVNVMHBNTTJSUlFsUlBXa0pRYnl0RmQxUjNXVVJXVWpCU1FWRklMd3BDUlZWM1VUUmFRbUZJVWpCalNFMDJUSGs1Y21SWFNteGpiVFZzWkVkV2VreHRiSFpNTWpWb1lsZFdlbU5IUm1wYVdFMTJXa2RXYlZsWVZuTmtRemw2Q2xwWVNqSmhWMDVzV1ZkT2FtSXpWblZrU0UxMldqSjBiRXhZVm5wYVdFbDNaWGRaUzB0M1dVSkNRVWRFZG5wQlFrRlJVblJoU0ZJd1kwaE5Oa3g1T1dvS1lqSTFNRmxYYkhWYVdFbDFXakk1ZGxveWVHeFpXRUp3WTNrMWFtSXlNSFprYWtWMlkwaEtkbUZ0Vm1wa1NFMTJXVEpvYUdGWE5XNWtWMFo1V2tNeGF3cGFXRmwyWWtjNWFsbFlVbkJpTWpWNlRETldla3hYVm1oak0xRjRURmRKZGxreWVERmpNMUpzWTI1TmRsa3lhR2hoVnpWdVpGZEdlVnBETVd0YVdGbDBDbG95ZEd4TmVrRk9RbWRyY1docmFVYzVkekJDUVZGelJrRkJUME5CWjBWQllWUnpjbGsyTkVkUE5URjRVa3hYTml0YVNWUmhUR3B0VFU1VVRteGhhVVlLYmtJM1VXdFZPRFpqTUhwNlVYQmpjVGhZZUhRMlduZG9WMGQ2TDJwMFlVdDRaMDR6UlhOWE5HaEhlVVY0V1VrMU1GUnJWMGgyWjBSSFR5OWhRVlZDUWdvM1psUlFhMWhwVEZVcldVNWtUWFJTV1dvelptVlJWbGh6Y1hNeWVYbEdWMGhZU2t4dWFESktla0ZKU3pKeldVUlhWVUZaVFNzNFozSkJSWGxvZW1OWUNubHRkMHh5Vldaak1YZERVMUpFZDJGdVVEWjFTRGh0YW1WNU5EVm9kbFk1VFVWMlQyVXliWE5YWWxsUlExSXhNM1pHUm5WSlpHZHNXVUozVkRNMVJHOEtRbEIyZUhjMVFVeFBXVWRqV0hKcllVMTRUbU5NZFRWSVJpOXdkSFZtZW1zek1GQXdUbWx1TkhZMWRrcHZkWHBJUnpnM1YxcFZhSEJsZEVsUldDOWhNZ3BTVVhSNWVGUnpTRk4yVTNOblRFSnRXa295U0VGSFpVVkxWbkZyYkdaWmJ5dDFia2t5YTNobFJXRjROelE0YkUxU05rcHNaSFo0T1V0bU9GWnhXV1JwQ2pKR1NtMTZjbEEwV0haR1RYSXpVWFJRVmtzM05qWkVZMUZXVUZFd0sxRjZVMUpPU213eFJtc3ZSMlp6TUhNM1JtRjJRMGQzU1VoWFJVZGFWMjE0Ym5jS2RTOXJUVUkzTWt4TmFVOVBhM1psWVZCSU9EVmtWVEEyWlhGMFdHMHJkWEl2UVhkd1VXTTFXbWh0Y1VSYVRXcEVabFpuVm0wMll6SjVkVkYySzFReU9BcHNPVEJ1Y1RVMk5sTkpkbWQ0U1RoU2N6ZFNjVlJJWVdwV09XWlNXbFpJTUU5QmJHRkplSGR2WmtveWMzUk5SbkZFT1dwNFduZDFVVTlVUm5ad1dHNUxDamx1VkV0bGRXMW5NMjFRZURGNFprcHFNR05yZW1Wc01uY3ZRMmhrTm1oaVZ6WkVZakJKV1VzME9HdElUVWRCUTFGclZUUXZTemxFZEVwc2EwbENjakVLWmpSTEsxVnhhMWwyZEhNNVpFRXlkMGRuTkRRNFZrRndRVUlyUlRJeFpYTnhVMUJKWkhkdmIzaE1NRFZtVDJ3eFlUWXhUbFI0ZWtoa01WSk1OMFZKS3dwNWVuSlVkRll3Y1VwMlJUMEtMUzB0TFMxRlRrUWdRMFZTVkVsR1NVTkJWRVV0TFMwdExRbz0ifX19fQ== IntegratedTime:0xc000129688 LogID:0xc00010d1f0 LogIndex:0xc000129720 Verification:0xc0001344a0}]

kubectl logs check-oidc-sl42c

Generating ephemeral keys...
Retrieving signed certificate...
**Warning** Using a non-standard public key for verifying SCT: /var/run/sigstore-root/rootfile.pem
Successfully verified SCT...
tlog entry created with index: 0
Pushing signature to: chainguard-dev/nginx 
```

# Tekton Overview

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
