# システムアーキテクチャ

## 全体構成

ccplant は、以下の3つの主要コンポーネントで構成されています:

```
┌─────────────────────────────────────────────────────────────┐
│                       ユーザー                               │
│                  (ブラウザ / PWA)                            │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTPS
                     ↓
┌─────────────────────────────────────────────────────────────┐
│                   Kubernetes クラスタ                         │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Ingress Controller (NGINX)                │ │
│  │           (TLS Termination / Routing)                  │ │
│  └───────────┬──────────────────────┬─────────────────────┘ │
│              │                      │                        │
│              ↓                      ↓                        │
│  ┌────────────────────┐  ┌─────────────────────────┐       │
│  │   agentapi-ui      │  │   agentapi-proxy        │       │
│  │   (Frontend)       │←→│   (Backend API)         │       │
│  │                    │  │                         │       │
│  │  - Next.js 15      │  │  - Go                   │       │
│  │  - React 18        │  │  - Port: 8080 (HTTP)    │       │
│  │  - Port: 3000      │  │  - Port: 9000 (Agent)   │       │
│  │  - PWA             │  │                         │       │
│  └────────────────────┘  └──────────┬──────────────┘       │
│                                      │                       │
│                                      │ Manages               │
│                                      ↓                       │
│              ┌─────────────────────────────────────┐        │
│              │   Session Pods (Dynamic)            │        │
│              │                                     │        │
│              │  ┌──────────┐  ┌──────────┐        │        │
│              │  │Session 1 │  │Session 2 │  ...   │        │
│              │  │          │  │          │        │        │
│              │  │AI Agent  │  │AI Agent  │        │        │
│              │  │Runtime   │  │Runtime   │        │        │
│              │  └──────────┘  └──────────┘        │        │
│              └─────────────────────────────────────┘        │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Kubernetes Resources                      │ │
│  │  - ConfigMaps (Auth Config)                           │ │
│  │  - Secrets (GitHub App, Encryption Keys)              │ │
│  │  - Services (Load Balancing)                          │ │
│  │  - ServiceAccounts (RBAC)                             │ │
│  │  - PersistentVolumeClaims (Optional)                  │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                     ↑
                     │ API Calls
                     ↓
┌─────────────────────────────────────────────────────────────┐
│                   External Services                          │
│  - GitHub OAuth                                             │
│  - GitHub App API                                           │
│  - GitHub Webhooks                                          │
└─────────────────────────────────────────────────────────────┘
```

## アーキテクチャの特徴

### 1. マイクロサービス設計

- **Frontend (agentapi-ui)**: ユーザーインターフェースを提供
- **Backend (agentapi-proxy)**: API サーバーとセッション管理
- **Session Pods**: 動的に作成される AI エージェント実行環境

各コンポーネントは独立してスケーリング可能で、疎結合な設計となっています。

### 2. Kubernetes ネイティブ

ccplant は Kubernetes の機能を最大限活用しています:

- **動的セッション管理**: Pod を動的に作成・削除
- **RBAC**: Kubernetes のロールベースアクセス制御
- **Service Discovery**: Kubernetes Service による自動的なサービス発見
- **ConfigMap/Secret**: 設定とシークレットの管理
- **Leader Election**: スケジュールワーカーの冗長性確保

### 3. セキュアな設計

```
┌──────────────────────────────────────────────────────┐
│              Security Layers                         │
├──────────────────────────────────────────────────────┤
│ 1. TLS Termination (Ingress)                        │
│    - HTTPS 通信の暗号化                              │
│    - Let's Encrypt による証明書管理                  │
├──────────────────────────────────────────────────────┤
│ 2. Authentication (Backend)                         │
│    - GitHub OAuth                                   │
│    - API Key 認証                                   │
│    - Cookie 暗号化 (AES-256-GCM)                    │
├──────────────────────────────────────────────────────┤
│ 3. Authorization (RBAC)                             │
│    - Kubernetes ServiceAccount                      │
│    - Role/RoleBinding                               │
│    - 最小権限の原則                                  │
├──────────────────────────────────────────────────────┤
│ 4. Network Policy (Optional)                        │
│    - Pod 間通信の制限                                │
│    - Ingress/Egress ルール                          │
├──────────────────────────────────────────────────────┤
│ 5. Container Security                               │
│    - Non-root ユーザー実行 (UID 999)                │
│    - ReadOnlyRootFilesystem                         │
│    - Resource Limits                                │
└──────────────────────────────────────────────────────┘
```

## データフロー

### 1. ユーザー認証フロー

