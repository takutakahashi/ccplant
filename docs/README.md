# ccplant ドキュメント

ccplant は、AI エージェントのための統合デプロイメントソリューションです。agentapi-proxy (バックエンド) と agentapi-ui (フロントエンド) を Kubernetes 上で簡単にデプロイできる Helm チャートを提供します。

## 目次

### 1. [概要](./overview/)
- [アーキテクチャ](./overview/architecture.md) - システム全体のアーキテクチャ
- [主要コンポーネント](./overview/components.md) - システムの構成要素
- [技術スタック](./overview/tech-stack.md) - 使用している技術の詳細

### 2. [機能](./features/)
- [機能概要](./features/README.md) - 全機能の概要とクイックスタート
- [セッション管理](./features/sessions.md) - セッションの作成、管理、削除
- [チャット機能](./features/chat.md) - メッセージング、ストリーミング、フォントカスタマイズ
- [Webhook](./features/webhooks.md) - GitHub Webhook 統合と自動化
- [スケジュール](./features/schedules.md) - Cron ベースの定期実行
- [エージェント管理](./features/agents.md) - エージェントの設定とマーケットプレイス
- [認証とアクセス](./features/authentication.md) - ログイン方法と認証設定
- [チームと権限](./features/permissions.md) - RBAC とロール管理
- [MCP サーバー](./features/mcp-servers.md) - Model Context Protocol 統合
- [プッシュ通知](./features/notifications.md) - ブラウザ通知の設定
- [設定管理](./features/settings.md) - グローバル設定と個人設定

### 3. [バックエンド](./backend/)
- [概要](./backend/overview.md) - agentapi-proxy の概要
- [アーキテクチャ](./backend/architecture.md) - バックエンドのアーキテクチャ
- [API エンドポイント](./backend/api-endpoints.md) - REST API 仕様
- [認証と認可](./backend/authentication.md) - 認証・認可の仕組み
- [Kubernetes セッション管理](./backend/kubernetes-sessions.md) - セッション管理の詳細
- [GitHub 統合](./backend/github-integration.md) - GitHub OAuth/App 統合
- [Webhook とスケジュール](./backend/webhooks-schedules.md) - 自動化機能
- [設定リファレンス](./backend/configuration.md) - 設定項目の詳細
- [RBAC 権限](./backend/rbac.md) - Kubernetes RBAC 設定

### 4. [フロントエンド](./frontend/)
- [概要](./frontend/overview.md) - agentapi-ui の概要
- [アーキテクチャ](./frontend/architecture.md) - フロントエンドのアーキテクチャ
- [機能と UI](./frontend/features.md) - 主要機能とユーザーインターフェース
- [ページとルーティング](./frontend/pages-routing.md) - ページ構造とルーティング
- [API 統合](./frontend/api-integration.md) - バックエンドとの通信
- [設定リファレンス](./frontend/configuration.md) - 設定項目の詳細
- [セキュリティ](./frontend/security.md) - セキュリティ実装
- [PWA 機能](./frontend/pwa.md) - Progressive Web App 機能

### 5. [デプロイメント](./deployment/)
- [クイックスタート](./deployment/quick-start.md) - 最短でデプロイする方法
- [Docker Compose](./deployment/docker-compose.md) - Docker Compose でのデプロイ
- [Kubernetes](./deployment/kubernetes.md) - Kubernetes へのデプロイ
- [Helm Chart](./deployment/helm-chart.md) - Helm チャートの詳細設定
- [設定ガイド](./deployment/configuration.md) - デプロイ設定のベストプラクティス
- [トラブルシューティング](./deployment/troubleshooting.md) - よくある問題と解決方法

### 6. [開発](./development/)
- [開発環境セットアップ](./development/setup.md) - ローカル開発環境の構築
- [テスト](./development/testing.md) - テスト戦略と実行方法
- [コントリビューション](./development/contributing.md) - プロジェクトへの貢献方法
- [CI/CD パイプライン](./development/ci-cd.md) - 継続的インテグレーション/デリバリー

### 7. [運用](./operations/)
- [モニタリング](./operations/monitoring.md) - システムの監視とメトリクス
- [セキュリティ](./operations/security.md) - セキュリティベストプラクティス
- [バックアップとリカバリ](./operations/backup-recovery.md) - データ保護
- [メンテナンス](./operations/maintenance.md) - 定期メンテナンス作業

## クイックリンク

### よく使うコマンド

```bash
# Docker Compose でローカル起動
docker compose up -d

# Helm で Kubernetes にデプロイ
helm install ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --set global.hostname=cc-dev.example.com \
  --set global.github.oauth.clientId=YOUR_CLIENT_ID \
  --set global.github.oauth.clientSecret=YOUR_CLIENT_SECRET

# Helm チャートの更新
helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant

# ログの確認
kubectl logs -f deployment/ccplant-agentapi-proxy
```

### リポジトリ

- **Helm Chart**: [takutakahashi/ccplant](https://github.com/takutakahashi/ccplant)
- **Backend**: [takutakahashi/agentapi-proxy](https://github.com/takutakahashi/agentapi-proxy)
- **Frontend**: [takutakahashi/agentapi-ui](https://github.com/takutakahashi/agentapi-ui)

### バージョン情報

- **Helm Chart**: v0.4.0
- **agentapi-proxy**: v1.191.0
- **agentapi-ui**: v1.97.0

## サポート

問題が発生した場合は、以下のリソースをご確認ください:

1. [トラブルシューティングガイド](./deployment/troubleshooting.md)
2. [GitHub Issues](https://github.com/takutakahashi/ccplant/issues)
3. 各リポジトリの Issue トラッカー

## ライセンス

このプロジェクトのライセンスについては、各リポジトリの LICENSE ファイルをご確認ください。
