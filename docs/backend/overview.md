# バックエンド概要

## agentapi-proxy とは

`agentapi-proxy` は ccplant プロジェクトのバックエンドコンポーネントで、AI エージェントとユーザーのセッション管理を実現する Go 言語ベースの REST API サーバーです。Kubernetes ネイティブな設計により、動的なセッション Pod の作成・管理を通じて、複数ユーザーによる同時利用を可能にします。

## 主要機能

### 1. セッション管理
- **Kubernetes ネイティブセッション**: 各ユーザーセッションを独立した Kubernetes Pod として動的に作成・管理
- **自動スケーリング**: セッション需要に応じて Pod を自動的に作成・削除
- **リソース分離**: セッションごとに独立したリソース制限とセキュリティコンテキストを適用

### 2. 認証・認可
- **GitHub OAuth 2.0**: ユーザー認証に GitHub OAuth を使用
- **GitHub App 統合**: GitHub App による高度な権限管理
- **静的 API キー認証**: システム間通信用の API キー認証をサポート
- **RBAC (Role-Based Access Control)**: ロールベースのアクセス制御によるきめ細かい権限管理

### 3. マルチポート構成
- **ポート 8080**: メイン HTTP API エンドポイント (REST API、ヘルスチェック)
- **ポート 9000**: セッション管理ベースポート (動的セッション接続)

### 4. 監視と可観測性
- **OpenTelemetry 統合**: 自動メトリクス収集とエクスポート
- **ヘルスチェックエンドポイント**: `/health` エンドポイントによる稼働状態監視
- **セッションメトリクス**: セッション Pod 内の Claude Code メトリクスを収集

### 5. 拡張性
- **MCP サーバー統合**: Model Context Protocol サーバーの動的設定
- **ロールベース環境変数**: ユーザーロールに応じた環境変数の注入
- **カスタム Pod 設定**: NodeSelector、Tolerations による Pod 配置制御

## アーキテクチャの特徴

### Kubernetes ネイティブ
agentapi-proxy は Kubernetes API を直接操作して、以下のリソースを動的に管理します:

- **Pod**: セッション実行環境
- **Service**: セッション Pod へのネットワークアクセス
- **PersistentVolumeClaim**: セッションデータの永続化 (オプション)
- **Secret**: 認証情報とセッション固有の機密データ
- **ConfigMap**: セッション設定情報

### マルチテナント対応
- ユーザーごとに独立したセッション環境を提供
- ServiceAccount による最小権限の原則を適用
- セッション Pod 間の完全な分離

### セキュリティ重視
- **非 root ユーザー実行**: UID/GID 999 での実行
- **読み取り専用ルートファイルシステム**: 可能な限り変更不可能な環境
- **SecurityContext 適用**: Pod およびコンテナレベルのセキュリティ設定
- **RBAC 最小権限**: セッション Pod には最小限の Kubernetes API 権限のみ付与

## デプロイメント構成

### スタンドアロン
- Docker Compose によるローカル開発環境
- ポート 8080 での HTTP API 公開

### Kubernetes (推奨本番環境)
- Helm Chart による一貫したデプロイメント
- Ingress による外部アクセス制御
- 水平スケーリング対応 (デフォルト 3 レプリカ)
- cert-manager による自動 TLS 証明書管理

## 技術スタック

- **言語**: Go
- **コンテナレジストリ**: GitHub Container Registry (ghcr.io)
- **オーケストレーション**: Kubernetes
- **認証**: GitHub OAuth 2.0, GitHub App
- **監視**: OpenTelemetry
- **パッケージ管理**: Helm

## 次のステップ

- [アーキテクチャ詳細](./architecture.md): システム設計とコンポーネント構成
- [API エンドポイント](./api-endpoints.md): REST API 仕様
- [認証・認可](./authentication.md): 認証フローと権限管理
- [Kubernetes セッション管理](./kubernetes-sessions.md): セッション Pod のライフサイクルと設定
