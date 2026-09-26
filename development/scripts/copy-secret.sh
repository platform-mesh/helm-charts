#!/bin/bash

# Usage: ./copy-secret.sh <source-secret-name> <source-namespace> <target-secret-name> <target-namespace>
# Example: ./copy-secret.sh my-secret default my-secret-copy new-namespace

set -e

SOURCE_SECRET_NAME="$1"
SOURCE_NAMESPACE="$2"
TARGET_SECRET_NAME="$3"
TARGET_NAMESPACE="$4"

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <source-secret-name> <source-namespace> <target-secret-name> <target-namespace>"
  exit 1
fi

# Fetch the secret as YAML
kubectl get secret "$SOURCE_SECRET_NAME" -n "$SOURCE_NAMESPACE" -o yaml \
| sed "s/name: $SOURCE_SECRET_NAME/name: $TARGET_SECRET_NAME/" \
| yq eval "del(.metadata.namespace) | .metadata.namespace = \"$TARGET_NAMESPACE\"" - \
| yq eval 'del(.metadata.uid, .metadata.resourceVersion, .metadata.creationTimestamp, .metadata.annotations, .metadata.managedFields)' - \
| kubectl apply -f -
