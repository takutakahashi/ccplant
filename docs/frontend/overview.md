# agentapi-ui 概要

## はじめに

agentapi-ui は、ccplant プロジェクトのフロントエンドコンポーネントで、AI エージェントとの対話インターフェースを提供する Next.js ベースの Progressive Web Application (PWA) です。agentapi-proxy バックエンドと連携し、セッション管理、リアルタイム通信、Kubernetes 上での AI エージェント実行を可能にします。

## 主要な特徴

### 1. モダンな技術スタック

- **Next.js 15.4.10**: App Router を使用した最新のフルスタック React フレームワーク
- **React 18.3.1**: 最新の React フックと Suspense サポート
- **TypeScript 5.8.3**: 型安全な開発環境
- **Tailwind CSS 3.4.1**: ユーティリティファーストの CSS フレームワーク
- **Bun 1.2.16**: 高速なパッケージマネージャーとランタイム

### 2. Progressive Web App (PWA)

- **オフラインサポート**: Service Worker によるオフライン機能
- **インストール可能**: ホーム画面への追加でネイティブアプリのような体験
- **プッシュ通知**: Web Push API による通知機能
- **マニフェスト設定**: カスタマイズ可能な PWA マニフェスト
- **next-pwa 5.6.0**: Next.js 向け PWA プラグイン

### 3. セッション管理

- **Kubernetes ベースのセッション**: Pod として実行される AI エージェント
- **リアルタイム通信**: WebSocket/SSE によるストリーミング応答
- **セッション一覧**: アクティブ・完了したセッションの管理
- **チャット履歴**: 永続化されたメッセージ履歴の表示
- **共有機能**: セッションの共有トークン生成

### 4. セキュアな認証

- **複数の認証方式**:
  - GitHub OAuth 認証
  - API キー認証
  - ハイブリッドモード（両方をサポート）
- **Cookie 暗号化**: AES-256-GCM による Cookie の暗号化
- **セキュアヘッダー**: CSP、X-Frame-Options などのセキュリティヘッダー
- **トークン管理**: 暗号化された認証トークンの安全な保存

### 5. 充実した機能セット

#### エージェント管理
- エージェント一覧の表示
- エージェントステータスのモニタリング
- エージェント設定の管理

#### スケジュール機能
- 定期実行スケジュールの作成・管理
- Cron 式によるスケジュール設定
- スケジュール実行履歴の確認

#### Webhook 機能
- Webhook エンドポイントの作成・管理
- Webhook シークレットの生成・再生成
- Webhook 実行履歴とログの表示

#### 設定管理
- 個人設定とチーム設定の分離
- GitHub トークン設定
- Claude OAuth 設定
- Bedrock 設定
- MCP サーバー設定
- プラグイン設定
- 実験的機能の設定

### 6. モバイルファーストデザイン

- **レスポンシブ UI**: すべての画面サイズに対応
- **タッチ最適化**: モバイルデバイスでの快適な操作
- **動的ビューポート**: dvh（Dynamic Viewport Height）の使用
- **プルトゥリフレッシュ**: モバイルネイティブな操作感
- **ページ可視性 API**: バックグラウンド時の処理最適化

### 7. リアルタイム機能

- **ストリーミング応答**: SSE/WebSocket による AI 応答のストリーミング表示
- **自動更新**: セッションステータスの自動更新
- **プッシュ通知**: セッション完了やエラーの通知
- **ライブログ**: リアルタイムでのログ表示

## アーキテクチャハイライト

### クライアントアーキテクチャ

```
┌─────────────────────────────────────────────┐
│           agentapi-ui (Next.js)              │
├─────────────────────────────────────────────┤
│  App Router (src/app/)                       │
│  ├─ Pages (page.tsx)                         │
│  ├─ API Routes (api/)                        │
│  ├─ Components (components/)                 │
│  └─ Layouts (layout.tsx)                     │
├─────────────────────────────────────────────┤
│  Contexts (src/contexts/)                    │
│  ├─ ThemeContext                             │
│  ├─ TeamScopeContext                         │
│  └─ ToastContext                             │
├─────────────────────────────────────────────┤
│  Libraries (src/lib/)                        │
│  ├─ agentapi-proxy-client.ts                 │
│  ├─ cookie-encryption.ts                     │
│  ├─ api.ts                                   │
│  └─ subscriptions.ts                         │
├─────────────────────────────────────────────┤
│  Utilities (src/utils/)                      │
│  ├─ pushNotification.ts                      │
│  ├─ messageTemplateManager.ts                │
│  └─ timeUtils.ts                             │
└─────────────────────────────────────────────┘
```

