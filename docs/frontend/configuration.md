# 設定リファレンス

## 概要

このドキュメントでは、agentapi-ui の設定オプション、環境変数、カスタマイズ方法について詳しく説明します。

## 環境変数

### 必須環境変数

#### COOKIE_SECRET

Cookie 暗号化のためのシークレットキー。

```bash
COOKIE_SECRET=your-secure-cookie-secret-at-least-32-characters-long
```

**要件**:
- 最低 32 文字以上
- ランダムで推測困難な文字列
- 本番環境では必ず変更すること

**生成方法**:
```bash
# OpenSSL を使用
openssl rand -base64 32

# または Node.js を使用
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
```

**重要**: このキーを変更すると、既存のすべての Cookie が無効になります。

#### AGENTAPI_PROXY_URL

agentapi-proxy バックエンドの URL。

```bash
AGENTAPI_PROXY_URL=http://localhost:8080
```

**例**:
- ローカル開発: `http://localhost:8080`
- Docker Compose: `http://agentapi-proxy:8080`
- Kubernetes: `http://ccplant-agentapi-proxy:8080`
- 本番環境: `https://api.example.com`

### 認証設定

#### AUTH_MODE

認証方式の設定。

```bash
AUTH_MODE=both
```

**オプション**:
- `both`: API キーと OAuth の両方を許可（デフォルト）
- `api_key`: API キー認証のみ
- `oauth_only`: OAuth 認証のみ

**使用例**:
```bash
# OAuth のみを使用する場合
AUTH_MODE=oauth_only

# API キーのみを使用する場合
AUTH_MODE=api_key
```

#### 後方互換性

以前の `NEXT_PUBLIC_OAUTH_ONLY_MODE` もサポートされています。

```bash
# 古い設定（非推奨だがサポート）
NEXT_PUBLIC_OAUTH_ONLY_MODE=true
# 新しい設定に相当
AUTH_MODE=oauth_only
```

### ログインページカスタマイズ

#### LOGIN_TITLE

ログインページのタイトル。

```bash
LOGIN_TITLE=AgentAPI UI
```

**デフォルト**: `AgentAPI UI`

#### LOGIN_DESCRIPTION

ログインページの説明文。

```bash
LOGIN_DESCRIPTION="Enter your API key or sign in with GitHub to continue."
```

**デフォルト**: `Enter your API key or sign in with GitHub to continue.`

#### LOGIN_SUB_DESCRIPTION

ログインページのサブテキスト。

```bash
LOGIN_SUB_DESCRIPTION="API key can be any valid authentication token for your AgentAPI service."
```

**デフォルト**: `API key can be any valid authentication token for your AgentAPI service.`

### UI カスタマイズ

#### FAVICON_URL

カスタムファビコンの URL。

```bash
FAVICON_URL=https://example.com/favicon.ico
```

**要件**:
- 有効な画像 URL
- HTTPS 推奨
- ICO、PNG、SVG 形式をサポート

**デフォルト**: `/favicon.ico`（内蔵アイコン）

### PWA 設定

#### PWA_APP_NAME

PWA のアプリケーション名。

```bash
PWA_APP_NAME="AgentAPI UI"
```

**使用場所**:
- PWA マニフェスト
- インストールプロンプト
- ホーム画面のアイコン名

**デフォルト**: `AgentAPI UI`

#### PWA_SHORT_NAME

PWA の短縮名。

```bash
PWA_SHORT_NAME=AgentAPI
```

**使用場所**:
- ホーム画面のアイコン下のラベル
- 限られたスペースでの表示

**デフォルト**: `AgentAPI`

**推奨**: 12 文字以内

#### PWA_DESCRIPTION

PWA の説明。

```bash
PWA_DESCRIPTION="User interface for AgentAPI - AI agent conversation management"
```

**デフォルト**: `User interface for AgentAPI - AI agent conversation management`

#### PWA_ICON_URL

カスタム PWA アイコンの URL。

```bash
PWA_ICON_URL=https://example.com/icon.png
```

**要件**:
- PNG 形式推奨
- 512x512 ピクセル以上
- 正方形
- HTTPS 推奨

