# Kubernetes セッション管理

## 概要

agentapi-proxy は Kubernetes ネイティブなセッション管理を実装しており、ユーザーリクエストごとに動的に Pod を作成・管理します。各セッションは独立した Kubernetes Pod として実行され、完全な分離とリソース制御を実現します。

## セッション Pod のライフサイクル

### 1. セッション作成

```
ユーザーリクエスト
    │
    ▼
┌─────────────────────────────────────────────┐
│ 1. リクエスト検証                              │
│    - 認証・認可チェック                         │
│    - リソースクォータチェック                    │
│    - パラメータバリデーション                    │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│ 2. Secret 作成                               │
│    - MCP servers 設定                        │
│    - GitHub 認証情報                          │
│    - セッション固有の環境変数                   │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│ 3. ConfigMap 作成                            │
│    - セッション設定                            │
│    - カスタム設定ファイル                       │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│ 4. PVC 作成 (オプション)                       │
│    - ワークスペース永続化                       │
│    - ユーザーデータ保存                         │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│ 5. Pod 作成                                  │
│    - メインコンテナ: claude-code              │
│    - サイドカー: otel-collector              │
│    - サイドカー: credentials-sync            │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│ 6. Service 作成                              │
│    - セッション Pod へのネットワークアクセス     │
│    - ClusterIP Service                       │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│ 7. Pod Ready 待機                            │
│    - 最大 120 秒待機 (設定可能)               │
│    - コンテナ起動確認                          │
│    - Readiness Probe チェック                │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│ 8. セッション情報返却                          │
│    - Session ID                             │
│    - Connection URL                         │
│    - Status: running                        │
└─────────────────────────────────────────────┘
```

### 2. セッション実行

セッション Pod が起動すると、以下のプロセスが実行されます:

```yaml
# セッション Pod の構成例
apiVersion: v1
kind: Pod
metadata:
  name: session-user123-abc123
  namespace: default
  labels:
    app: agentapi-session
    user: user123
    session-id: abc123
spec:
  serviceAccountName: agentapi-proxy-session
  securityContext:
    fsGroup: 999
    runAsUser: 999
    runAsGroup: 999

  # メインコンテナ: Claude Code
  containers:
    - name: claude-code
      image: ghcr.io/takutakahashi/agentapi-proxy:v1.191.0
      ports:
        - containerPort: 9000
          name: agentapi
      resources:
        requests:
          cpu: 500m
          memory: 512Mi
        limits:
          cpu: 2
          memory: 4Gi
      env:
        - name: HOME
          value: /home/agentapi
        - name: GITHUB_TOKEN
          valueFrom:
            secretKeyRef:
              name: session-user123-abc123-creds
              key: github-token
      volumeMounts:
        - name: workspace
          mountPath: /home/agentapi/.claude
        - name: mcp-servers
          mountPath: /home/agentapi/.config/mcp-servers
          subPath: mcp-servers.json

    # サイドカー: OpenTelemetry Collector
    - name: otel-collector
      image: otel/opentelemetry-collector-contrib:0.143.1
      ports:
        - containerPort: 9464
          name: metrics
        - containerPort: 9090
          name: export
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 200m
          memory: 256Mi

    # サイドカー: Credentials Sync
    - name: credentials-sync
      image: ghcr.io/takutakahashi/agentapi-proxy:v1.191.0
      command: ["/bin/credentials-sync"]
      env:
        - name: WATCH_FILE
          value: /home/agentapi/.claude/credentials.json
        - name: SECRET_NAME
          value: session-user123-abc123-creds
        - name: SECRET_NAMESPACE
          value: default
      volumeMounts:
        - name: workspace
          mountPath: /home/agentapi/.claude

  volumes:
    - name: workspace
      persistentVolumeClaim:
        claimName: session-user123-abc123-pvc
    - name: mcp-servers
      secret:
        secretName: session-user123-abc123-mcp
```

### 3. セッション監視

スケジュールワーカーが定期的に (デフォルト 30 秒間隔) セッションの状態を監視します:

```go
type SessionMonitor struct {
    checkInterval time.Duration
}

func (m *SessionMonitor) Run(ctx context.Context) {
    ticker := time.NewTicker(m.checkInterval)
    defer ticker.Stop()

    for {
        select {
        case <-ticker.C:
            m.checkSessions(ctx)
        case <-ctx.Done():
            return
        }
    }
}

func (m *SessionMonitor) checkSessions(ctx context.Context) {
    sessions, _ := m.listAllSessions(ctx)

    for _, session := range sessions {
        // 1. タイムアウトチェック
        if m.isTimedOut(session) {
            m.terminateSession(ctx, session)
            continue
        }

        // 2. Pod 状態チェック
        pod, _ := m.getPod(ctx, session.PodName)
        if pod.Status.Phase == v1.PodFailed {
            m.handleFailedPod(ctx, session, pod)
            continue
        }

        // 3. リソース使用率チェック
        metrics := m.getMetrics(ctx, session)
        m.updateSessionMetrics(ctx, session, metrics)
    }
}
```

### 4. セッション削除

```
削除リクエスト
    │
    ▼
┌─────────────────────────────────────────────┐
│ 1. 権限チェック                               │
│    - セッション所有者確認                       │
│    - または session:delete 権限確認           │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│ 2. Graceful Shutdown 通知                    │
│    - Pod に SIGTERM 送信                     │
│    - 保存処理の完了を待機                      │
│    - タイムアウト: 30 秒 (設定可能)            │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│ 3. リソース削除                               │
│    - Pod 削除                                │
│    - Service 削除                            │
│    - ConfigMap 削除                          │
│    - Secret 削除                             │
│    - PVC 削除 (設定による)                    │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│ 4. メタデータ更新                             │
│    - Status: terminated                     │
│    - 終了時刻記録                             │
│    - 監査ログ記録                             │
└─────────────────────────────────────────────┘
```

---

## リソース管理

### CPU とメモリ

#### デフォルト設定

```yaml
# セッション Pod
claude-code:
  requests:
    cpu: 500m        # 0.5 コア保証
    memory: 512Mi    # 512 MB 保証
  limits:
    cpu: 2           # 最大 2 コア
    memory: 4Gi      # 最大 4 GB

otel-collector:
  requests:
    cpu: 100m        # 0.1 コア保証
    memory: 128Mi    # 128 MB 保証
  limits:
    cpu: 200m        # 最大 0.2 コア
    memory: 256Mi    # 最大 256 MB
```

#### カスタマイズ

**環境変数による設定**
```yaml
# agentapi-proxy Deployment
env:
  - name: AGENTAPI_K8S_SESSION_CPU_REQUEST
    value: "1"
  - name: AGENTAPI_K8S_SESSION_CPU_LIMIT
    value: "4"
  - name: AGENTAPI_K8S_SESSION_MEMORY_REQUEST
    value: "1Gi"
  - name: AGENTAPI_K8S_SESSION_MEMORY_LIMIT
    value: "8Gi"
```

**Helm による設定**
```yaml
# values.yaml
agentapi-proxy:
  kubernetesSession:
    resources:
      claude-code:
        requests:
          cpu: 1
          memory: 1Gi
        limits:
          cpu: 4
          memory: 8Gi
      otel-collector:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 200m
          memory: 256Mi
```

**API リクエストによる動的設定**
```json
POST /api/v1/sessions
{
  "config": {
    "cpu_limit": "4",
    "memory_limit": "8Gi"
  }
}
```

### ストレージ (PVC)

#### PVC の有効化

```yaml
# agentapi-proxy 設定
env:
  - name: AGENTAPI_K8S_SESSION_PVC_ENABLED
    value: "true"
  - name: AGENTAPI_K8S_SESSION_PVC_STORAGE_CLASS
    value: "fast-ssd"
  - name: AGENTAPI_K8S_SESSION_PVC_STORAGE_SIZE
    value: "20Gi"
```

#### Helm による設定

```yaml
# values.yaml
agentapi-proxy:
  kubernetesSession:
    pvc:
      enabled: true
      storageClass: fast-ssd
      storageSize: 20Gi
      # 削除ポリシー
      reclaimPolicy: Delete  # または Retain
```

#### PVC の構造

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: session-user123-abc123-pvc
  namespace: default
  labels:
    app: agentapi-session
    user: user123
    session-id: abc123
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 20Gi
```

#### PVC ライフサイクル

```
セッション作成時
    │
    ▼