### 通信フロー

```
[Browser]
   │
   ├─ HTTP/HTTPS ────────────────┐
   │                             │
   ├─ WebSocket/SSE ─────────────┤
   │                             │
   └─ Web Push API              │
                                 ▼
                    ┌────────────────────────┐
                    │   Next.js API Routes   │
                    │   /api/proxy/[...path] │
                    └────────────┬───────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │   agentapi-proxy       │
                    │   (Backend)            │
                    └────────────┬───────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │   Kubernetes Cluster   │
                    │   (AI Agent Pods)      │
                    └────────────────────────┘
```

## ポート設定

- **開発環境**: ポート 3000（`bun run dev`）
- **本番環境**: ポート 3000（`bun run start`）
- **カスタマイズ**: 環境変数 `PORT` で変更可能

## デプロイメントオプション

### 1. スタンドアロン
```bash
bun run build
bun run start
```

### 2. Docker コンテナ
```bash
docker build -t agentapi-ui .
docker run -p 3000:3000 agentapi-ui
```

### 3. Kubernetes (Helm Chart)
```bash
helm install ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --set global.hostname=example.com
```

## 主要な依存関係

### プロダクション依存関係

```json
{
  "next": "15.4.10",
  "react": "18.3.1",
  "react-dom": "18.3.1",
  "typescript": "5.8.3",
  "next-pwa": "5.6.0",
  "lucide-react": "0.525.0",
  "recharts": "3.0.0",
  "uuid": "11.1.0",
  "web-push": "3.6.7"
}
```

### 開発依存関係

```json
{
  "@playwright/test": "1.53.2",
  "@testing-library/react": "16.0.1",
  "vitest": "2.1.8",
  "tailwindcss": "3.4.1",
  "msw": "2.7.0"
}
```

## ブラウザサポート

- **モダンブラウザ**: Chrome/Edge 90+、Firefox 88+、Safari 14+
- **モバイルブラウザ**: iOS Safari 14+、Chrome Mobile 90+
- **PWA サポート**: Service Worker 対応ブラウザ
- **プッシュ通知**: Web Push API 対応ブラウザ

## パフォーマンス特性

- **初回ロード**: 最適化された Next.js バンドルで高速ロード
- **コード分割**: ページ単位の自動コード分割
- **画像最適化**: Next.js Image コンポーネントによる自動最適化
- **SSR/SSG**: 静的生成とサーバーサイドレンダリングの併用
- **キャッシング**: Service Worker によるアセットキャッシング

## セキュリティ機能

1. **Cookie 暗号化**: AES-256-GCM による認証情報の暗号化
2. **CSP ヘッダー**: Content Security Policy による XSS 対策
3. **HTTPS 強制**: 本番環境での HTTPS 必須
4. **CSRF 対策**: SameSite Cookie 属性の使用
5. **セキュアヘッダー**: X-Frame-Options、X-Content-Type-Options など

## 開発体験

### ホットリロード
```bash
bun run dev
# http://localhost:3000 で起動
```

### 型チェック
```bash
bun run type-check
```

### リント
```bash
bun run lint
```

### テスト
```bash
# ユニットテスト
bun run test

# E2E テスト
bun run e2e

# テスト UI
bun run test:ui
```

## 次のステップ

- [アーキテクチャ](./architecture.md) - 詳細なアーキテクチャ設計
- [機能と UI](./features.md) - 主要機能の詳細
- [ページとルーティング](./pages-routing.md) - ページ構造とルーティング
- [API 統合](./api-integration.md) - バックエンド API との統合
- [設定リファレンス](./configuration.md) - 環境変数と設定
- [セキュリティ](./security.md) - セキュリティ実装の詳細
- [PWA 機能](./pwa.md) - Progressive Web App 機能

## リポジトリ情報

- **GitHub**: [takutakahashi/agentapi-ui](https://github.com/takutakahashi/agentapi-ui)
- **バージョン**: v1.19.0
- **ライセンス**: リポジトリの LICENSE ファイルを参照
- **パッケージマネージャー**: Bun 1.2.16

## サポートとフィードバック

問題が発生した場合や機能リクエストがある場合は、以下のリソースをご利用ください：

1. [GitHub Issues](https://github.com/takutakahashi/agentapi-ui/issues)
2. [ccplant ドキュメント](../README.md)
3. [トラブルシューティングガイド](../deployment/troubleshooting.md)