**デフォルト**: 内蔵アイコン（`/icon-*.png`）

### プッシュ通知設定

#### VAPID_PUBLIC_KEY / NEXT_PUBLIC_VAPID_PUBLIC_KEY

プッシュ通知用の VAPID 公開鍵。

```bash
# ランタイム設定（推奨）
VAPID_PUBLIC_KEY=BOv-qOWAZ4--eLYAQNk-0jZPDGHH3rrmb4RFaQglVpdz_zQrS5wH1puNS4aWoWSDnRbPO764YURRZt8_B2OMkDQ

# ビルドタイム設定（代替）
NEXT_PUBLIC_VAPID_PUBLIC_KEY=BOv-qOWAZ4--eLYAQNk-0jZPDGHH3rrmb4RFaQglVpdz_zQrS5wH1puNS4aWoWSDnRbPO764YURRZt8_B2OMkDQ
```

**生成方法**:
```bash
# VAPID キーペアを生成
npx web-push generate-vapid-keys

# 出力例:
# =============== VAPID keys ===============
# Public Key: BOv-qOWAZ4--eLYAQNk-0jZPDGHH3rrmb4RFaQglVpdz_zQrS5wH1puNS4aWoWSDnRbPO764YURRZt8_B2OMkDQ
# Private Key: mDe1TZnHJAshXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# ==========================================
```

**重要**:
- **公開鍵のみ**を設定すること
- プライベートキーは絶対に公開しない
- プライベートキーはサーバー側で使用

#### VAPID_PRIVATE_KEY

プッシュ通知用の VAPID プライベートキー（サーバー側のみ）。

```bash
VAPID_PRIVATE_KEY=mDe1TZnHJAshXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

**重要**:
- サーバー側でのみ使用
- 絶対にクライアントに露出しない
- 安全に保管すること

### Next.js 設定

#### NEXT_PUBLIC_BASE_URL

アプリケーションのベース URL。

```bash
NEXT_PUBLIC_BASE_URL=http://localhost:3000
```

**例**:
- ローカル開発: `http://localhost:3000`
- 本番環境: `https://app.example.com`

**使用場所**:
- OAuth リダイレクト URI
- Webhook URL 生成
- 絶対 URL が必要な場所

#### NODE_ENV

実行環境。

```bash
NODE_ENV=production
```

**オプション**:
- `development`: 開発環境
- `production`: 本番環境
- `test`: テスト環境

#### PORT

サーバーのポート番号。

```bash
PORT=3000
```

**デフォルト**: `3000`

### デバッグ設定

#### AGENTAPI_DEBUG

デバッグモードの有効化。

```bash
AGENTAPI_DEBUG=true
```

**効果**:
- 詳細なログ出力
- API リクエスト/レスポンスのログ
- エラーの詳細表示

**本番環境**: 必ず `false` に設定すること

## 設定ファイル

### .env ファイル

ローカル開発用の環境変数設定。

```bash
# .env.local
# AgentAPI Proxy Configuration
AGENTAPI_PROXY_URL=http://localhost:8080

# Cookie Encryption Secret (REQUIRED)
COOKIE_SECRET=your-secure-cookie-secret-at-least-32-characters-long

# Authentication Configuration
AUTH_MODE=both
LOGIN_TITLE=AgentAPI UI
LOGIN_DESCRIPTION=Enter your API key or sign in with GitHub to continue.

# Next.js Configuration
NEXT_PUBLIC_BASE_URL=http://localhost:3000
NODE_ENV=development

# PWA Configuration
PWA_APP_NAME=AgentAPI UI
PWA_SHORT_NAME=AgentAPI

# Push Notifications
VAPID_PUBLIC_KEY=BOv-qOWAZ4--eLYAQNk-0jZPDGHH3rrmb4RFaQglVpdz_zQrS5wH1puNS4aWoWSDnRbPO764YURRZt8_B2OMkDQ
VAPID_PRIVATE_KEY=mDe1TZnHJAshXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Debug
AGENTAPI_DEBUG=true
```

### Next.js Config

`next.config.js` での設定。

