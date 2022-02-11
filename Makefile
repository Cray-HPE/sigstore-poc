KIND_CLUSTER_NAME=tekton-tf-dev
KIND_LOG_LEVEL=6
WORKSPACE_ID ?= $(shell cd terraform/ && terraform workspace show)
include .env

tk_chains_helm_chart_version="0.2.0"
tk_dashboard_helm_chart_version="0.2.0"
tk_pl_helm_chart_version="v0.2.0"

export

dev_cluster:
	 kind create cluster \
        --verbosity=${KIND_LOG_LEVEL} \
        --name ${KIND_CLUSTER_NAME} \
        --config ./config/kind.yaml \
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
	cd terraform/ && \
	terraform init

tf_get:
	cd terraform/ && \
	terraform get

# Target apply for the GKE cluster, it has to exist before helm provider can use it
tf_target_plan:
	cd terraform/ && \
	GOOGLE_APPLICATION_CREDENTIALS=${GOOGLE_APPLICATION_CREDENTIALS} terraform plan \
	-var="tk_pl_local=${TK_PL_HELM_PATH}" \
	-var="tk_chains_local=${TK_CHAINS_HELM_PATH}" \
	-var="tk_dashboard_local=${TK_DASHBOARD_HELM_PATH}" \
	-var="tk_chains_helm_chart_version=${tk_chains_helm_chart_version}" \
	-var="workspace_id=${WORKSPACE_ID}" \
	-var="config_context=${K8S_CONTEXT}" \
	-target=google_container_cluster.primary \
	-target=google_service_account.gke-user \
	-target=google_project_iam_member.gcr_member

tf_target_apply:
	cd terraform/ && \
	GOOGLE_APPLICATION_CREDENTIALS=${GOOGLE_APPLICATION_CREDENTIALS} terraform apply \
	-var="tk_pl_local=${TK_PL_HELM_PATH}" \
	-var="tk_chains_local=${TK_CHAINS_HELM_PATH}" \
	-var="tk_dashboard_local=${TK_DASHBOARD_HELM_PATH}" \
	-var="config_context=${K8S_CONTEXT}" -var="workspace_id=${WORKSPACE_ID}" \
	-target=google_container_cluster.primary \
	-target=google_service_account.gke-user \
	-target=google_project_iam_member.gcr_member \
	-auto-approve


tf_plan:
	cd terraform/ && \
	terraform plan \
	-var="tk_pl_local=${TK_PL_HELM_PATH}" \
	-var="tk_chains_local=${TK_CHAINS_HELM_PATH}" \
	-var="tk_dashboard_local=${TK_DASHBOARD_HELM_PATH}" \
	-var="config_context=${K8S_CONTEXT}" -var="workspace_id=${WORKSPACE_ID}" \
	-out=plan.out

tf_apply:
	cd terraform/ && \
	terraform apply \
	-var="tk_pl_local=${TK_PL_HELM_PATH}" \
	-var="tk_chains_local=${TK_CHAINS_HELM_PATH}" \
	-var="tk_dashboard_local=${TK_DASHBOARD_HELM_PATH}" \
	-var="workspace_id=${WORKSPACE_ID}" \
	-var="config_context=${K8S_CONTEXT}" \
	-auto-approve

tf_fmt:
	cd terraform/ && \
	terraform fmt

tf_target_destroy:
		cd terraform/ && \
    	terraform destroy \
    	-var="tk_pl_local=${TK_PL_HELM_PATH}" \
    	-var="tk_chains_local=${TK_CHAINS_HELM_PATH}" \
    	-var="tk_dashboard_local=${TK_DASHBOARD_HELM_PATH}" \
    	-var="workspace_id=${WORKSPACE_ID}" \
    	-var="config_context=${K8S_CONTEXT}" \
		-target=google_container_cluster.primary \
		-target=google_service_account.gke-user \
		-target=google_project_iam_member.gcr_member \
    	-auto-approve

tf_destroy:
	cd terraform/ && \
	terraform destroy \
	-var="tk_pl_local=${TK_PL_HELM_PATH}" \
	-var="tk_chains_local=${TK_CHAINS_HELM_PATH}" \
	-var="tk_dashboard_local=${TK_DASHBOARD_HELM_PATH}" \
	-var="workspace_id=${WORKSPACE_ID}" \
	-var="config_context=${K8S_CONTEXT}" \
	-auto-approve