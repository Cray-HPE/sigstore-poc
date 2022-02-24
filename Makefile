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
KIND_CLUSTER_NAME=tekton-tf-dev
KIND_LOG_LEVEL=6
WORKSPACE_ID ?= $(shell cd terraform/ && terraform workspace show)
include .env

TK_CHAINS_HELM_CHART_VERSION="0.2.2"
TK_DASHBOARD_HELM_CHART_VERSION="0.2.0"
TK_PIPELINE_HELM_CHART_VERSION="v0.2.1"
SIGSTORE_HELM_VERSION="0.1.3"
export

dev_cluster:
	 kind create cluster \
        --verbosity=${KIND_LOG_LEVEL} \
        --name ${KIND_CLUSTER_NAME} \
        --config ./kind.yaml \
        --retain

delete_cluster:
	kind delete cluster --name ${KIND_CLUSTER_NAME}

################################################################################
# Terraform
################################################################################

tf_clean:
	cd terraform/ && \
	rm -rf .terraform \
	rm -rf plan.out

tf_init:
	terraform -chdir=terraform/ init

tf_get:
	terraform -chdir=terraform/ get

# Target apply for the GKE cluster, it has to exist before helm provider can use it
tf_target_plan:
	GOOGLE_APPLICATION_CREDENTIALS=${GOOGLE_APPLICATION_CREDENTIALS} \
	terraform -chdir=terraform/ plan \
	-var="TK_PIPELINE_HELM_LOCAL_PATH=${TK_PIPELINE_HELM_LOCAL_PATH}" \
	-var="TK_CHAINS_HELM_LOCAL_PATH=${TK_CHAINS_HELM_LOCAL_PATH}" \
	-var="TK_DASHBOARD_HELM_LOCAL_PATH=${TK_DASHBOARD_HELM_LOCAL_PATH}" \
	-var="WORKSPACE_ID=${WORKSPACE_ID}" \
	-var="K8S_CONTEXT=${K8S_CONTEXT}" \
	-var="SIGSTORE_HELM_LOCAL_PATH=${SIGSTORE_HELM_LOCAL_PATH}" \
	-var="SIGSTORE_HELM_VERSION=${SIGSTORE_HELM_VERSION}" \
	-var="TK_PIPELINE_HELM_CHART_VERSION=${TK_PIPELINE_HELM_CHART_VERSION}" \
	-var="TK_DASHBOARD_HELM_CHART_VERSION=${TK_DASHBOARD_HELM_CHART_VERSION}" \
	-var="TK_CHAINS_HELM_CHART_VERSION=${TK_CHAINS_HELM_CHART_VERSION}" \
	-var="SIGSTORE_HELM_VERSION=${SIGSTORE_HELM_VERSION}" \
	-var="TRILLIAN_PASSWORD=${TRILLIAN_PASSWORD}" \
	-target=google_container_cluster.primary \
	-target=google_service_account.gke-user \
	-target=google_project_iam_member.gcr_member

tf_target_apply:
	GOOGLE_APPLICATION_CREDENTIALS=${GOOGLE_APPLICATION_CREDENTIALS} \
	terraform -chdir=terraform/ apply \
	-var="TK_PIPELINE_HELM_LOCAL_PATH=${TK_PIPELINE_HELM_LOCAL_PATH}" \
	-var="TK_CHAINS_HELM_LOCAL_PATH=${TK_CHAINS_HELM_LOCAL_PATH}" \
	-var="TK_DASHBOARD_HELM_LOCAL_PATH=${TK_DASHBOARD_HELM_LOCAL_PATH}" \
	-var="WORKSPACE_ID=${WORKSPACE_ID}" \
	-var="K8S_CONTEXT=${K8S_CONTEXT}" \
	-var="SIGSTORE_HELM_LOCAL_PATH=${SIGSTORE_HELM_LOCAL_PATH}" \
	-var="SIGSTORE_HELM_VERSION=${SIGSTORE_HELM_VERSION}" \
	-var="TK_PIPELINE_HELM_CHART_VERSION=${TK_PIPELINE_HELM_CHART_VERSION}" \
	-var="TK_DASHBOARD_HELM_CHART_VERSION=${TK_DASHBOARD_HELM_CHART_VERSION}" \
	-var="TK_CHAINS_HELM_CHART_VERSION=${TK_CHAINS_HELM_CHART_VERSION}" \
	-var="SIGSTORE_HELM_VERSION=${SIGSTORE_HELM_VERSION}" \
	-var="TRILLIAN_PASSWORD=${TRILLIAN_PASSWORD}" \
	-target=google_container_cluster.primary \
	-target=google_service_account.gke-user \
	-target=google_project_iam_member.gcr_member \
	-auto-approve