```javascript
const withPWA = require('next-pwa')({
  dest: 'public',
  register: true,
  skipWaiting: true,
  disable: process.env.NODE_ENV === 'development',
  fallbacks: {
    document: '/offline',
  },
  publicExcludes: ['!manifest.json'],
  buildExcludes: [/manifest\.json$/],
})

/** @type {import('next').NextConfig} */
const nextConfig = {
  env: {
    AGENTAPI_DEBUG: process.env.AGENTAPI_DEBUG || '',
  },
  output: 'standalone',
  images: {
    domains: ['avatars.githubusercontent.com'],
  },
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          {
            key: 'X-Frame-Options',
            value: 'DENY',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'Referrer-Policy',
            value: 'strict-origin-when-cross-origin',
          },
          {
            key: 'Content-Security-Policy',
            value: "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https:; font-src 'self' data:; object-src 'none'; base-uri 'self';",
          },
        ],
      },
    ];
  },
}

module.exports = withPWA(nextConfig)
```

## デプロイメント別設定

### Docker

Dockerfile で環境変数を設定。

```dockerfile
FROM node:20-alpine AS base

# 依存関係のインストール
FROM base AS deps
WORKDIR /app
COPY package.json bun.lockb ./
RUN bun install --frozen-lockfile

# ビルド
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# 環境変数をビルド時に設定（オプション）
ARG NEXT_PUBLIC_BASE_URL
ENV NEXT_PUBLIC_BASE_URL=${NEXT_PUBLIC_BASE_URL}

RUN bun run build

# 実行
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

# 実行時環境変数
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

EXPOSE 3000

CMD ["node", "server.js"]
```

**実行時の環境変数設定**:
```bash
docker run -p 3000:3000 \
  -e COOKIE_SECRET="your-secret-key" \
  -e AGENTAPI_PROXY_URL="http://agentapi-proxy:8080" \
  -e AUTH_MODE="both" \
  agentapi-ui
```

### Docker Compose

`docker-compose.yaml` で環境変数を設定。

```yaml
version: '3.8'

services:
  agentapi-ui:
    image: agentapi-ui:latest
    ports:
      - "3000:3000"
    environment:
      # 必須設定
      COOKIE_SECRET: ${COOKIE_SECRET}
      AGENTAPI_PROXY_URL: http://agentapi-proxy:8080

      # 認証設定
      AUTH_MODE: both
      LOGIN_TITLE: "AgentAPI UI"

      # PWA 設定
      PWA_APP_NAME: "AgentAPI UI"
      PWA_SHORT_NAME: "AgentAPI"

      # プッシュ通知
      VAPID_PUBLIC_KEY: ${VAPID_PUBLIC_KEY}
      VAPID_PRIVATE_KEY: ${VAPID_PRIVATE_KEY}

      # Next.js 設定
      NEXT_PUBLIC_BASE_URL: http://localhost:3000
      NODE_ENV: production

    depends_on:
      - agentapi-proxy
```

**.env ファイル**:
```bash
COOKIE_SECRET=your-secure-cookie-secret-at-least-32-characters-long
VAPID_PUBLIC_KEY=BOv-qOWAZ4--eLYAQNk-0jZPDGHH3rrmb4RFaQglVpdz_zQrS5wH1puNS4aWoWSDnRbPO764YURRZt8_B2OMkDQ
VAPID_PRIVATE_KEY=mDe1TZnHJAshXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### Kubernetes / Helm

Helm の `values.yaml` で設定。

```yaml
# values.yaml
agentapi-ui:
  image:
    repository: ghcr.io/takutakahashi/agentapi-ui
    tag: v1.97.0

  env:
    # 必須設定
    - name: COOKIE_SECRET
      valueFrom:
        secretKeyRef:
          name: agentapi-ui-secrets
          key: cookie-secret

    - name: AGENTAPI_PROXY_URL
      value: "http://{{ .Release.Name }}-agentapi-proxy:8080"

    # 認証設定
    - name: AUTH_MODE
      value: "both"

    - name: LOGIN_TITLE
      value: "AgentAPI UI"

    # PWA 設定
    - name: PWA_APP_NAME
      value: "AgentAPI UI"

    - name: PWA_SHORT_NAME
      value: "AgentAPI"

    # プッシュ通知
    - name: VAPID_PUBLIC_KEY
      valueFrom:
        secretKeyRef:
          name: agentapi-ui-secrets
          key: vapid-public-key

    - name: VAPID_PRIVATE_KEY
      valueFrom:
        secretKeyRef:
          name: agentapi-ui-secrets
          key: vapid-private-key

    # Next.js 設定
    - name: NEXT_PUBLIC_BASE_URL
      value: "https://{{ .Values.global.hostname }}"

    - name: NODE_ENV
      value: "production"
