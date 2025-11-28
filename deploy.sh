
---

## 🔧 **deploy.sh (Shell Script)**

```bash
#!/bin/bash

echo "🚀 Starting Deployment..."

### 1. Create Namespace & Secrets
cd k8s
kubectl apply -f namespace.yml
kubectl apply -f secrets.yml

### 2. MongoDB
kubectl apply -f mongodb-pv.yml
kubectl apply -f mongodb-pvc.yml
kubectl apply -f mongodb-deployment.yml
kubectl apply -f mongodb-service.yml

### 3. Backend Deployment
cd ../backend
docker build -t smitdarji/k8s-chat-app-backend:latest .
docker push smitdarji/k8s-chat-app-backend:latest

cd ../k8s
kubectl apply -f backend-deployment.yml
kubectl apply -f backend-service.yml

### 4. Frontend Deployment
cd ../frontend
docker build -t smitdarji/k8s-chat-app-frontend:latest .
docker push smitdarji/k8s-chat-app-frontend:latest

cd ../k8s
kubectl apply -f frontend-deployment.yml
kubectl apply -f frontend-service.yml

### 5. Ingress Setup
kubectl apply -f ingress.yml
minikube addons enable ingress
echo "⚠️ Run this manually in terminal:  minikube tunnel"

### 6. Optional Port Forward
echo "To test services manually:"
echo "kubectl port-forward -n chat-app svc/mongo 8000:80"
echo "kubectl port-forward -n chat-app svc/frontend 8000:80"

echo "✔ Deployment Completed!"