┌─────────────────────────────────────────────┐
│ PVC 作成                                     │
│ - 動的プロビジョニング                          │
│ - ストレージクラスに基づいて PV 自動作成         │
└─────────────────────────────────────────────┘
    │
    ▼
セッション実行中
    │
    - ユーザーデータ保存
    - ワークスペース永続化
    │
    ▼
セッション削除時
    │
    ▼
┌─────────────────────────────────────────────┐
│ PVC 削除ポリシー適用                          │
│ - Delete: PVC と PV を削除                   │
│ - Retain: PVC を保持 (手動クリーンアップ)      │
└─────────────────────────────────────────────┘
```

#### データ保持設定

**セッション削除時に PVC を保持**
```yaml
# セッション削除時の動作を制御
DELETE /api/v1/sessions/{session_id}?delete_pvc=false
```

**PVC の再利用**
```json
POST /api/v1/sessions
{
  "config": {
    "pvc_name": "session-user123-abc123-pvc",  // 既存の PVC を再利用
    "pvc_enabled": true
  }
}
```

---

## ネットワーク構成

### Service によるアクセス

各セッション Pod には専用の ClusterIP Service が作成されます:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: session-user123-abc123
  namespace: default
  labels:
    app: agentapi-session
    user: user123
    session-id: abc123
spec:
  type: ClusterIP
  selector:
    app: agentapi-session
    session-id: abc123
  ports:
    - name: agentapi
      port: 9000
      targetPort: 9000
      protocol: TCP
    - name: metrics
      port: 9090
      targetPort: 9090
      protocol: TCP
```

### 接続フロー

```
ユーザー
    │
    ▼
┌─────────────────────────────────────────────┐
│ Ingress (HTTPS)                             │
│ cc-api.example.com                          │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│ agentapi-proxy Service                      │
│ Port 8080                                   │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│ agentapi-proxy Pod                          │
│ - WebSocket/SSE 接続受付                     │
│ - セッション ID 抽出                          │
│ - 認証・認可チェック                           │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│ Session Service                             │
│ session-user123-abc123:9000                 │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│ Session Pod                                 │
│ claude-code container (Port 9000)           │
└─────────────────────────────────────────────┘
```

### NetworkPolicy (オプション)

セッション間の通信を制限する NetworkPolicy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: session-isolation
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: agentapi-session
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # agentapi-proxy からのアクセスのみ許可
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: agentapi-proxy
      ports:
        - protocol: TCP
          port: 9000
  egress:
    # 外部 API アクセスを許可
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 443
        - protocol: TCP
          port: 80
    # DNS アクセスを許可
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
```

---

## セキュリティ設定

### SecurityContext

#### Pod レベル

```yaml
securityContext:
  # 非 root ユーザーで実行
  runAsUser: 999
  runAsGroup: 999
  fsGroup: 999

  # 特権昇格を防止
  runAsNonRoot: true

  # セキュアなファイルシステム
  fsGroupChangePolicy: "OnRootMismatch"
```

#### コンテナレベル

```yaml
securityContext:
  # ルートファイルシステムを読み取り専用に
  readOnlyRootFilesystem: true

  # 特権コンテナを防止
  privileged: false

  # 不要な Linux Capabilities を削除
  capabilities:
    drop:
      - ALL
    add:
      - NET_BIND_SERVICE  # 必要な場合のみ

  # seccomp プロファイル適用
  seccompProfile:
    type: RuntimeDefault

  # AppArmor プロファイル適用 (オプション)
  appArmorProfile:
    type: RuntimeDefault
```

### Secret 管理

#### MCP Servers Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: session-user123-abc123-mcp
  namespace: default
type: Opaque
stringData:
  mcp-servers.json: |
    {
      "github": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-github"],
        "env": {
          "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_xxxxx"
        }
      },
      "postgres": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-postgres"],
        "env": {
          "DATABASE_URL": "postgresql://user:pass@host/db"
        }
      }
    }
```

#### Credentials Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: session-user123-abc123-creds
  namespace: default
type: Opaque
stringData:
  github-token: "ghp_xxxxx"
  credentials.json: |
    {
      "github": {
        "token": "ghp_xxxxx",
        "username": "takutakahashi"
      }
    }