tf_plan:
	GOOGLE_APPLICATION_CREDENTIALS=${GOOGLE_APPLICATION_CREDENTIALS} \
	terraform -chdir=terraform/  plan \
	-var="TK_PIPELINE_HELM_LOCAL_PATH=${TK_PIPELINE_HELM_LOCAL_PATH}" \
	-var="TK_CHAINS_HELM_LOCAL_PATH=${TK_CHAINS_HELM_LOCAL_PATH}" \
	-var="TK_DASHBOARD_HELM_LOCAL_PATH=${TK_DASHBOARD_HELM_LOCAL_PATH}" \
	-var="WORKSPACE_ID=${WORKSPACE_ID}" \
	-var="K8S_CONTEXT=${K8S_CONTEXT}" \
	-var="SIGSTORE_HELM_LOCAL_PATH=${SIGSTORE_HELM_LOCAL_PATH}" \
	-var="SIGSTORE_HELM_VERSION=${SIGSTORE_HELM_VERSION}" \
	-var="TK_PIPELINE_HELM_CHART_VERSION=${TK_PIPELINE_HELM_CHART_VERSION}" \
	-var="TK_DASHBOARD_HELM_CHART_VERSION=${TK_DASHBOARD_HELM_CHART_VERSION}" \
	-var="TK_CHAINS_HELM_CHART_VERSION=${TK_CHAINS_HELM_CHART_VERSION}" \
	-var="SIGSTORE_HELM_VERSION=${SIGSTORE_HELM_VERSION}" \
	-var="TRILLIAN_PASSWORD=${TRILLIAN_PASSWORD}" \
	-out=plan.out

tf_apply:
	GOOGLE_APPLICATION_CREDENTIALS=${GOOGLE_APPLICATION_CREDENTIALS} \
	terraform -chdir=terraform/ apply \
	-var="TK_PIPELINE_HELM_LOCAL_PATH=${TK_PIPELINE_HELM_LOCAL_PATH}" \
	-var="TK_CHAINS_HELM_LOCAL_PATH=${TK_CHAINS_HELM_LOCAL_PATH}" \
	-var="TK_DASHBOARD_HELM_LOCAL_PATH=${TK_DASHBOARD_HELM_LOCAL_PATH}" \
	-var="WORKSPACE_ID=${WORKSPACE_ID}" \
	-var="K8S_CONTEXT=${K8S_CONTEXT}" \
	-var="SIGSTORE_HELM_LOCAL_PATH=${SIGSTORE_HELM_LOCAL_PATH}" \
	-var="SIGSTORE_HELM_VERSION=${SIGSTORE_HELM_VERSION}" \
	-var="TK_PIPELINE_HELM_CHART_VERSION=${TK_PIPELINE_HELM_CHART_VERSION}" \
	-var="TK_DASHBOARD_HELM_CHART_VERSION=${TK_DASHBOARD_HELM_CHART_VERSION}" \
	-var="TK_CHAINS_HELM_CHART_VERSION=${TK_CHAINS_HELM_CHART_VERSION}" \
	-var="SIGSTORE_HELM_VERSION=${SIGSTORE_HELM_VERSION}" \
	-var="TRILLIAN_PASSWORD=${TRILLIAN_PASSWORD}" \
	-auto-approve

tf_fmt:
	terraform -chdir=terraform/ fmt

