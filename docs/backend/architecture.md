# バックエンドアーキテクチャ

## システム構成図

```
┌─────────────────────────────────────────────────────────────────┐
│                          Ingress (HTTPS)                        │
│                     cc-api.example.com                          │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                   agentapi-proxy Deployment                     │
│                      (3 Replicas)                               │
│                                                                 │
│  ┌───────────────────────────────────────────────────────┐    │
│  │  Container: agentapi-proxy                            │    │
│  │  Port 8080: HTTP API (REST, WebSocket, SSE)          │    │
│  │  Port 9000: Session Base Port                         │    │
│  │                                                        │    │
│  │  Volume Mounts:                                        │    │
│  │  - /etc/auth-config (ConfigMap)                       │    │
│  │  - /etc/github-app (Secret)                           │    │
│  └───────────────────────────────────────────────────────┘    │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                │ Manages via Kubernetes API
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Session Pods (Dynamic)                        │
│                                                                  │
│  ┌──────────────────────────────────────────────────────┐      │
│  │  Pod: session-{user}-{session-id}                     │      │
│  │                                                        │      │
│  │  ┌────────────────────────────────────────────────┐  │      │
│  │  │ Container: claude-code                         │  │      │
│  │  │ Port 9000: Claude Code API                     │  │      │
│  │  │ Volume: /home/agentapi/.claude (PVC optional)  │  │      │
│  │  └────────────────────────────────────────────────┘  │      │
│  │                                                        │      │
│  │  ┌────────────────────────────────────────────────┐  │      │
│  │  │ Container: otel-collector (sidecar)            │  │      │
│  │  │ Port 9464: Prometheus metrics scrape           │  │      │
│  │  │ Port 9090: Metrics export                       │  │      │
│  │  └────────────────────────────────────────────────┘  │      │
│  │                                                        │      │
│  │  ┌────────────────────────────────────────────────┐  │      │
│  │  │ Container: credentials-sync (sidecar)          │  │      │
│  │  │ Syncs credentials.json to Secret               │  │      │
│  │  └────────────────────────────────────────────────┘  │      │
│  └──────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────┘
```

## コンポーネント詳細

### 1. agentapi-proxy (メインアプリケーション)

#### 役割
- REST API エンドポイントの提供
- WebSocket/SSE によるリアルタイム通信
- 認証・認可の処理
- Kubernetes リソースの動的管理
- セッションライフサイクル管理

#### 主要機能モジュール

##### API サーバー (ポート 8080)
```
/api/v1/sessions          - セッション管理
/api/v1/users             - ユーザー情報
/api/v1/github            - GitHub 統合
/health                   - ヘルスチェック
/ws                       - WebSocket エンドポイント
/sse                      - Server-Sent Events
```

##### セッションマネージャー
- Pod の作成・削除・監視
- Service の動的管理
- PVC のライフサイクル管理
- リソースクォータの適用

##### 認証マネージャー
- GitHub OAuth トークンの検証
- GitHub App による権限確認
- API キーの検証
- ユーザーロールとパーミッションの解決

##### スケジュールワーカー
- セッションのタイムアウト監視
- 不要なリソースの自動クリーンアップ
- リーダーエレクション (複数レプリカ対応)

### 2. セッション Pod

#### 構成
各セッション Pod は以下のコンテナで構成されます:

##### メインコンテナ: claude-code
```yaml
Resources:
  Requests:
    CPU: 500m
    Memory: 512Mi
  Limits:
    CPU: 2
    Memory: 4Gi

Environment Variables:
  - HOME=/home/agentapi
  - AGENTAPI_*=(セッション固有の設定)

Volume Mounts:
  - /home/agentapi/.claude (ワークスペース)
  - /home/agentapi/.config (設定ファイル)
```

##### サイドカー: otel-collector
```yaml
Image: otel/opentelemetry-collector-contrib:0.143.1

Resources:
  Requests:
    CPU: 100m
    Memory: 128Mi
  Limits:
    CPU: 200m
    Memory: 256Mi

Purpose:
  - Claude Code メトリクスの収集 (ポート 9464)
  - Prometheus 形式でのメトリクスエクスポート
  - 15秒間隔でのスクレイピング
```

##### サイドカー: credentials-sync
```yaml
Purpose:
  - credentials.json の監視
  - Kubernetes Secret への自動同期
  - セッション間での認証情報共有
```

### 3. RBAC 構成

#### agentapi-proxy ServiceAccount
```yaml
Permissions:
  - pods: [get, list, watch, create, delete]
  - services: [get, list, create, delete]
  - persistentvolumeclaims: [get, list, create, delete]
  - secrets: [get, list, create, update, delete, patch]
  - configmaps: [get, list, create, update, patch, delete]
  - deployments: [get, list, watch, create, delete]
  - leases: [get, list, watch, create, update, patch, delete]
```

用途: セッション Pod の完全な管理権限

#### agentapi-proxy-session ServiceAccount
```yaml
Permissions:
  - pods: [get, list]
  - pods/log: [get]
  - configmaps: [get, list]
  - secrets: [create, update]
```

用途: セッション Pod 内での最小権限 (credentials-sync 用)

## データフロー

### セッション作成フロー

