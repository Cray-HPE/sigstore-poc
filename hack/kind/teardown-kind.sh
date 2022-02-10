#!/usr/bin/env bash

# Copyright 2022 Chainguard, Inc.
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o nounset
set -o pipefail

# Delete the kind cluster first
kind delete clusters kind

# Then remove the registry
docker rm -f `docker ps -a | grep 'registry:2' | awk -F " " '{print $1}'`
