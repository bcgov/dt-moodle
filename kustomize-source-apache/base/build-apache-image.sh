#!/bin/bash

# Set variables
REGISTRY="${REGISTRY_URL}"
NAMESPACE="aa0156-tools"
IMAGE_NAME="dt-moodle-apache"
IMAGE_TAG="${ENVIRONMENT}"

# Login to the registry
oc login --token=$(oc whoami -t) --server="${CLUSTER_URL}"
oc registry login

# Build the image
echo "Building the Apache-based Moodle image..."
docker build -t ${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG} -f Dockerfile .

# Push the image to the registry
echo "Pushing the image to the registry..."
docker push ${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}

echo "Done! The new Apache-based Moodle image has been built and pushed to the registry."
echo "Image: ${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}" 