```
1. ユーザーリクエスト
   POST /api/v1/sessions
   Authorization: Bearer {github-token}
   │
   ▼
2. 認証・認可チェック
   - GitHub トークン検証
   - ユーザーロール解決
   - パーミッション確認 (session:create)
   │
   ▼
3. Kubernetes リソース作成
   - Secret 作成 (MCP servers, credentials)
   - ConfigMap 作成 (session config)
   - PVC 作成 (オプション)
   - Pod 作成 (claude-code + sidecars)
   - Service 作成 (セッションアクセス用)
   │
   ▼
4. Pod 起動待機
   - Pod Ready 状態を監視
   - タイムアウト: 120秒 (設定可能)
   │
   ▼
5. セッション情報返却
   - Session ID
   - Connection URL
   - Status: running
```

### セッション削除フロー

```
1. 削除リクエスト
   DELETE /api/v1/sessions/{id}
   │
   ▼
2. 権限チェック
   - セッション所有者確認
   - または session:delete 権限確認
   │
   ▼
3. リソース削除
   - Pod 削除 (graceful shutdown: 30秒)
   - Service 削除
   - PVC 削除 (設定による)
   - Secret 削除
   - ConfigMap 削除
   │
   ▼
4. ステータス更新
   - Session Status: terminated
   - メタデータの保存 (監査ログ用)
```

### リアルタイム通信フロー

```
WebSocket/SSE 接続
   │
   ▼
認証 (Authorization header)
   │
   ▼
セッション Pod へのプロキシ
   │
   ▼
双方向通信
   - ユーザー → Session Pod: コマンド、入力
   - Session Pod → ユーザー: 出力、ステータス、イベント
```

## 設計パターン

### 1. サイドカーパターン
セッション Pod は複数のサイドカーコンテナを使用:
- **otel-collector**: メトリクス収集の責務分離
- **credentials-sync**: 認証情報同期の自動化

利点:
- 関心の分離
- 再利用可能なコンポーネント
- 独立したリソース管理

### 2. オペレーターパターン
agentapi-proxy は Kubernetes Operator のように動作:
- カスタムリソース (Session) の管理
- Reconciliation ループによる状態同期
- スケジュールワーカーによる定期チェック

### 3. マルチテナンシー
- Namespace によるリソース分離
- ServiceAccount による権限分離
- NetworkPolicy による通信制御 (オプション)

### 4. 設定外部化
環境変数プレフィックス `AGENTAPI_*` による階層的設定:
```
AGENTAPI_AUTH_ENABLED=true
AGENTAPI_AUTH_GITHUB_ENABLED=true
AGENTAPI_AUTH_GITHUB_OAUTH_CLIENT_ID=xxx
AGENTAPI_K8S_SESSION_ENABLED=true
AGENTAPI_K8S_SESSION_CPU_LIMIT=2
```

## スケーラビリティ

### 水平スケーリング

#### agentapi-proxy
- デフォルト 3 レプリカ
- ステートレス設計
- リーダーエレクション (スケジュールワーカー用)

#### セッション Pod
- ユーザー需要に応じて自動作成
- 1 セッション = 1 Pod
- Kubernetes スケジューラーによる最適配置

### リソース管理

```yaml
agentapi-proxy:
  Requests:
    CPU: 500m
    Memory: 512Mi
  Limits:
    CPU: 8
    Memory: 8Gi

Session Pod (claude-code):
  Requests:
    CPU: 500m
    Memory: 512Mi
  Limits:
    CPU: 2
    Memory: 4Gi

Session Pod (otel-collector):
  Requests:
    CPU: 100m
    Memory: 128Mi
  Limits:
    CPU: 200m
    Memory: 256Mi
```

## セキュリティアーキテクチャ

### 多層防御

1. **ネットワーク層**
   - Ingress による外部アクセス制御
   - TLS 終端 (cert-manager)
   - ホワイトリストベースのアクセス制御

2. **認証層**
   - GitHub OAuth 必須
   - トークンベース認証
   - セッション固有の認証情報

3. **認可層**
   - RBAC によるリソースアクセス制御
   - ユーザーロールベースのパーミッション
   - セッション所有者検証

4. **実行層**
   - 非 root ユーザー実行 (UID 999)
   - SecurityContext 適用
   - 最小権限の ServiceAccount

5. **データ層**
   - Secret による機密情報管理
   - 暗号化ボリューム (オプション)
   - 自動クリーンアップ

## 監視とロギング

### メトリクス収集
- OpenTelemetry による自動計測
- Prometheus 互換メトリクスエクスポート
- カスタムメトリクス:
  - セッション数
  - セッション期間
  - リソース使用率

### ヘルスチェック
```yaml
Liveness Probe:
  Path: /health
  InitialDelaySeconds: 30
  PeriodSeconds: 10
  TimeoutSeconds: 5

Readiness Probe:
  Path: /health
  InitialDelaySeconds: 10
  PeriodSeconds: 5
  TimeoutSeconds: 3
```

### ログ
- 構造化ログ (JSON)
- セッション ID によるトレーシング
- 監査ログ (認証・認可イベント)

## 障害復旧

### 自動復旧メカニズム
- Deployment による自動 Pod 再起動
- Readiness Probe による不健全なレプリカの除外
- スケジュールワーカーによる孤立リソースのクリーンアップ

### データ永続化
- PVC によるセッションデータの保持 (オプション)
- Secret による認証情報の保存
- 削除ポリシーの設定可能化

## パフォーマンス最適化

### 並行処理
- Go の goroutine による非同期処理
- Kubernetes API の並行呼び出し
- WebSocket/SSE による効率的な通信

### キャッシング
- Kubernetes リソースの in-memory キャッシュ
- GitHub API レスポンスのキャッシュ
- ユーザーロール情報のキャッシュ

### リソース効率
- 不要なセッションの自動削除
- Graceful shutdown による正常終了
- リソースリミットによる過負荷防止
