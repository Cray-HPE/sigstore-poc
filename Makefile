KIND_CLUSTER_NAME=tekton-tf-dev
KIND_LOG_LEVEL=6

TK_PL_HELM_VERSION="0.1.1"

include .env

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
	cd terraform/ && \
	terraform init

tf_get:
	cd terraform/ && \
	terraform get

tf_plan:
	cd terraform/ && \
	terraform plan \
	-var="tk_pl_local=${TK_PL_HELM_PATH}" \
	   	-var="tk_chains_local=${TK_CHAINS_HELM_PATH}" \
        	-var="tk_dashboard_local=${TK_DASHBOARD_HELM_PATH}" \
        		-out=plan.out

tf_apply:
	cd terraform/ && \
	terraform apply \
	-var="tk_pl_local=${TK_PL_HELM_PATH}" \
	   	-var="tk_chains_local=${TK_CHAINS_HELM_PATH}" \
        	-var="tk_dashboard_local=${TK_DASHBOARD_HELM_PATH}" \
		-auto-approve

tf_fmt:
	cd terraform/ && \
	terraform fmt

tf_destroy:
	cd terraform/ && \
	terraform destroy \
	-var="tk_pl_local=${TK_PL_HELM_PATH}" \
	   	-var="tk_chains_local=${TK_CHAINS_HELM_PATH}" \
        	-var="tk_dashboard_local=${TK_DASHBOARD_HELM_PATH}" \
		-auto-approve