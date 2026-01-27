# 定期メンテナンス

ccplant プロジェクトの日常的なメンテナンスと運用管理の完全ガイドです。

## 目次

- [概要](#概要)
- [日次メンテナンス](#日次メンテナンス)
- [週次メンテナンス](#週次メンテナンス)
- [月次メンテナンス](#月次メンテナンス)
- [Helm Chart 更新](#helm-chart-更新)
- [依存関係の更新](#依存関係の更新)
- [ログローテーション](#ログローテーション)
- [証明書の更新](#証明書の更新)
- [クリーンアップ手順](#クリーンアップ手順)
- [パフォーマンスチューニング](#パフォーマンスチューニング)

## 概要

### メンテナンススケジュール

```
┌─────────────────────────────────────────────┐
│  メンテナンスサイクル                        │
│                                              │
│  毎日:                                       │
│  - ログ確認                                  │
│  - メトリクス確認                            │
│  - バックアップ確認                          │
│                                              │
│  毎週:                                       │
│  - セキュリティパッチ確認                    │
│  - リソース使用状況レビュー                  │
│  - アラート確認                              │
│                                              │
│  毎月:                                       │
│  - 依存関係の更新                            │
│  - パフォーマンスレビュー                    │
│  - キャパシティプランニング                  │
│                                              │
│  四半期:                                     │
│  - 災害復旧ドリル                            │
│  - セキュリティ監査                          │
│  - アーキテクチャレビュー                    │
└─────────────────────────────────────────────┘
```

### メンテナンスウィンドウ

```yaml
# 推奨メンテナンス時間帯
定期メンテナンス:
  曜日: 日曜日
  時間: 03:00 - 05:00 JST
  頻度: 毎週

緊急メンテナンス:
  即時実施可能

計画メンテナンス:
  事前通知: 7日前
  時間: 03:00 - 05:00 JST
```

## 日次メンテナンス

### ヘルスチェック

```bash
#!/bin/bash
# daily-health-check.sh

echo "=== Daily Health Check $(date) ==="

# 1. Pod の状態確認
echo "## Pod Status"
kubectl get pods -n ccplant

# 異常な Pod を検出
UNHEALTHY_PODS=$(kubectl get pods -n ccplant --field-selector=status.phase!=Running -o name)
if [ -n "$UNHEALTHY_PODS" ]; then
  echo "⚠️  Unhealthy pods detected:"
  echo "$UNHEALTHY_PODS"
fi

# 2. Service の状態確認
echo "## Service Status"
kubectl get svc -n ccplant

# 3. ヘルスエンドポイントの確認
echo "## Health Endpoints"
kubectl port-forward -n ccplant svc/ccplant-backend 8080:8080 &
PF_PID=$!
sleep 2

if curl -f http://localhost:8080/health > /dev/null 2>&1; then
  echo "✅ Backend health check passed"
else
  echo "❌ Backend health check failed"
fi

kill $PF_PID

# 4. リソース使用状況
echo "## Resource Usage"
kubectl top pods -n ccplant
kubectl top nodes

# 5. 最近のイベント
echo "## Recent Events"
kubectl get events -n ccplant --sort-by='.lastTimestamp' | tail -20

echo "=== Health Check Complete ==="
```

### ログ確認

```bash
#!/bin/bash
# daily-log-check.sh

echo "=== Daily Log Check $(date) ==="

# エラーログの確認
echo "## Error Logs (Last 24 hours)"
kubectl logs -n ccplant -l app=ccplant --since=24h | grep -i error | tail -50

# 警告ログの確認
echo "## Warning Logs (Last 24 hours)"
kubectl logs -n ccplant -l app=ccplant --since=24h | grep -i warn | tail -50

# 認証失敗の確認
echo "## Authentication Failures"
kubectl logs -n ccplant -l component=backend --since=24h | grep -i "authentication failed" | wc -l

# API エラー率
echo "## API Error Rate"
kubectl logs -n ccplant -l component=backend --since=24h | \
  grep -E "status=(4|5)[0-9]{2}" | wc -l

echo "=== Log Check Complete ==="
```

### バックアップ確認

```bash
#!/bin/bash
# daily-backup-check.sh

echo "=== Daily Backup Check $(date) ==="

# Velero バックアップの確認
echo "## Recent Backups"
velero backup get | head -10

# 最新のバックアップ状態
LATEST_BACKUP=$(velero backup get --output json | jq -r '.items[0].metadata.name')
echo "## Latest Backup: $LATEST_BACKUP"
velero backup describe $LATEST_BACKUP | grep -E "Phase|Expiration"

# バックアップの失敗を確認
FAILED_BACKUPS=$(velero backup get --output json | jq -r '.items[] | select(.status.phase == "Failed") | .metadata.name')
if [ -n "$FAILED_BACKUPS" ]; then
  echo "⚠️  Failed backups detected:"
  echo "$FAILED_BACKUPS"
fi

echo "=== Backup Check Complete ==="
```

### メトリクス確認

```bash
#!/bin/bash
# daily-metrics-check.sh

echo "=== Daily Metrics Check $(date) ==="

# Prometheus にクエリ
PROMETHEUS_URL="http://localhost:9090"

# HTTP リクエスト数
echo "## HTTP Request Count (24h)"
curl -s "${PROMETHEUS_URL}/api/v1/query?query=sum(increase(http_requests_total{namespace=\"ccplant\"}[24h]))" | \
  jq -r '.data.result[0].value[1]'

# エラー率
echo "## Error Rate (24h)"
curl -s "${PROMETHEUS_URL}/api/v1/query?query=sum(rate(http_requests_total{namespace=\"ccplant\",status=~\"5..\"}[24h]))/sum(rate(http_requests_total{namespace=\"ccplant\"}[24h]))" | \
  jq -r '.data.result[0].value[1]'

# P95 レスポンスタイム
echo "## P95 Response Time"
curl -s "${PROMETHEUS_URL}/api/v1/query?query=histogram_quantile(0.95,rate(http_request_duration_seconds_bucket{namespace=\"ccplant\"}[24h]))" | \
  jq -r '.data.result[0].value[1]'

echo "=== Metrics Check Complete ==="
```

## 週次メンテナンス

### セキュリティパッチ確認

```bash
#!/bin/bash
# weekly-security-check.sh

echo "=== Weekly Security Check $(date) ==="

# 1. イメージの脆弱性スキャン
echo "## Vulnerability Scan"
trivy image --severity HIGH,CRITICAL \
  ghcr.io/takutakahashi/agentapi-proxy:latest

trivy image --severity HIGH,CRITICAL \
  ghcr.io/takutakahashi/agentapi-ui:latest

# 2. Kubernetes クラスターのスキャン
echo "## Kubernetes Security Scan"
trivy k8s --report summary cluster

# 3. Secret の有効期限確認
echo "## Certificate Expiration"
kubectl get certificate -n ccplant -o json | \
  jq -r '.items[] | "\(.metadata.name): \(.status.notAfter)"'

# 4. 未使用のリソース確認
echo "## Unused Resources"
kubectl get secrets -n ccplant --sort-by='.metadata.creationTimestamp'
kubectl get configmaps -n ccplant --sort-by='.metadata.creationTimestamp'

echo "=== Security Check Complete ==="
```

### リソース使用状況レビュー

```bash
#!/bin/bash
# weekly-resource-review.sh

echo "=== Weekly Resource Review $(date) ==="

# 1. CPU 使用率 (過去7日間)
echo "## CPU Usage Trends"
kubectl top pods -n ccplant --sort-by=cpu

# 2. メモリ使用率
echo "## Memory Usage Trends"
kubectl top pods -n ccplant --sort-by=memory

# 3. ディスク使用率
echo "## Disk Usage"
kubectl get pvc -n ccplant

# 4. ネットワークトラフィック
echo "## Network Metrics"
kubectl exec -n ccplant -it <pod-name> -- \
  cat /proc/net/dev | grep eth0

# 5. リソース推奨値の計算
echo "## Resource Recommendations"
kubectl describe nodes | grep -A 5 "Allocated resources"

echo "=== Resource Review Complete ==="
```

### アラート確認

```bash
#!/bin/bash
# weekly-alert-review.sh

echo "=== Weekly Alert Review $(date) ==="

# 1. 発火したアラートの確認
echo "## Fired Alerts (Last 7 days)"
kubectl logs -n monitoring alertmanager-<pod-name> --since=168h | \
  grep -E "alert=.*state=firing"

# 2. アラートの頻度分析
echo "## Alert Frequency"
kubectl logs -n monitoring alertmanager-<pod-name> --since=168h | \
  grep "alert=" | awk '{print $3}' | sort | uniq -c | sort -nr

# 3. False Positive の特定
echo "## Potential False Positives"
# 短時間で解決されたアラート
kubectl logs -n monitoring alertmanager-<pod-name> --since=168h | \
  grep -E "state=firing.*state=resolved" | head -10

echo "=== Alert Review Complete ==="
```

## 月次メンテナンス

### 依存関係の更新

#### Helm Chart 依存関係

```bash
#!/bin/bash
# monthly-helm-update.sh

echo "=== Monthly Helm Update $(date) ==="

cd charts/ccplant

# 1. 現在のバージョンを確認
echo "## Current Versions"
helm dependency list

# 2. 利用可能な更新を確認
echo "## Available Updates"
echo "Checking agentapi-proxy..."
helm search repo oci://ghcr.io/takutakahashi/charts/agentapi-proxy --versions | head -5

echo "Checking agentapi-ui..."
helm search repo oci://ghcr.io/takutakahashi/charts/agentapi-ui --versions | head -5

# 3. Chart.yaml を更新
echo "## Updating Chart.yaml"
# 手動または自動で Chart.yaml を更新

# 4. 依存関係を更新
helm dependency update

# 5. テンプレートを検証
helm template ccplant . > /tmp/updated-template.yaml
helm lint .

# 6. 差分を確認
diff -u testdata/expected.yaml /tmp/updated-template.yaml

echo "=== Helm Update Complete ==="
```

### パフォーマンスレビュー

```bash
#!/bin/bash
# monthly-performance-review.sh

echo "=== Monthly Performance Review $(date) ==="

# 1. レスポンスタイムのトレンド
echo "## Response Time Trends (30 days)"
# Prometheus でクエリ
curl -s "http://prometheus:9090/api/v1/query_range" \
  --data-urlencode 'query=histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{namespace="ccplant"}[5m]))' \
  --data-urlencode "start=$(date -d '30 days ago' +%s)" \
  --data-urlencode "end=$(date +%s)" \
  --data-urlencode "step=3600" | jq

# 2. エラー率のトレンド
echo "## Error Rate Trends (30 days)"
curl -s "http://prometheus:9090/api/v1/query_range" \
  --data-urlencode 'query=rate(http_requests_total{namespace="ccplant",status=~"5.."}[5m])/rate(http_requests_total{namespace="ccplant"}[5m])' \
  --data-urlencode "start=$(date -d '30 days ago' +%s)" \
  --data-urlencode "end=$(date +%s)" \
  --data-urlencode "step=3600" | jq

# 3. スループット
echo "## Throughput (30 days)"
curl -s "http://prometheus:9090/api/v1/query_range" \
  --data-urlencode 'query=rate(http_requests_total{namespace="ccplant"}[5m])' \
  --data-urlencode "start=$(date -d '30 days ago' +%s)" \
  --data-urlencode "end=$(date +%s)" \
  --data-urlencode "step=3600" | jq

echo "=== Performance Review Complete ==="
```

### キャパシティプランニング

```bash
#!/bin/bash
# monthly-capacity-planning.sh

echo "=== Monthly Capacity Planning $(date) ==="

# 1. リソース使用率の傾向
echo "## Resource Utilization Trends"
kubectl top pods -n ccplant --sort-by=cpu
kubectl top pods -n ccplant --sort-by=memory

# 2. ストレージ使用率
echo "## Storage Usage"
kubectl get pvc -n ccplant -o json | \
  jq -r '.items[] | "\(.metadata.name): \(.status.capacity.storage)"'

# 3. ノードキャパシティ
echo "## Node Capacity"
kubectl describe nodes | grep -A 5 "Capacity:"

# 4. スケーリング推奨
echo "## Scaling Recommendations"
# CPU 使用率が80%を超える場合
HIGH_CPU_PODS=$(kubectl top pods -n ccplant --no-headers | \
  awk '{if ($2 ~ /m/) {cpu = $2; gsub(/m/, "", cpu); if (cpu > 400) print $1}}')

if [ -n "$HIGH_CPU_PODS" ]; then
  echo "⚠️  Consider scaling up these pods:"
  echo "$HIGH_CPU_PODS"
fi

echo "=== Capacity Planning Complete ==="
```

## Helm Chart 更新

### 更新プロセス

```bash
# 1. 現在のバージョンを確認
helm list -n ccplant

# 2. 新しいバージョンを確認
helm search repo oci://ghcr.io/takutakahashi/charts/ccplant --versions

# 3. 変更履歴を確認
helm show readme oci://ghcr.io/takutakahashi/charts/ccplant --version 0.2.0

# 4. values.yaml のバックアップ
kubectl get configmap ccplant-values -n ccplant -o yaml > values-backup.yaml

# 5. ドライラン
helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version 0.2.0 \
  --namespace ccplant \
  --dry-run

# 6. アップグレード実行
helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version 0.2.0 \
  --namespace ccplant \
  --wait \
  --timeout 10m

# 7. ロールアウト状況を確認
kubectl rollout status deployment/ccplant-backend -n ccplant
kubectl rollout status deployment/ccplant-frontend -n ccplant

# 8. 動作確認
curl https://ccplant.example.com/health

# 9. ロールバック (問題がある場合)
helm rollback ccplant -n ccplant
```

### 自動更新 (Renovate)

```json
// renovate.json
{
  "extends": ["config:base"],
  "helm-values": {
    "fileMatch": ["charts/.*/values\\.yaml$"]
  },
  "packageRules": [
    {
      "matchDatasources": ["helm"],
      "matchUpdateTypes": ["minor", "patch"],
      "automerge": true,
      "automergeType": "pr"
    },
    {
      "matchDatasources": ["helm"],
      "matchUpdateTypes": ["major"],
      "automerge": false
    }
  ],
  "schedule": ["every weekend"]
}
```

## 依存関係の更新

### Backend 依存関係

```bash
# agentapi-proxy の最新バージョンを確認
gh api repos/takutakahashi/agentapi-proxy/releases/latest

# Chart.yaml を更新
vim charts/ccplant/Chart.yaml

# dependencies:
#   - name: agentapi-proxy
#     version: "v1.192.0"  # 更新
#     repository: "oci://ghcr.io/takutakahashi/charts"

# 依存関係を更新
cd charts/ccplant
helm dependency update
```

### Frontend 依存関係

```bash
# agentapi-ui の最新バージョンを確認
gh api repos/takutakahashi/agentapi-ui/releases/latest

# Chart.yaml を更新
vim charts/ccplant/Chart.yaml

# dependencies:
#   - name: agentapi-ui
#     version: "v1.98.0"  # 更新
#     repository: "oci://ghcr.io/takutakahashi/charts"

# 依存関係を更新
cd charts/ccplant
helm dependency update
```

## ログローテーション

### Kubernetes ログローテーション

```yaml
# DaemonSet でログローテーションを設定
apiVersion: v1
kind: ConfigMap
metadata:
  name: logrotate-config
  namespace: kube-system
data:
  logrotate.conf: |
    /var/log/containers/*.log {
      daily
      rotate 7
      compress
      missingok
      notifempty
      dateext
      dateformat -%Y%m%d-%s
      create 0644 root root
    }
```

### アプリケーションログのクリーンアップ

```bash
#!/bin/bash
# log-cleanup.sh

# 7日以上前のログファイルを削除
find /var/log/ccplant -name "*.log" -mtime +7 -delete

# 圧縮されたログファイルは30日間保持
find /var/log/ccplant -name "*.log.gz" -mtime +30 -delete

# ログディレクトリのサイズ確認
du -sh /var/log/ccplant
```

## 証明書の更新

### TLS 証明書の確認

```bash
# 証明書の有効期限を確認
kubectl get certificate -n ccplant

# 詳細確認
kubectl describe certificate ccplant-frontend-tls -n ccplant

# 証明書の内容を確認
kubectl get secret ccplant-frontend-tls -n ccplant -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -noout -text
```

### 証明書の手動更新

```bash
# cert-manager が自動更新する前に手動更新
kubectl delete certificate ccplant-frontend-tls -n ccplant
kubectl delete certificate ccplant-backend-tls -n ccplant

# 証明書が再作成されるのを待つ
kubectl wait --for=condition=ready certificate/ccplant-frontend-tls -n ccplant --timeout=300s
kubectl wait --for=condition=ready certificate/ccplant-backend-tls -n ccplant --timeout=300s

# 確認
kubectl get certificate -n ccplant
```

### cert-manager のトラブルシューティング

```bash
# cert-manager のログ確認
kubectl logs -n cert-manager -l app=cert-manager

# CertificateRequest の確認
kubectl get certificaterequest -n ccplant

# Order と Challenge の確認
kubectl get order -n ccplant
kubectl get challenge -n ccplant

# Challenge の詳細
kubectl describe challenge -n ccplant
```

## クリーンアップ手順

### 不要なリソースのクリーンアップ

```bash
#!/bin/bash
# cleanup.sh

echo "=== Cleanup $(date) ==="

# 1. 完了した Job を削除
kubectl delete job -n ccplant --field-selector status.successful=1

# 2. 古い ReplicaSet を削除 (最新5つを保持)
kubectl get replicaset -n ccplant --sort-by=.metadata.creationTimestamp | \
  head -n -5 | awk '{print $1}' | xargs -r kubectl delete replicaset -n ccplant

# 3. Evicted な Pod を削除
kubectl delete pod -n ccplant --field-selector status.phase=Failed

# 4. 未使用の ConfigMap を削除 (作成から30日以上)
kubectl get configmap -n ccplant -o json | \
  jq -r ".items[] | select(.metadata.creationTimestamp < \"$(date -d '30 days ago' -Iseconds)\") | .metadata.name" | \
  xargs -r kubectl delete configmap -n ccplant

# 5. Docker イメージのクリーンアップ (各ノードで実行)
for node in $(kubectl get nodes -o name); do
  kubectl debug $node -it --image=alpine -- sh -c "docker image prune -a --filter \"until=168h\" -f"
done

echo "=== Cleanup Complete ==="
```

### ストレージのクリーンアップ

```bash
# 未使用の PVC を確認
kubectl get pvc -n ccplant -o json | \
  jq -r '.items[] | select(.status.phase == "Bound") | select(.spec.volumeName == null) | .metadata.name'

# 古いスナップショットを削除
kubectl get volumesnapshot -n ccplant --sort-by=.metadata.creationTimestamp | \
  head -n -10 | awk '{print $1}' | xargs -r kubectl delete volumesnapshot -n ccplant
```

## パフォーマンスチューニング

### Backend チューニング

```yaml
# Deployment リソース制限の最適化
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ccplant-backend
spec:
  template:
    spec:
      containers:
      - name: agentapi-proxy
        resources:
          requests:
            cpu: 200m      # 100m → 200m
            memory: 256Mi  # 128Mi → 256Mi
          limits:
            cpu: 1000m     # 500m → 1000m
            memory: 1Gi    # 512Mi → 1Gi

        # JVM ヒープサイズの設定 (該当する場合)
        env:
        - name: JAVA_OPTS
          value: "-Xms256m -Xmx768m"
```

### Frontend チューニング

```yaml
# Deployment リソース制限の最適化
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ccplant-frontend
spec:
  template:
    spec:
      containers:
      - name: agentapi-ui
        resources:
          requests:
            cpu: 100m      # 50m → 100m
            memory: 128Mi  # 64Mi → 128Mi
          limits:
            cpu: 500m      # 200m → 500m
            memory: 512Mi  # 256Mi → 512Mi

        # Node.js メモリ制限
        env:
        - name: NODE_OPTIONS
          value: "--max-old-space-size=384"
```

### HPA チューニング

```yaml
# HorizontalPodAutoscaler の最適化
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ccplant-backend-hpa
  namespace: ccplant
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ccplant-backend
  minReplicas: 3        # 2 → 3 (高可用性)
  maxReplicas: 20       # 10 → 20 (スケーラビリティ)
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60  # 70 → 60 (余裕を持たせる)
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70  # 80 → 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # 急激なスケールダウンを防ぐ
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0    # 迅速なスケールアップ
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
```

## ベストプラクティス

### 1. メンテナンス記録

```markdown
# メンテナンス記録テンプレート

## 日付: 2024-01-27
## 担当者: Admin

### 実施内容
- Helm チャートを v0.1.0 から v0.2.0 に更新
- Backend のリソース制限を調整
- 古い ReplicaSet を削除

### 結果
- アップグレード成功
- ダウンタイムなし
- パフォーマンス改善 (レスポンスタイム -20%)

### 問題点
- なし

### 次回のアクション
- Frontend のスケーリング設定を見直す
```

### 2. チェックリストの活用

```markdown
# 月次メンテナンスチェックリスト

## セキュリティ
- [ ] 脆弱性スキャン実施
- [ ] セキュリティパッチ適用
- [ ] 証明書有効期限確認
- [ ] Secret ローテーション確認

## パフォーマンス
- [ ] メトリクス確認
- [ ] ログ分析
- [ ] リソース使用状況確認
- [ ] キャパシティプランニング

## 依存関係
- [ ] Helm Chart 更新
- [ ] Backend 更新
- [ ] Frontend 更新
- [ ] 依存ライブラリ更新

## バックアップ
- [ ] バックアップ状態確認
- [ ] リストアテスト実施
- [ ] バックアップ保持期間確認
```

### 3. 自動化

```yaml
# CronJob でメンテナンスタスクを自動化
apiVersion: batch/v1
kind: CronJob
metadata:
  name: daily-maintenance
  namespace: ccplant
spec:
  schedule: "0 3 * * *"  # 毎日午前3時
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: maintenance
            image: bitnami/kubectl:latest
            command:
            - /bin/bash
            - -c
            - |
              # ヘルスチェック
              /scripts/daily-health-check.sh

              # ログ確認
              /scripts/daily-log-check.sh

              # メトリクス確認
              /scripts/daily-metrics-check.sh

              # クリーンアップ
              /scripts/cleanup.sh
          restartPolicy: OnFailure
```

## 参考リンク

- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Production Best Practices](https://kubernetes.io/docs/setup/best-practices/)
