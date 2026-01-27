# システムモニタリング

ccplant プロジェクトのシステムモニタリングとメトリクス収集の完全ガイドです。

## 目次

- [概要](#概要)
- [ヘルスチェック](#ヘルスチェック)
- [OpenTelemetry Collector 統合](#opentelemetry-collector-統合)
- [メトリクス収集](#メトリクス収集)
- [Prometheus 統合](#prometheus-統合)
- [ログ集約](#ログ集約)
- [アラート設定](#アラート設定)
- [ダッシュボード](#ダッシュボード)
- [トラブルシューティング](#トラブルシューティング)

## 概要

ccplant は以下のモニタリング機能を提供します:

### モニタリングの階層

```
┌─────────────────────────────────────────────┐
│  ダッシュボード (Grafana)                   │
│  可視化とアラート管理                        │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│  メトリクス収集 (Prometheus)                │
│  時系列データの保存とクエリ                  │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│  メトリクス生成                              │
│  - Backend: /metrics エンドポイント (9464)  │
│  - Frontend: /metrics エンドポイント (9090) │
│  - Kubernetes メトリクス                     │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│  ヘルスチェック                              │
│  - Liveness Probe: /health                  │
│  - Readiness Probe: /health                 │
└─────────────────────────────────────────────┘
```

### 主要なメトリクス

| カテゴリ | メトリクス | 説明 |
|---------|-----------|------|
| アプリケーション | HTTP リクエスト数、レスポンスタイム | アプリケーションパフォーマンス |
| リソース | CPU、メモリ、ディスク使用率 | システムリソースの監視 |
| Kubernetes | Pod 数、再起動回数、ノード状態 | クラスターヘルス |
| ビジネス | アクティブセッション数、ユーザー数 | ビジネスメトリクス |

## ヘルスチェック

### Backend ヘルスチェック

#### エンドポイント

```bash
# ヘルスチェックエンドポイント
GET http://localhost:8080/health

# 期待されるレスポンス
{
  "status": "healthy",
  "version": "v1.191.0",
  "timestamp": "2024-01-27T12:00:00Z"
}
```

#### Kubernetes での設定

```yaml
# Deployment での設定例
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ccplant-backend
spec:
  template:
    spec:
      containers:
      - name: agentapi-proxy
        image: ghcr.io/takutakahashi/agentapi-proxy:latest
        ports:
        - containerPort: 8080
          name: http

        # Liveness Probe: コンテナが生きているか
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 30  # 起動後 30 秒待機
          periodSeconds: 10        # 10 秒ごとに確認
          timeoutSeconds: 5        # タイムアウト 5 秒
          failureThreshold: 3      # 3 回失敗で再起動
          successThreshold: 1      # 1 回成功で復帰

        # Readiness Probe: トラフィックを受け入れ可能か
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 10  # 起動後 10 秒待機
          periodSeconds: 5         # 5 秒ごとに確認
          timeoutSeconds: 3        # タイムアウト 3 秒
          failureThreshold: 3      # 3 回失敗で除外
          successThreshold: 1      # 1 回成功で追加
```

#### ヘルスチェックの確認

```bash
# ローカル環境
curl http://localhost:8080/health

# Kubernetes 環境
kubectl exec -it <pod-name> -- curl http://localhost:8080/health

# Service 経由
kubectl port-forward svc/ccplant-backend 8080:8080
curl http://localhost:8080/health
```

### Frontend ヘルスチェック

#### エンドポイント

```bash
# ヘルスチェックエンドポイント
GET http://localhost:3000/

# 期待されるレスポンス
HTTP/1.1 200 OK
Content-Type: text/html
```

#### Kubernetes での設定

```yaml
# Deployment での設定例
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ccplant-frontend
spec:
  template:
    spec:
      containers:
      - name: agentapi-ui
        image: ghcr.io/takutakahashi/agentapi-ui:latest
        ports:
        - containerPort: 3000
          name: http

        livenessProbe:
          httpGet:
            path: /
            port: 3000
            scheme: HTTP
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3

        readinessProbe:
          httpGet:
            path: /
            port: 3000
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
```

## OpenTelemetry Collector 統合

### 概要

OpenTelemetry Collector を使用して、メトリクス、ログ、トレースを統合的に収集します。

### OpenTelemetry Collector のデプロイ

```bash
# Helm リポジトリを追加
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# OpenTelemetry Collector をインストール
cat > otel-values.yaml <<EOF
mode: deployment

config:
  receivers:
    prometheus:
      config:
        scrape_configs:
          - job_name: 'ccplant-backend'
            scrape_interval: 15s
            static_configs:
              - targets: ['ccplant-backend:9464']
                labels:
                  app: 'ccplant'
                  component: 'backend'

          - job_name: 'ccplant-frontend'
            scrape_interval: 15s
            static_configs:
              - targets: ['ccplant-frontend:9090']
                labels:
                  app: 'ccplant'
                  component: 'frontend'

  processors:
    batch:
      timeout: 10s
      send_batch_size: 1024

    memory_limiter:
      check_interval: 1s
      limit_mib: 512

  exporters:
    prometheus:
      endpoint: "0.0.0.0:8889"

    logging:
      loglevel: info

  service:
    pipelines:
      metrics:
        receivers: [prometheus]
        processors: [memory_limiter, batch]
        exporters: [prometheus, logging]
EOF

helm install otel-collector open-telemetry/opentelemetry-collector \
  -f otel-values.yaml \
  --namespace ccplant
```

### アプリケーションの設定

```yaml
# Backend で OpenTelemetry を有効化
apiVersion: v1
kind: ConfigMap
metadata:
  name: ccplant-backend-config
data:
  OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector:4317"
  OTEL_SERVICE_NAME: "ccplant-backend"
  OTEL_METRICS_EXPORTER: "otlp"
  OTEL_LOGS_EXPORTER: "otlp"
```

## メトリクス収集

### Backend メトリクス (Port 9464)

#### メトリクスエンドポイント

```bash
# メトリクスを取得
curl http://localhost:9464/metrics

# 出力例
# TYPE http_requests_total counter
http_requests_total{method="GET",path="/health",status="200"} 1523

# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{method="GET",path="/health",le="0.005"} 1200
http_request_duration_seconds_bucket{method="GET",path="/health",le="0.01"} 1450
http_request_duration_seconds_sum{method="GET",path="/health"} 7.6
http_request_duration_seconds_count{method="GET",path="/health"} 1523

# TYPE process_cpu_seconds_total counter
process_cpu_seconds_total 45.32

# TYPE process_resident_memory_bytes gauge
process_resident_memory_bytes 134217728
```

#### 主要なメトリクス

| メトリクス | タイプ | 説明 |
|-----------|--------|------|
| `http_requests_total` | Counter | HTTP リクエスト総数 |
| `http_request_duration_seconds` | Histogram | リクエスト処理時間 |
| `process_cpu_seconds_total` | Counter | CPU 使用時間 |
| `process_resident_memory_bytes` | Gauge | メモリ使用量 |
| `active_sessions` | Gauge | アクティブセッション数 |

### Frontend メトリクス (Port 9090)

#### メトリクスエンドポイント

```bash
# メトリクスを取得
curl http://localhost:9090/metrics

# 出力例
# TYPE nodejs_heap_size_total_bytes gauge
nodejs_heap_size_total_bytes 134217728

# TYPE nodejs_heap_size_used_bytes gauge
nodejs_heap_size_used_bytes 89478485

# TYPE http_requests_total counter
http_requests_total{method="GET",path="/",status="200"} 2341
```

### Kubernetes メトリクス

```bash
# metrics-server をインストール
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Pod メトリクスを確認
kubectl top pods -n ccplant

# Node メトリクスを確認
kubectl top nodes
```

## Prometheus 統合

### Prometheus のインストール

```bash
# Prometheus Operator をインストール
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

cat > prometheus-values.yaml <<EOF
prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false

    # データ保持期間
    retention: 7d

    # ストレージ
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi

grafana:
  enabled: true
  adminPassword: admin
EOF

helm install prometheus prometheus-community/kube-prometheus-stack \
  -f prometheus-values.yaml \
  --namespace monitoring \
  --create-namespace
```

### ServiceMonitor の作成

```yaml
# Backend ServiceMonitor
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ccplant-backend
  namespace: ccplant
  labels:
    app: ccplant
    component: backend
spec:
  selector:
    matchLabels:
      app: ccplant
      component: backend
  endpoints:
  - port: metrics
    interval: 15s
    path: /metrics

---
# Frontend ServiceMonitor
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ccplant-frontend
  namespace: ccplant
  labels:
    app: ccplant
    component: frontend
spec:
  selector:
    matchLabels:
      app: ccplant
      component: frontend
  endpoints:
  - port: metrics
    interval: 15s
    path: /metrics
```

### Prometheus クエリの例

```promql
# HTTP リクエスト率 (1分間)
rate(http_requests_total[1m])

# P95 レスポンスタイム
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# エラー率
rate(http_requests_total{status=~"5.."}[1m]) / rate(http_requests_total[1m])

# CPU 使用率
rate(process_cpu_seconds_total[1m])

# メモリ使用率
process_resident_memory_bytes / 1024 / 1024
```

## ログ集約

### Loki のインストール

```bash
# Loki スタックをインストール
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

cat > loki-values.yaml <<EOF
loki:
  auth_enabled: false

  storage:
    type: filesystem

promtail:
  config:
    clients:
      - url: http://loki:3100/loki/api/v1/push

    snippets:
      scrapeConfigs: |
        - job_name: kubernetes-pods
          kubernetes_sd_configs:
            - role: pod
          relabel_configs:
            - source_labels: [__meta_kubernetes_namespace]
              target_label: namespace
            - source_labels: [__meta_kubernetes_pod_name]
              target_label: pod
            - source_labels: [__meta_kubernetes_pod_label_app]
              target_label: app
EOF

helm install loki grafana/loki-stack \
  -f loki-values.yaml \
  --namespace monitoring
```

### ログの確認

```bash
# kubectl でログ確認
kubectl logs -f -n ccplant -l app=ccplant

# Grafana Explore でクエリ
{namespace="ccplant", app="ccplant"}
{namespace="ccplant", component="backend"} |= "error"
{namespace="ccplant"} | json | level="error"
```

### ログレベル

| レベル | 説明 | 例 |
|--------|------|-----|
| DEBUG | デバッグ情報 | リクエストパラメータ |
| INFO | 通常の情報 | リクエスト処理完了 |
| WARN | 警告 | 非推奨 API の使用 |
| ERROR | エラー | リクエスト処理失敗 |

## アラート設定

### PrometheusRule の作成

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: ccplant-alerts
  namespace: ccplant
spec:
  groups:
  - name: ccplant
    interval: 30s
    rules:
    # Backend が停止
    - alert: BackendDown
      expr: up{job="ccplant-backend"} == 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "Backend is down"
        description: "Backend has been down for more than 1 minute"

    # エラー率が高い
    - alert: HighErrorRate
      expr: |
        rate(http_requests_total{status=~"5.."}[5m])
        / rate(http_requests_total[5m]) > 0.05
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value | humanizePercentage }}"

    # レスポンスタイムが遅い
    - alert: HighResponseTime
      expr: |
        histogram_quantile(0.95,
          rate(http_request_duration_seconds_bucket[5m])) > 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High response time"
        description: "P95 response time is {{ $value }}s"

    # メモリ使用率が高い
    - alert: HighMemoryUsage
      expr: |
        process_resident_memory_bytes / 1024 / 1024 / 1024 > 0.8
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage"
        description: "Memory usage is {{ $value }}GB"

    # Pod が再起動している
    - alert: PodRestarting
      expr: |
        rate(kube_pod_container_status_restarts_total
          {namespace="ccplant"}[15m]) > 0
      labels:
        severity: warning
      annotations:
        summary: "Pod is restarting"
        description: "Pod {{ $labels.pod }} is restarting"
```

### Alertmanager の設定

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      resolve_timeout: 5m

    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'slack'
      routes:
      - match:
          severity: critical
        receiver: 'slack-critical'

    receivers:
    - name: 'slack'
      slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#ccplant-alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

    - name: 'slack-critical'
      slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#ccplant-critical'
        title: '🚨 CRITICAL: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

## ダッシュボード

### Grafana ダッシュボードのインポート

```bash
# Grafana にアクセス
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# ブラウザで http://localhost:3000 にアクセス
# ユーザー名: admin
# パスワード: (prometheus-values.yaml で設定したもの)
```

### ccplant ダッシュボード JSON

```json
{
  "dashboard": {
    "title": "ccplant Overview",
    "panels": [
      {
        "title": "HTTP Requests Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total{namespace=\"ccplant\"}[5m])"
          }
        ]
      },
      {
        "title": "Response Time (P95)",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{namespace=\"ccplant\"}[5m]))"
          }
        ]
      },
      {
        "title": "Error Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total{namespace=\"ccplant\",status=~\"5..\"}[5m]) / rate(http_requests_total{namespace=\"ccplant\"}[5m])"
          }
        ]
      },
      {
        "title": "Active Sessions",
        "targets": [
          {
            "expr": "active_sessions{namespace=\"ccplant\"}"
          }
        ]
      }
    ]
  }
}
```

## トラブルシューティング

### メトリクスが収集されない

```bash
# ServiceMonitor の確認
kubectl get servicemonitor -n ccplant

# ServiceMonitor の詳細確認
kubectl describe servicemonitor ccplant-backend -n ccplant

# Prometheus が ServiceMonitor を検出しているか確認
kubectl logs -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 | grep servicemonitor

# メトリクスエンドポイントに直接アクセス
kubectl port-forward -n ccplant svc/ccplant-backend 9464:9464
curl http://localhost:9464/metrics
```

### アラートが発火しない

```bash
# PrometheusRule の確認
kubectl get prometheusrule -n ccplant

# Prometheus でルールを確認
# Grafana > Explore > Prometheus
# アラートクエリを手動で実行

# Alertmanager のログ確認
kubectl logs -n monitoring alertmanager-prometheus-kube-prometheus-alertmanager-0
```

### ログが表示されない

```bash
# Loki の状態確認
kubectl get pods -n monitoring | grep loki

# Promtail のログ確認
kubectl logs -n monitoring -l app=promtail

# Loki に直接クエリ
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={namespace="ccplant"}' | jq
```

## 参考リンク

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
