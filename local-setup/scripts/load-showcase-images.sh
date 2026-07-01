#!/bin/bash
# Preload showcase images into the platform-mesh kind cluster.
#
# generic-resource-ui and terminal images are published to GHCR under private
# packages. Kind nodes do not inherit host GHCR credentials, so we pull on the
# host (which is authenticated) and side-load into the cluster.

set -eo pipefail

IMAGES=(
  "ghcr.io/platform-mesh/generic-resource-ui:v0.2.1"
  "ghcr.io/platform-mesh/terminal-controller-manager:v0.3.0"
  "ghcr.io/platform-mesh/terminal:v0.3.0"
)

for img in "${IMAGES[@]}"; do
  echo "Pulling ${img}"
  docker pull "$img"
  echo "Loading ${img} into kind cluster platform-mesh"
  kind load docker-image --name platform-mesh "$img"
done