```

---

## Pod 配置制御

### NodeSelector

特定のノードでセッション Pod を実行:

```yaml
# agentapi-proxy 設定
env:
  - name: AGENTAPI_K8S_SESSION_NODE_SELECTOR
    value: '{"workload-type":"agentapi-sessions"}'
```

```yaml
# Helm 設定
agentapi-proxy:
  kubernetesSession:
    nodeSelector:
      workload-type: agentapi-sessions
      instance-type: c5.2xlarge
```

**ノードにラベルを付与**
```bash
kubectl label nodes node-1 workload-type=agentapi-sessions
kubectl label nodes node-1 instance-type=c5.2xlarge
```

### Tolerations

Taint のあるノードでセッション Pod を実行:

```yaml
# Helm 設定
agentapi-proxy:
  kubernetesSession:
    tolerations:
      - key: "dedicated"
        operator: "Equal"
        value: "agentapi-sessions"
        effect: "NoSchedule"
      - key: "gpu"
        operator: "Exists"
        effect: "NoSchedule"
```

**ノードに Taint を付与**
```bash
kubectl taint nodes node-1 dedicated=agentapi-sessions:NoSchedule
```

### Affinity (詳細な配置制御)

```yaml
# セッション Pod の Affinity 設定
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: workload-type
              operator: In
              values:
                - agentapi-sessions
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
            - key: instance-type
              operator: In
              values:
                - c5.2xlarge
                - c5.4xlarge

  podAntiAffinity:
    # 同一ユーザーのセッションを異なるノードに配置
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: user
                operator: In
                values:
                  - user123
          topologyKey: kubernetes.io/hostname
```

---

## 監視とメトリクス

### OpenTelemetry Collector

各セッション Pod の otel-collector サイドカーが以下を収集:

#### メトリクス

```yaml
# Prometheus メトリクスのスクレイピング設定
receivers:
  prometheus:
    config:
      scrape_configs:
        - job_name: 'claude-code'
          scrape_interval: 15s
          static_configs:
            - targets: ['localhost:9464']

exporters:
  prometheus:
    endpoint: "0.0.0.0:9090"
  otlphttp:
    endpoint: "http://tempo.monitoring:4318"

service:
  pipelines:
    metrics:
      receivers: [prometheus]
      exporters: [prometheus, otlphttp]
```

#### 収集されるメトリクス例

```
# Claude Code メトリクス
claude_code_requests_total{method="GET",status="200"} 42
claude_code_request_duration_seconds{method="POST",quantile="0.95"} 1.23
claude_code_active_sessions 5
claude_code_tokens_used_total 15000

# リソースメトリクス
container_cpu_usage_seconds_total 123.45
container_memory_usage_bytes 1073741824
container_network_receive_bytes_total 10485760
container_network_transmit_bytes_total 5242880
```

### ログ収集

#### セッション Pod ログ

```bash
# すべてのコンテナログを取得
kubectl logs session-user123-abc123 --all-containers

# 特定のコンテナログを取得
kubectl logs session-user123-abc123 -c claude-code
kubectl logs session-user123-abc123 -c otel-collector
kubectl logs session-user123-abc123 -c credentials-sync

# リアルタイムログ監視
kubectl logs -f session-user123-abc123 -c claude-code
```

#### ログフォーマット (JSON)

```json
{
  "timestamp": "2024-01-27T12:00:00Z",
  "level": "info",
  "logger": "claude-code",
  "session_id": "abc123",
  "user": "user123",
  "message": "Request processed",
  "request_id": "req-123",
  "duration_ms": 123,
  "status": 200
}
```

---

## トラブルシューティング

### Pod 起動失敗

#### 症状
```
Session status: pending
Pod phase: Pending
```

#### 診断

```bash
# Pod イベントを確認
kubectl describe pod session-user123-abc123

