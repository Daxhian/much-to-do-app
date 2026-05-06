#!/bin/bash
set -e

IMAGE_NAME="muchtodo-backend"
IMAGE_TAG="${1:-latest}"

echo "🔨 Building Docker image: $IMAGE_NAME:$IMAGE_TAG"
docker build -t "$IMAGE_NAME:$IMAGE_TAG" .

echo "✅ Build complete: $IMAGE_NAME:$IMAGE_TAG"
echo ""
echo "To load into Kind cluster run:"
echo "  kind load docker-image $IMAGE_NAME:$IMAGE_TAG --name muchtodo-cluster"