```
User → Frontend → Backend → GitHub OAuth → Backend → Frontend → User
  1. ログインボタンクリック
  2. OAuth リダイレクト
  3. GitHub 認証
  4. コールバック処理
  5. トークン発行
  6. Cookie 設定
  7. ホームページリダイレクト
```

### 2. セッション作成フロー

```
User → Frontend → Backend → Kubernetes API → Session Pod
  1. 新規セッション作成リクエスト
  2. API 呼び出し
  3. Pod 定義生成
  4. Pod 作成 (Kubernetes API)
  5. Pod 起動待機
  6. セッション情報返却
  7. チャット画面表示
```

### 3. メッセージ送信フロー

```
User → Frontend → Backend → Session Pod → AI Agent → Response
  1. メッセージ入力
  2. WebSocket/SSE で送信
  3. Session Pod にルーティング
  4. AI エージェント処理
  5. ストリーミングレスポンス
  6. リアルタイム表示
```

## スケーラビリティ

### 水平スケーリング

```
┌──────────────────────────────────────────────────────┐
│                  Load Balancer                       │
│                  (Kubernetes Service)                │
└─────────────┬────────────────────────────────────────┘
              │
    ┌─────────┼─────────┬─────────┐
    ↓         ↓         ↓         ↓
┌────────┐┌────────┐┌────────┐┌────────┐
│Backend ││Backend ││Backend ││Backend │
│  Pod 1 ││  Pod 2 ││  Pod 3 ││  Pod N │
└────────┘└────────┘└────────┘└────────┘
```

- **Backend**: 3 レプリカ (デフォルト)
- **Frontend**: 1 レプリカ (デフォルト、必要に応じて増減可能)
- **Session Pods**: ユーザーごとに動的作成

### リソース配分

| コンポーネント | CPU Request | CPU Limit | Memory Request | Memory Limit |
|---------------|-------------|-----------|----------------|--------------|
| agentapi-proxy | 500m | 8 cores | 512Mi | 8Gi |
| agentapi-ui | 100m | 500m | 128Mi | 512Mi |
| Session Pod | 500m | 2 cores | 512Mi | 4Gi |
| OTEL Collector | 100m | 200m | 128Mi | 256Mi |

## 可用性

### High Availability 構成

1. **Backend の冗長化**
   - 3 レプリカによる冗長性
   - Pod 障害時の自動再起動
   - Readiness/Liveness Probe による健全性チェック

2. **Leader Election**
   - スケジュールワーカーの Leader Election
   - Kubernetes Lease リソースを使用
   - 単一のワーカーのみが実行

3. **Stateless Design**
   - Backend は基本的にステートレス
   - セッション状態は Session Pod に保持
   - 設定は ConfigMap/Secret で管理

## 監視とオブザーバビリティ

### OpenTelemetry 統合

```
Session Pod
    ↓
OTEL Collector (Sidecar)
    ↓ (Metrics Export)
Prometheus / Grafana / Cloud Monitoring
```

- **メトリクス収集**: 15秒間隔
- **Claude Code メトリクス**: Port 9464
- **Exporter Port**: 9090

### ヘルスチェック

```yaml
Liveness Probe:
  HTTP GET /health
  - Initial Delay: 30s
  - Period: 10s
  - Timeout: 5s
  - Failure Threshold: 3

Readiness Probe:
  HTTP GET /health
  - Initial Delay: 10s
  - Period: 5s
  - Timeout: 3s
  - Failure Threshold: 3
```

## デプロイメントモデル

### 1. 開発環境 (Docker Compose)

```
docker-compose.yaml
├── backend:latest
└── frontend:latest
```

- ローカル開発に最適
- 簡単な起動とテスト
- リソース制限あり

### 2. ステージング/本番環境 (Kubernetes)

```
Helm Chart
├── agentapi-proxy (v1.191.0)
└── agentapi-ui (v1.97.0)
```

- Helm チャートによる統一的なデプロイ
- OCI レジストリから配信
- バージョン管理と簡単なロールバック

## まとめ

ccplant のアーキテクチャは以下の原則に基づいています:

1. **モジュール性**: 各コンポーネントは独立して開発・デプロイ可能
2. **スケーラビリティ**: 負荷に応じて水平スケーリング
3. **セキュリティ**: 多層防御によるセキュア設計
4. **可用性**: 冗長化と自動復旧による高可用性
5. **可観測性**: メトリクス、ログ、ヘルスチェックによる監視

次のセクション:
- [主要コンポーネント](./components.md)
- [技術スタック](./tech-stack.md)