```

**Secret の作成**:
```bash
kubectl create secret generic agentapi-ui-secrets \
  --from-literal=cookie-secret="your-secure-cookie-secret" \
  --from-literal=vapid-public-key="BOv-qOWAZ4..." \
  --from-literal=vapid-private-key="mDe1TZnH..."
```

### Vercel

Vercel のダッシュボードまたは CLI で環境変数を設定。

**ダッシュボード**:
1. プロジェクト設定 → Environment Variables
2. 以下の変数を追加:
   - `COOKIE_SECRET`
   - `AGENTAPI_PROXY_URL`
   - `AUTH_MODE`
   - その他の必要な変数

**CLI**:
```bash
# .env.production.local
COOKIE_SECRET=your-secure-cookie-secret
AGENTAPI_PROXY_URL=https://api.example.com

# デプロイ
vercel --prod
```

## ランタイム設定 API

### /api/config エンドポイント

クライアント側から設定を取得するための API。

**リクエスト**:
```
GET /api/config
```

**レスポンス**:
```json
{
  "authMode": "both",
  "loginTitle": "AgentAPI UI",
  "loginDescription": "Enter your API key or sign in with GitHub to continue.",
  "loginSubDescription": "API key can be any valid authentication token.",
  "oauthProviders": ["github"],
  "vapidPublicKey": "BOv-qOWAZ4--eLYAQNk-0jZPDGHH3rrmb4RFaQglVpdz_zQrS5wH1puNS4aWoWSDnRbPO764YURRZt8_B2OMkDQ",
  "faviconUrl": "https://example.com/favicon.ico"
}
```

**使用例**:
```typescript
const { config, loading } = useConfig();

if (loading) return <LoadingSpinner />;

return (
  <div>
    <h1>{config.loginTitle}</h1>
    {config.authMode !== 'oauth_only' && <ApiKeyForm />}
    {config.authMode !== 'api_key' && <OAuthButtons />}
  </div>
);
```

## セキュリティ設定

### Cookie セキュリティ

```typescript
{
  httpOnly: true,              // JavaScript からアクセス不可
  secure: NODE_ENV === 'production', // HTTPS のみ
  sameSite: 'lax',             // CSRF 対策
  path: '/',                   // すべてのパスで有効
  maxAge: 86400,               // 24時間
}
```

### セキュリティヘッダー

```typescript
{
  'X-Frame-Options': 'DENY',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Content-Security-Policy': "default-src 'self'; ...",
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
}
```

## トラブルシューティング

### よくある設定エラー

#### 1. Cookie 暗号化エラー

```
Error: COOKIE_SECRET must be at least 32 characters long
```

**解決方法**:
```bash
# 十分に長いシークレットを生成
openssl rand -base64 32
```

#### 2. CORS エラー

```
Access to fetch at 'http://localhost:8080/v1/sessions' has been blocked by CORS policy
```

**解決方法**:
- API Routes プロキシを使用（`/api/proxy/*`）
- または agentapi-proxy で CORS を設定

#### 3. 認証エラー

```
401 Unauthorized
```

**確認事項**:
- `COOKIE_SECRET` が正しく設定されているか
- Cookie が正しく保存されているか
- API キーが有効か

#### 4. プッシュ通知エラー

```
Invalid VAPID_PUBLIC_KEY format
```

**解決方法**:
- VAPID キーが Base64URL 形式か確認
- 正しいキーペアを使用しているか確認

## 次のステップ

- [セキュリティ](./security.md) - セキュリティ設定の詳細
- [API 統合](./api-integration.md) - API 設定の詳細
- [PWA 機能](./pwa.md) - PWA 設定の詳細
