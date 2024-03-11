#!/bin/bash

# Check if the cluster name is provided as an argument
if [ -z "$1" ]; then
  echo "Please provide the cluster name as an argument."
  echo "Usage: $0 <cluster-name>"
  exit 1
fi

# Set variables
CLUSTER_NAME=$1
REPO_URL="https://github.com/anish-mudaraddi/cloud-deployed-apps.git"
ARGOCD_NAMESPACE="argocd"


# Install ArgoCD using Helm
echo "Installing ArgoCD on cluster $CLUSTER_NAME using Helm..."
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd \
  --create-namespace \
  --namespace $ARGOCD_NAMESPACE \
# TODO: make argocd self-managed
#  -f values.yaml
  --wait


# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD to be ready..."
while ! kubectl get pods -n $ARGOCD_NAMESPACE -l app.kubernetes.io/name=argocd-server --field-selector=status.phase=Running 2>/dev/null | grep -q "Running"; do
  sleep 5
done

# Get the initial admin password
ARGOCD_PWD=$(kubectl -n $ARGOCD_NAMESPACE get secrets argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Install the ArgoCD CLI
echo "Installing ArgoCD CLI..."
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Configure ArgoCD
echo "Configuring ArgoCD for cluster $CLUSTER_NAME..."
argocd login --insecure --username admin --password "$ARGOCD_PWD" "$(kubectl get pods -n $ARGOCD_NAMESPACE -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].status.hostIP}'):8080"
argocd cluster add "$CLUSTER_NAME" --in-cluster


# Create the App of Apps
echo "Creating App of Apps for cluster $CLUSTER_NAME..."
argocd app create apps \
  --repo $REPO_URL \
  --path argocd/appofapps.yaml \
  --dest-server "https://kubernetes.default.svc" \
  --dest-namespace $ARGOCD_NAMESPACE \
  --sync-policy automated \
  --sync-option ServerSideApply=true \
  --values "clusterName=$CLUSTER_NAME"

echo "ArgoCD installation and configuration completed for cluster $CLUSTER_NAME."