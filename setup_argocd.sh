#!/bin/bash

set -e

NAMESPACE="argocd"

echo "🚀 Creating ArgoCD namespace..."
kubectl create namespace $NAMESPACE || echo "⚠️ Namespace already exists"

echo "📥 Installing ArgoCD using official manifests..."
kubectl apply -n $NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "⏳ Waiting for ArgoCD components to be ready..."
kubectl wait --for=condition=Available deployment/argocd-server -n $NAMESPACE --timeout=300s || true

echo "📦 ArgoCD Pods:"
kubectl get pods -n $NAMESPACE

echo "📡 ArgoCD Services:"
kubectl get svc -n $NAMESPACE

echo "🔑 Fetching admin password..."
PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n $NAMESPACE -o jsonpath="{.data.password}" | base64 -d)
echo "===================================="
echo "ArgoCD Admin Password: $PASSWORD"
echo "===================================="

echo "🌐 ACCESS OPTIONS:"
echo "🔹 1) Port-forward (recommended locally):"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443 --address=0.0.0.0"
echo ""
echo "Then open browser: https://localhost:8080"
echo ""
echo "🔹 2) (Optional) Ingress for Domain Access"
echo "Create file: argocd-ui-ingress.yml and apply it manually:"
echo "kubectl apply -f argocd-ui-ingress.yml"
echo ""
echo "⚠ FIRST LOGIN USING:"
echo "Username: admin"
echo "Password: $PASSWORD"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443 --address=0.0.0.0"
echo "===================================="
echo "✔ ArgoCD Setup Completed!"

echo "📚 Next Steps:"
echo "1) Access ArgoCD UI using one of the methods above."
echo "2) Create a new Application in ArgoCD pointing to your Git repository."   
kubectl apply -f k8s/argocd-apps/project.yml -n argocd
kubectl apply -f k8s/argocd-apps/chat-application.yml -n argocd
