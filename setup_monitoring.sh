#!/bin/bash
set -e

NAMESPACE="monitoring"

echo "🚀 Ensuring monitoring namespace..."
kubectl create namespace $NAMESPACE 2>/dev/null || echo "✔ Namespace exists"

echo "🛠 Enabling metrics-server (needed for CPU/memory dashboards)..."
minikube addons enable metrics-server
kubectl rollout status deployment/metrics-server -n kube-system || true

echo "📊 Checking Prometheus..."
if ! helm list -n $NAMESPACE | grep -q prometheus; then
  helm install prometheus prometheus-community/kube-prometheus-stack -n $NAMESPACE
else
  echo "✔ Prometheus already installed"
fi

echo "📦 Checking Loki..."
if ! helm list -n $NAMESPACE | grep -q loki; then
  helm install loki grafana/loki-stack -n $NAMESPACE --set grafana.enabled=false
else
  echo "✔ Loki already installed"
fi

echo "📥 Deploying Promtail (log collector)..."
cat <<EOF > promtail-values.yaml
server:
  http_listen_port: 3101
  grpc_listen_port: 0

clients:
  - url: http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push

scrape_configs:
  - job_name: kubernetes-pods
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app,__meta_kubernetes_pod_label_app_kubernetes_io_name]
        action: keep
        regex: backend|frontend|mongodb
      - source_labels: [__meta_kubernetes_pod_name]
        target_label: pod
      - source_labels: [__meta_kubernetes_namespace]
        target_label: namespace
      - source_labels: [__meta_kubernetes_pod_node_name]
        target_label: node
      - source_labels: [__meta_kubernetes_pod_container_name]
        target_label: container
EOF

helm upgrade --install promtail grafana/promtail -n $NAMESPACE -f promtail-values.yaml

echo "📊 Checking Grafana..."
if ! helm list -n $NAMESPACE | grep -q grafana; then
  helm install grafana grafana/grafana -n $NAMESPACE
else
  echo "✔ Grafana already installed"
fi

echo "🔌 Creating Grafana datasource ConfigMap..."
cat <<EOF | kubectl apply -n $NAMESPACE -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  labels:
    grafana_datasource: "1"
data:
  prometheus.yaml: |
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://prometheus-kube-prometheus-prometheus:9090
        isDefault: true
  loki.yaml: |
    apiVersion: 1
    datasources:
      - name: Loki
        type: loki
        access: proxy
        url: http://loki.monitoring.svc.cluster.local:3100
        isDefault: false
EOF

echo "🧠 Auto-detecting Prometheus Deployment..."
PROM_DEPLOY=$(kubectl get deployment -n monitoring | grep prometheus-kube | awk '{print $1}')
if [ -n "$PROM_DEPLOY" ]; then
  echo "🔄 Restarting Prometheus deployment: $PROM_DEPLOY"
  kubectl rollout restart deployment $PROM_DEPLOY -n monitoring
else
  echo "⚠️ Prometheus deployment NOT found — skipping."
fi

echo "🌀 Restarting Grafana..."
kubectl rollout restart deployment grafana -n $NAMESPACE

echo "🚀 Port-forwarding Grafana on http://localhost:3000 ..."
kubectl port-forward svc/grafana -n $NAMESPACE 3000:80 --address=0.0.0.0 &
sleep 4

GRAFANA_PWD=$(kubectl get secret grafana -n $NAMESPACE -o jsonpath="{.data.admin-password}" | base64 -d)

echo "
=====================================================
🎉 SETUP COMPLETED — MONITORING IS READY!
=====================================================

📊 Verify Prometheus Targets:
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090 &
👉 Open: http://localhost:9090/targets  → ALL must be UP

📩 Verify Promtail Logs:
kubectl logs -l app=promtail -n monitoring --tail=50 | grep -E 'backend|frontend|mongodb'

🌐 Grafana Dashboard → http://localhost:3000
👤 USERNAME         → admin
🔐 PASSWORD         → $GRAFANA_PWD

📌 In Grafana Explore — Use These Queries:

🟢 Check Logs (Loki):
{app=\"backend\"}
{app=\"backend\"} |= \"ERROR\"
{app=\"mongodb\"}
{app=\"frontend\"} |= \"404\"

📈 Check Pod Metrics (Prometheus):
up
kube_pod_container_status_restarts_total
rate(container_cpu_usage_seconds_total[5m])
container_memory_usage_bytes

💡 NEXT:
👉 \"Generate Grafana Dashboard JSON\"
👉 \"Enable Slack/Telegram Alerts\"
👉 \"API Performance Monitoring\"

=====================================================
"
