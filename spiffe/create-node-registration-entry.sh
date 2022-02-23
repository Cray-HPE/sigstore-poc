#/bin/bash

set -e

bb=$(tput bold)
nn=$(tput sgr0)


echo "${bb}Creating registration entry for the node...${nn}"
kubectl exec -n spire spire-server-0 -- \
    /opt/spire/bin/spire-server entry create \
    -node  \
    -spiffeID spiffe://oidc.vaikas.dev/ns/spire/sa/spire-agent \
    -selector k8s_sat:cluster:demo-cluster \
    -selector k8s_sat:agent_ns:spire \
    -selector k8s_sat:agent_sa:spire-agent

# Test executable for making sure Spiffe is up and running and
# connecting to Fulcio
kubectl exec -n spire spire-server-0 -- \
    /opt/spire/bin/spire-server entry create \
    -spiffeID spiffe://oidc.vaikas.dev/ns/spire-test/sa/spire \
    -parentID spiffe://oidc.vaikas.dev/ns/spire/sa/spire-agent \
    -socketPath /run/spire/sockets/api.sock \
    -selector k8s:ns:spire-test \
    -selector k8s:sa:spire

# Chains connections to Fulcio
kubectl exec -n spire spire-server-0 -- \
    /opt/spire/bin/spire-server entry create \
    -spiffeID spiffe://oidc.vaikas.dev/ns/tekton-chains/sa/tekton-chains-controller \
    -parentID spiffe://oidc.vaikas.dev/ns/spire/sa/spire-agent \
    -socketPath /run/spire/sockets/api.sock \
    -selector k8s:ns:tekton-chains \
    -selector k8s:sa:tekton-chains-controller
