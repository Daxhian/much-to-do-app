#!/bin/bash
set -e

CLUSTER_NAME="muchtodo-cluster"

echo "🧹 Cleaning up MuchToDo Kubernetes resources..."

# Delete all resources in the namespace
kubectl delete namespace muchtodo --ignore-not-found=true

echo "✅ Namespace and all resources deleted."
echo ""
echo "To also delete the Kind cluster entirely, run:"
echo "  kind delete cluster --name $CLUSTER_NAME"
read -p "Delete the Kind cluster too? (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  kind delete cluster --name "$CLUSTER_NAME"
  echo "✅ Kind cluster deleted."
fi
