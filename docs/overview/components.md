# 主要コンポーネント

ccplant システムを構成する主要なコンポーネントについて説明します。

## 1. agentapi-ui (フロントエンド)

### 概要

Next.js ベースの Web フロントエンドで、AI エージェントとのインタラクションを提供します。

### 主要な機能

- **セッション管理**
  - セッションの作成、一覧表示、削除
  - セッションのソートとフィルタリング
  - セッションの検索機能

- **チャットインターフェース**
  - リアルタイムメッセージング (WebSocket/SSE)
  - ストリーミングレスポンス表示
  - Markdown レンダリング
  - コードブロックのシンタックスハイライト

- **設定管理**
  - グローバル設定 (API キー、OAuth)
  - 個人設定 (フォント、テーマ)
  - MCP サーバー設定
  - プロファイル管理

- **高度な機能**
  - Webhook 設定
  - スケジュール管理
  - プラグイン/マーケットプレイス
  - プッシュ通知

### 技術仕様

```yaml
Framework: Next.js 15.4.10
Runtime: React 18.3.1
Language: TypeScript 5.8.3
Package Manager: Bun 1.2.16
Port: 3000
Container Image: ghcr.io/takutakahashi/agentapi-ui
```

### リソース要件

```yaml
CPU Request: 100m
CPU Limit: 500m
Memory Request: 128Mi
Memory Limit: 512Mi
Replicas: 1 (スケーラブル)
```

## 2. agentapi-proxy (バックエンド)

### 概要

Go 言語で実装されたバックエンド API サーバーで、認証、セッション管理、Kubernetes 統合を提供します。

### 主要な機能

- **認証・認可**
  - GitHub OAuth 認証
  - GitHub App 統合
  - API キー認証
  - ロールベースアクセス制御 (RBAC)

- **セッション管理**
  - Kubernetes Pod としてのセッション作成
  - セッションのライフサイクル管理
  - リソース制限の適用
  - セッションの監視

- **API エンドポイント**
  - REST API
  - WebSocket サポート
  - Server-Sent Events (SSE)
  - ヘルスチェックエンドポイント

- **自動化機能**
  - Webhook 統合
  - スケジュールタスク実行
  - Leader Election による冗長性

### 技術仕様

```yaml
Language: Go
Primary Port: 8080 (HTTP API)
Agent Port: 9000 (Session Communication)
Container Image: ghcr.io/takutakahashi/agentapi-proxy
Deployment Type: StatefulSet
```

### リソース要件

```yaml
CPU Request: 500m
CPU Limit: 8 cores
Memory Request: 512Mi
Memory Limit: 8Gi
Replicas: 3 (High Availability)
```

### セキュリティ

```yaml
User/Group: 999 (non-root)
fsGroup: 999
ReadOnly Root Filesystem: Yes (for configs)
ServiceAccount: ccplant-agentapi-proxy
```

## 3. Session Pods (動的セッション)

### 概要

ユーザーごとに動的に作成される Pod で、AI エージェントの実行環境を提供します。

### 特徴

- **分離された実行環境**
  - ユーザーごとに独立した Pod
  - リソース制限の適用
  - セキュリティコンテキストの分離

- **Kubernetes ネイティブ**
  - Kubernetes API を使用した動的管理
  - サービスアカウントによる権限管理
  - ConfigMap/Secret のマウント

- **オプション機能**
  - Persistent Volume Claim (データ永続化)
  - MCP サーバーサイドカー
  - OpenTelemetry Collector サイドカー

### 技術仕様

```yaml
Base Image: agentapi-proxy (同じイメージ)
ServiceAccount: agentapi-proxy-session
Base Port: 9000
Lifecycle: 動的作成/削除
```

### リソース要件

```yaml
CPU Request: 500m
CPU Limit: 2 cores
Memory Request: 512Mi
Memory Limit: 4Gi
Start Timeout: 120 seconds
Stop Timeout: 30 seconds
```

### PVC 設定 (オプション)

```yaml
Enabled: false (デフォルト)
Storage Class: 指定可能
Storage Size: 10Gi (デフォルト)
```

## 4. OpenTelemetry Collector (オプション)

### 概要

Session Pod にサイドカーとしてデプロイされ、メトリクスを収集します。

### 機能

- **メトリクス収集**
  - Claude Code メトリクス (Port 9464)
  - システムメトリクス
  - カスタムメトリクス

- **エクスポート**
  - Prometheus 形式
  - クラウドモニタリングサービス
  - カスタムエクスポーター

### 技術仕様

