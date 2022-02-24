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