tf_target_destroy:
	GOOGLE_APPLICATION_CREDENTIALS=${GOOGLE_APPLICATION_CREDENTIALS} \
	terraform -chdir=terraform/ destroy \
	-var="TK_PIPELINE_HELM_LOCAL_PATH=${TK_PIPELINE_HELM_LOCAL_PATH}" \
	-var="TK_CHAINS_HELM_LOCAL_PATH=${TK_CHAINS_HELM_LOCAL_PATH}" \
	-var="TK_DASHBOARD_HELM_LOCAL_PATH=${TK_DASHBOARD_HELM_LOCAL_PATH}" \
	-var="WORKSPACE_ID=${WORKSPACE_ID}" \
	-var="K8S_CONTEXT=${K8S_CONTEXT}" \
	-var="SIGSTORE_HELM_LOCAL_PATH=${SIGSTORE_HELM_LOCAL_PATH}" \
	-var="SIGSTORE_HELM_VERSION=${SIGSTORE_HELM_VERSION}" \
	-var="TK_PIPELINE_HELM_CHART_VERSION=${TK_PIPELINE_HELM_CHART_VERSION}" \
	-var="TK_DASHBOARD_HELM_CHART_VERSION=${TK_DASHBOARD_HELM_CHART_VERSION}" \
	-var="TK_CHAINS_HELM_CHART_VERSION=${TK_CHAINS_HELM_CHART_VERSION}" \
	-var="SIGSTORE_HELM_VERSION=${SIGSTORE_HELM_VERSION}" \
	-var="TRILLIAN_PASSWORD=${TRILLIAN_PASSWORD}" \
	-target=google_container_cluster.primary \
	-target=google_service_account.gke-user \
	-target=google_project_iam_member.gcr_member \
	-auto-approve

tf_destroy:
	GOOGLE_APPLICATION_CREDENTIALS=${GOOGLE_APPLICATION_CREDENTIALS} \
	terraform -chdir=terraform/ destroy \
	-var="TK_PIPELINE_HELM_LOCAL_PATH=${TK_PIPELINE_HELM_LOCAL_PATH}" \
	-var="TK_CHAINS_HELM_LOCAL_PATH=${TK_CHAINS_HELM_LOCAL_PATH}" \
	-var="TK_DASHBOARD_HELM_LOCAL_PATH=${TK_DASHBOARD_HELM_LOCAL_PATH}" \
	-var="WORKSPACE_ID=${WORKSPACE_ID}" \
	-var="K8S_CONTEXT=${K8S_CONTEXT}" \
	-var="SIGSTORE_HELM_LOCAL_PATH=${SIGSTORE_HELM_LOCAL_PATH}" \
	-var="SIGSTORE_HELM_VERSION=${SIGSTORE_HELM_VERSION}" \
	-var="TK_PIPELINE_HELM_CHART_VERSION=${TK_PIPELINE_HELM_CHART_VERSION}" \
	-var="TK_DASHBOARD_HELM_CHART_VERSION=${TK_DASHBOARD_HELM_CHART_VERSION}" \
	-var="TK_CHAINS_HELM_CHART_VERSION=${TK_CHAINS_HELM_CHART_VERSION}" \
	-var="SIGSTORE_HELM_VERSION=${SIGSTORE_HELM_VERSION}" \
	-var="TRILLIAN_PASSWORD=${TRILLIAN_PASSWORD}" \
	-auto-approve

tf_import:
	GOOGLE_APPLICATION_CREDENTIALS=${GOOGLE_APPLICATION_CREDENTIALS} \
	terraform -chdir=terraform/ import \
	-var="TK_PIPELINE_HELM_LOCAL_PATH=${TK_PIPELINE_HELM_LOCAL_PATH}" \
	-var="TK_CHAINS_HELM_LOCAL_PATH=${TK_CHAINS_HELM_LOCAL_PATH}" \
	-var="TK_DASHBOARD_HELM_LOCAL_PATH=${TK_DASHBOARD_HELM_LOCAL_PATH}" \
	-var="WORKSPACE_ID=${WORKSPACE_ID}" \
	-var="K8S_CONTEXT=${K8S_CONTEXT}" \
	-var="SIGSTORE_HELM_LOCAL_PATH=${SIGSTORE_HELM_LOCAL_PATH}" \
	-var="SIGSTORE_HELM_VERSION=${SIGSTORE_HELM_VERSION}" \
	-var="TK_PIPELINE_HELM_CHART_VERSION=${TK_PIPELINE_HELM_CHART_VERSION}" \
	-var="TK_DASHBOARD_HELM_CHART_VERSION=${TK_DASHBOARD_HELM_CHART_VERSION}" \
	-var="TK_CHAINS_HELM_CHART_VERSION=${TK_CHAINS_HELM_CHART_VERSION}" \
	-var="SIGSTORE_HELM_VERSION=${SIGSTORE_HELM_VERSION}" \
	-var="TRILLIAN_PASSWORD=${TRILLIAN_PASSWORD}" \
	${ADDRESS} ${TARGET}