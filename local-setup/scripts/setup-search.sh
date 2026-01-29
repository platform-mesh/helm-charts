#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
# This script is sourced by start.sh to load custom Docker images into the Kind cluster.
# Copy this file to load-custom-images.sh and customize it for your needs.
# The load-custom-images.sh file is gitignored, so your local changes won't be committed.
#
# Usage:
#   cp load-custom-images.sh.example load-custom-images.sh
#   # Edit load-custom-images.sh with your custom images
#   task local-setup:iterate

# Example: Load a locally built platform-mesh-operator image
kubectl apply -f $SCRIPT_DIR/../../search-operator-crds/templates/apiresourceschema-searchindices.core.platformmesh.io.yaml
kubectl apply -f $SCRIPT_DIR/../../search-operator-crds/templates/apiexport-core.platform-mesh.io.yaml

# Example: Load multiple images
# kind load docker-image ghcr.io/platform-mesh/portal:dev -n platform-mesh
# kind load docker-image ghcr.io/platform-mesh/api-syncagent:dev -n platform-mesh

# Example: Load from a tar archive
# kind load image-archive my-image.tar -n platform-mesh