```yaml
Image: otel/opentelemetry-collector-contrib:0.143.1
Scrape Interval: 15 seconds
Claude Code Port: 9464
Exporter Port: 9090
```

### リソース要件

```yaml
CPU Request: 100m
CPU Limit: 200m
Memory Request: 128Mi
Memory Limit: 256Mi
```

## 5. Ingress Controller (NGINX)

### 概要

外部トラフィックをルーティングし、TLS 終端を提供します。

### 機能

- **TLS 終端**
  - Let's Encrypt 証明書の自動管理
  - cert-manager 統合
  - HTTPS 強制

- **ルーティング**
  - ホストベースルーティング
  - パスベースルーティング
  - バックエンドへのプロキシ

- **設定**
  - プロキシボディサイズ: 100MB
  - タイムアウト: 600 秒
  - カスタムアノテーション対応

### 設定例

```yaml
className: nginx
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-prod
  nginx.ingress.kubernetes.io/proxy-body-size: "100m"
  nginx.ingress.kubernetes.io/proxy-connect-timeout: "600"
  nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
  nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
```

## 6. Kubernetes リソース

### ConfigMap

```yaml
名前: ccplant-agentapi-proxy-auth-config
目的: 認証設定の管理
マウント先: /etc/auth-config/auth-config.yaml
内容:
  - ユーザーマッピング
  - デフォルトロール
  - デフォルト権限
  - チームマッピング
```

### Secret

1. **github-app**
   ```yaml
   内容:
     - private-key: GitHub App の秘密鍵 (PEM 形式)
   マウント先: /etc/github-app/
   ```

2. **agentapi-ui-encryption**
   ```yaml
   内容:
     - cookie-encryption-secret: Cookie 暗号化キー
     - cookie-secret: セッションシークレット
     - encryption-key: データ暗号化キー
   ```

3. **mcp-servers-base** (オプション)
   ```yaml
   内容: MCP サーバー設定
   用途: Session Pod での MCP サーバー起動
   ```

### ServiceAccount

1. **ccplant-agentapi-proxy**
   ```yaml
   目的: メインアプリケーションの実行
   権限:
     - Pod 管理 (create, delete, get, list, watch)
     - Service 管理
     - PVC 管理
     - Deployment 管理
     - Secret/ConfigMap 管理
     - Lease 管理 (Leader Election)
   ```

2. **agentapi-proxy-session**
   ```yaml
   目的: Session Pod の実行
   権限:
     - Pod 読み取り (get, list)
     - Pod ログ読み取り
     - ConfigMap 読み取り
     - Secret 作成/更新 (credentials-sync 用)
   ```

## 7. サポートサービス

### cert-manager

- TLS 証明書の自動取得と更新
- Let's Encrypt 統合
- ClusterIssuer: letsencrypt-prod

### GitHub Services

- **GitHub OAuth**: ユーザー認証
- **GitHub App**: サーバー間認証、Webhook、API アクセス
- **GitHub API**: ユーザー情報取得、リポジトリアクセス

## コンポーネント間の通信

### 内部通信

```
agentapi-ui → agentapi-proxy
  Protocol: HTTP
  URL: http://ccplant-agentapi-proxy:8080
  Authentication: Cookie (encrypted)

agentapi-proxy → Session Pods
  Protocol: HTTP
  Base Port: 9000
  Management: Kubernetes API
```

### 外部通信

```
User → Ingress (HTTPS)
  Frontend: https://cc-dev.example.com → agentapi-ui:3000
  Backend: https://cc-api.example.com → agentapi-proxy:8080

agentapi-proxy → GitHub
  OAuth: https://github.com/login/oauth
  API: https://api.github.com
  App: GitHub App API
```

## デプロイメント構成

### Helm チャート構造

```
ccplant (親チャート)
├── agentapi-proxy (dependency)
│   └── v1.191.0
└── agentapi-ui (dependency)
    └── v1.97.0
```

### OCI レジストリ

```
Registry: ghcr.io/takutakahashi/charts
Charts:
  - ccplant
  - agentapi-proxy
  - agentapi-ui
```

## まとめ

各コンポーネントは独立して機能しつつ、Kubernetes の機能を活用して連携しています:

1. **Frontend**: ユーザーインターフェースの提供
2. **Backend**: ビジネスロジックとセッション管理
3. **Session Pods**: 分離された実行環境
4. **Ingress**: トラフィックルーティングと TLS 終端
5. **Kubernetes**: 統一的なリソース管理とオーケストレーション

次のセクション:
- [技術スタック](./tech-stack.md)