# よくある原因:
# - ImagePullBackOff: イメージが取得できない
# - Pending: リソース不足、NodeSelector/Tolerations の不一致
# - CrashLoopBackOff: コンテナが起動直後にクラッシュ
```

#### 対処

1. **イメージの確認**
   ```bash
   # イメージが存在するか確認
   docker pull ghcr.io/takutakahashi/agentapi-proxy:v1.191.0
   ```

2. **リソース確認**
   ```bash
   # ノードのリソースを確認
   kubectl top nodes
   kubectl describe nodes
   ```

3. **Secret/ConfigMap の確認**
   ```bash
   # Secret が存在するか確認
   kubectl get secret session-user123-abc123-mcp
   kubectl get secret session-user123-abc123-creds
   ```

### Pod タイムアウト

#### 症状
```json
{
  "error": {
    "code": "POD_START_TIMEOUT",
    "message": "Pod failed to become ready within 120 seconds"
  }
}
```

#### 対処

```yaml
# タイムアウトを延長
env:
  - name: AGENTAPI_K8S_SESSION_POD_START_TIMEOUT
    value: "300"  # 5 分に延長
```

### PVC マウント失敗

#### 症状
```
Pod status: ContainerCreating
Event: FailedMount: MountVolume.SetUp failed
```

#### 診断

```bash
# PVC の状態を確認
kubectl get pvc session-user123-abc123-pvc
kubectl describe pvc session-user123-abc123-pvc

# StorageClass を確認
kubectl get storageclass
```

#### 対処

1. **StorageClass の確認**
   ```bash
   # デフォルト StorageClass を確認
   kubectl get storageclass -o wide
   ```

2. **PV のプロビジョニング確認**
   ```bash
   # PV が作成されているか確認
   kubectl get pv
   ```

### OOM (Out Of Memory)

#### 症状
```
Pod status: Failed
Reason: OOMKilled
```

#### 診断

```bash
# Pod のメモリ使用量を確認
kubectl top pod session-user123-abc123

# Pod イベントを確認
kubectl describe pod session-user123-abc123
```

#### 対処

```yaml
# メモリ制限を増やす
env:
  - name: AGENTAPI_K8S_SESSION_MEMORY_LIMIT
    value: "8Gi"  # 4Gi → 8Gi
```

---

## ベストプラクティス

### 1. リソース管理

```yaml
# リソースリクエストは実際の使用量に基づいて設定
# リソースリミットは過負荷時の上限として設定
resources:
  requests:
    cpu: "1"        # 保証される最小リソース
    memory: "1Gi"
  limits:
    cpu: "4"        # 最大使用可能リソース
    memory: "8Gi"
```

### 2. PVC の使用

```yaml
# 長時間セッションや重要なデータを扱う場合は PVC を有効化
pvc:
  enabled: true
  storageSize: "20Gi"

# 短時間セッションや一時的な作業の場合は無効化してコスト削減
pvc:
  enabled: false
```

### 3. セッションタイムアウト

```json
// 自動タイムアウトを設定して孤立セッションを防止
POST /api/v1/sessions
{
  "config": {
    "timeout_minutes": 60  // 60 分後に自動削除
  }
}
```

### 4. ノード配置

```yaml
# 専用ノードプールを使用してセッション Pod を分離
nodeSelector:
  workload-type: agentapi-sessions

# スポットインスタンス/Preemptible VM を使用してコスト削減
tolerations:
  - key: "preemptible"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
```

### 5. 監視とアラート

```yaml
# メトリクスを定期的に監視
# - Pod 起動失敗率
# - セッション平均実行時間
# - リソース使用率
# - OOM 発生頻度

# アラート設定例 (Prometheus AlertManager)
groups:
  - name: agentapi-sessions
    rules:
      - alert: HighSessionPodFailureRate
        expr: |
          rate(agentapi_session_pod_failures_total[5m]) > 0.1
        annotations:
          summary: "High session pod failure rate"

      - alert: SessionPodOOM
        expr: |
          kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} == 1
        annotations:
          summary: "Session pod killed due to OOM"
```

---

## まとめ

Kubernetes セッション管理は agentapi-proxy の中核機能です:

- **動的リソース管理**: ユーザーリクエストに応じて Pod を自動作成・削除
- **完全な分離**: セッションごとに独立した Pod、ServiceAccount、リソース制限
- **柔軟な設定**: CPU、メモリ、ストレージ、配置ポリシーをカスタマイズ可能
- **セキュア**: SecurityContext、RBAC、Secret による多層防御
- **可観測性**: OpenTelemetry、ログ、メトリクスによる詳細な監視

適切な設定により、スケーラブルでセキュアなマルチユーザー環境を実現できます。
