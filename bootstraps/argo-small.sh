#!/bin/bash
echo "Creating the Kind Cluster"
kind create cluster --name argo-cluster --config ./kind-config/small-cluster.yaml
echo

echo "Installing ArgoCD Using Helm"
kubectl create namespace argocd
# helm repo add argo https://argoproj.github.io/argo-helm
# helm repo update
# helm repo list
# helm install argocd argo/argo-cd --version 6.7.11 --namespace argocd #--values ./helm/argocd/values.yaml
# helm list -n argocd

kubectl apply -n argocd -f ./manifests/kube.yaml

echo "Setting the Argo Admin Password"
export ARGO_ADMIN_PASSWORD=abc123
kubectl patch secret -n argocd argocd-secret -p '{"stringData": { "admin.password": "'$(htpasswd -bnBC 10 "" $ARGO_ADMIN_PASSWORD | tr -d ':\n')'"}}'
echo

# echo "Patching the ArgoCD CM"
# kubectl patch configmap argocd-cm -n argocd --patch '{
#   "data": {
#     "resource.customizations": "argoproj.io/v1alpha1,Application:\n  ignoreDifferences: |\n    jsonPointers:\n      - \"/metadata/annotations/foo.bar.com/snow-data\""
#   }
# }'
# echo

echo "Creating the ArgoCD Root Application"
kubectl apply -f ./app-of-apps/root-app/my-application.yml
echo

echo "Dont forget to port-forward the ArgoCD Server. Run this in another terminal:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:80"
echo