# 技術スタック

ccplant プロジェクトで使用されている技術とツールの詳細です。

## フロントエンド技術

### コアフレームワーク

| 技術 | バージョン | 用途 |
|------|-----------|------|
| **Next.js** | 15.4.10 | React フレームワーク、App Router |
| **React** | 18.3.1 | UI ライブラリ |
| **TypeScript** | 5.8.3 | 型安全なコード |

### スタイリング

| 技術 | バージョン | 用途 |
|------|-----------|------|
| **Tailwind CSS** | 3.4.1 | ユーティリティファーストの CSS フレームワーク |
| **PostCSS** | 8.4.21 | CSS 処理 |
| **lucide-react** | 0.525.0 | アイコンライブラリ |

### データビジュアライゼーション

| 技術 | バージョン | 用途 |
|------|-----------|------|
| **recharts** | 3.0.0 | グラフとチャートの描画 |

### PWA (Progressive Web App)

| 技術 | バージョン | 用途 |
|------|-----------|------|
| **next-pwa** | 5.6.0 | PWA サポート |
| **web-push** | 3.6.7 | プッシュ通知 |

### ユーティリティ

| 技術 | バージョン | 用途 |
|------|-----------|------|
| **uuid** | 11.1.0 | UUID 生成 |

### 分析・モニタリング

| 技術 | バージョン | 用途 |
|------|-----------|------|
| **@vercel/analytics** | 1.5.0 | アプリケーション分析 |

## バックエンド技術

### プログラミング言語

| 技術 | 説明 |
|------|------|
| **Go** | バックエンド API サーバーの実装言語 |

### 主要機能

- REST API サーバー
- WebSocket サポート
- Server-Sent Events (SSE)
- Kubernetes クライアント
- GitHub OAuth/App 統合

## インフラストラクチャ

### コンテナ・オーケストレーション

| 技術 | バージョン | 用途 |
|------|-----------|------|
| **Kubernetes** | - | コンテナオーケストレーション |
| **Docker** | - | コンテナ化 |
| **k3s** | - | 軽量 Kubernetes (テスト用) |

### パッケージ管理

| 技術 | バージョン | 用途 |
|------|-----------|------|
| **Helm** | v3.14.0+ | Kubernetes パッケージマネージャー |
| **OCI Registry** | - | Helm チャート配信 (GHCR) |

### Ingress

| 技術 | 説明 |
|------|------|
| **NGINX Ingress Controller** | トラフィックルーティング、TLS 終端 |

### 証明書管理

| 技術 | 説明 |
|------|------|
| **cert-manager** | TLS 証明書の自動管理 |
| **Let's Encrypt** | 無料の TLS 証明書発行 |

## 開発ツール

### ランタイム・パッケージマネージャー

| 技術 | バージョン | 用途 |
|------|-----------|------|
| **Bun** | 1.2.16 | JavaScript ランタイム・パッケージマネージャー |
| **Node.js** | 20.x | JavaScript ランタイム (CI/CD) |

### ツールバージョン管理

| 技術 | 用途 |
|------|------|
| **mise** | ツールバージョン管理 (mise.toml で設定) |

## テスト

### ユニットテスト

| 技術 | バージョン | 用途 |
|------|-----------|------|
| **Vitest** | 2.1.8 | ユニットテスト |
| **@testing-library/react** | 16.0.1 | React コンポーネントテスト |
| **happy-dom** | - | DOM 環境シミュレーション |

### E2E テスト

| 技術 | バージョン | 用途 |
|------|-----------|------|
| **Playwright** | 1.53.2 | E2E テスト、ブラウザ自動化 |

### API モッキング

| 技術 | バージョン | 用途 |
|------|-----------|------|
| **MSW (Mock Service Worker)** | 2.7.0 | API モッキング |

## コード品質

### リント・フォーマット

| 技術 | 用途 |
|------|------|
| **ESLint** | JavaScript/TypeScript リンター |
| **TypeScript** | 型チェック (strict mode) |

## CI/CD

### GitHub Actions

```yaml
ワークフロー:
  - helm-template-validation.yml    # Helm テンプレート検証
  - integration-test.yml            # Docker Compose 統合テスト
  - integration-test-helm.yml       # k3s/Helm デプロイテスト
  - release.yml                     # リリースと公開
```

### 使用 Actions

| Action | 用途 |
|--------|------|
| **actions/checkout@v4** | リポジトリのチェックアウト |
| **azure/setup-helm@v4** | Helm のセットアップ |
| **docker/setup-buildx-action** | Docker Buildx セットアップ |
| **docker/build-push-action** | Docker イメージのビルド・プッシュ |

## 監視・オブザーバビリティ

### メトリクス収集

| 技術 | バージョン | 用途 |
|------|-----------|------|
| **OpenTelemetry Collector** | 0.143.1 | メトリクス・トレース収集 |

### エクスポーター

- Prometheus 形式
- カスタムエクスポーター対応

## 外部サービス統合

### GitHub

