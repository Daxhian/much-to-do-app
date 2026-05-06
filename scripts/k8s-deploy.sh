#!/bin/bash
set -e

CLUSTER_NAME="muchtodo-cluster"
IMAGE_NAME="muchtodo-backend:latest"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " MuchToDo — Kubernetes Deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Create Kind cluster if it doesn't exist
if kind get clusters | grep -q "$CLUSTER_NAME"; then
  echo "✅ Kind cluster '$CLUSTER_NAME' already exists"
else
  echo "🔧 Creating Kind cluster: $CLUSTER_NAME"
  kind create cluster --name "$CLUSTER_NAME"
fi

# 2. Build and load the backend image into Kind
echo ""
echo "🔨 Building backend Docker image..."
docker build -t "$IMAGE_NAME" .

echo "📦 Loading image into Kind cluster..."
kind load docker-image "$IMAGE_NAME" --name "$CLUSTER_NAME"

# 3. Install nginx ingress controller for Kind
echo ""
echo "🌐 Installing nginx ingress controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
echo "⏳ Waiting for ingress controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# 4. Apply all manifests in order
echo ""
echo "📋 Applying Kubernetes manifests..."
kubectl apply -f kubernetes/namespace.yaml

kubectl apply -f kubernetes/mongodb/mongodb-secret.yaml
kubectl apply -f kubernetes/mongodb/mongodb-configmap.yaml
kubectl apply -f kubernetes/mongodb/mongodb-pvc.yaml
kubectl apply -f kubernetes/mongodb/mongodb-deployment.yaml
kubectl apply -f kubernetes/mongodb/mongodb-service.yaml

kubectl apply -f kubernetes/backend/backend-secret.yaml
kubectl apply -f kubernetes/backend/backend-configmap.yaml
kubectl apply -f kubernetes/backend/backend-deployment.yaml
kubectl apply -f kubernetes/backend/backend-service.yaml

kubectl apply -f kubernetes/ingress.yaml

# 5. Wait for pods
echo ""
echo "⏳ Waiting for MongoDB pod to be ready..."
kubectl wait --namespace muchtodo \
  --for=condition=ready pod \
  --selector=app=mongodb \
  --timeout=120s

echo "⏳ Waiting for backend pods to be ready..."
kubectl wait --namespace muchtodo \
  --for=condition=ready pod \
  --selector=app=backend \
  --timeout=120s

# 6. Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Deployment complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
kubectl get pods -n muchtodo
echo ""
kubectl get services -n muchtodo
echo ""
echo "📡 Access via NodePort: http://localhost:30080/ping"
echo "📡 Access via Ingress:  http://muchtodo.local/ping"
echo "   (add '127.0.0.1 muchtodo.local' to /etc/hosts for ingress)"