| サービス | 用途 |
|---------|------|
| **GitHub OAuth** | ユーザー認証 |
| **GitHub App** | サーバー間認証、Webhook |
| **GitHub API** | ユーザー情報、リポジトリアクセス |
| **GitHub Webhooks** | イベント通知 |

### コンテナレジストリ

| サービス | 用途 |
|---------|------|
| **GitHub Container Registry (ghcr.io)** | Docker イメージと Helm チャートの保存 |

## ドキュメンテーション

### ツール

| 技術 | 用途 |
|------|------|
| **HonKit** | ドキュメント生成 (agentapi-ui) |
| **Markdown** | ドキュメント記述 |

## ローカル開発

### Docker Compose

```yaml
services:
  - backend (agentapi-proxy)
  - frontend (agentapi-ui)

features:
  - ヘルスチェック
  - リソース制限
  - カスタムネットワーク
```

## データベース・ストレージ

### 現在の実装

- **In-memory/Ephemeral**: デフォルトはメモリ内データ保存
- **PersistentVolumeClaim**: オプションで永続化可能

### ストレージクラス

- カスタマイズ可能なストレージクラス
- デフォルトサイズ: 10Gi

## セキュリティ

### 認証・暗号化

| 技術 | 用途 |
|------|------|
| **AES-256-GCM** | Cookie 暗号化 |
| **PBKDF2** | キー導出 |
| **Web Crypto API** | ブラウザ内暗号化 |

### Kubernetes セキュリティ

| 機能 | 説明 |
|------|------|
| **ServiceAccount** | Pod のアイデンティティ |
| **Role/RoleBinding** | RBAC 権限管理 |
| **Secret** | 機密情報の管理 |
| **Security Context** | コンテナセキュリティ設定 |

## バージョン情報

### 現在のバージョン

```yaml
Helm Chart: v0.4.0
agentapi-proxy: v1.191.0
agentapi-ui: v1.97.0
```

### バージョニングスキーム

- **Semantic Versioning**: major.minor.patch
- **Chart Version**: 独立してバージョニング
- **Dependency Version**: Chart.lock でピン留め

## 開発言語別の依存関係

### TypeScript/JavaScript (Frontend)

```json
{
  "dependencies": {
    "next": "15.4.10",
    "react": "18.3.1",
    "typescript": "5.8.3",
    "tailwindcss": "3.4.1",
    "recharts": "3.0.0",
    "lucide-react": "0.525.0",
    "next-pwa": "5.6.0",
    "web-push": "3.6.7",
    "uuid": "11.1.0",
    "@vercel/analytics": "1.5.0"
  },
  "devDependencies": {
    "vitest": "2.1.8",
    "playwright": "1.53.2",
    "@testing-library/react": "16.0.1",
    "msw": "2.7.0"
  }
}
```

### Go (Backend)

```go
// 主要なパッケージ (推定)
- net/http (HTTP サーバー)
- k8s.io/client-go (Kubernetes クライアント)
- github.com/... (GitHub API クライアント)
- encoding/json (JSON 処理)
- crypto/* (暗号化)
```

## ビルド・デプロイツール

### Makefile (Frontend)

```makefile
targets:
  - install
  - build
  - lint
  - typecheck
  - test
  - dev
  - clean
  - docker-build
  - docker-push
  - helm-lint
  - helm-package
```

### Dockerfile

```dockerfile
Multi-stage Build:
  1. Base (Bun)
  2. Dependencies
  3. Build
  4. Runner (Non-root user)
```

## ネットワーク・プロトコル

| プロトコル | 用途 |
|-----------|------|
| **HTTP/HTTPS** | REST API |
| **WebSocket** | リアルタイム通信 |
| **Server-Sent Events (SSE)** | ストリーミングレスポンス |

## ポート番号

| サービス | ポート | 用途 |
|---------|-------|------|
| agentapi-ui | 3000 | Frontend HTTP |
| agentapi-proxy | 8080 | Backend API |
| agentapi-proxy | 9000 | Session Communication |
| OTEL Collector | 9090 | Metrics Export |
| OTEL Collector | 9464 | Claude Code Metrics |

## 互換性

### Kubernetes

- **最小バージョン**: Kubernetes 1.19+
- **テスト済み**: k3s (軽量 Kubernetes)

### Helm

- **必須バージョン**: v3.14.0+

### ブラウザ

- **モダンブラウザ**: Chrome, Firefox, Safari, Edge (最新版)
- **PWA サポート**: Chrome, Edge, Safari (iOS 16.4+)

## まとめ

ccplant の技術スタックは以下の特徴があります:

1. **モダンなフロントエンド**: Next.js 15 + React 18 + TypeScript
2. **パフォーマンス重視**: Bun による高速ビルド・実行
3. **Kubernetes ネイティブ**: コンテナオーケストレーションの完全活用
4. **包括的なテスト**: ユニット、統合、E2E テスト
5. **セキュアな設計**: 暗号化、RBAC、TLS
6. **CI/CD 自動化**: GitHub Actions による完全自動化

次のセクション:
- [バックエンド概要](../backend/overview.md)
- [フロントエンド概要](../frontend/overview.md)
