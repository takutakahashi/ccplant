# 認証とアクセス

## 概要

ccplant は柔軟な認証システムを提供し、GitHub OAuth、API キー、Cookie ベース認証をサポートします。組織のセキュリティポリシーに合わせて認証方式を選択・設定できます。

## ログイン方法

### 1. GitHub OAuth

**推奨方法:** ユーザー認証の標準的な方式

**手順:**
1. ログインページで「GitHub でログイン」をクリック
2. GitHub 認証ページにリダイレクト
3. 権限を確認して「Authorize」をクリック
4. ccplant にリダイレクトされ、ログイン完了

**必要な権限:**
- `read:user` - ユーザー基本情報
- `read:org` - 組織・チーム情報 (RBAC 用)
- `repo` - リポジトリアクセス (オプション)

### 2. API キー

**用途:** プログラムからのアクセス、CI/CD

**取得方法:**
1. 設定画面 → API キー
2. 「新規 API キー」をクリック
3. 名前と有効期限を設定
4. API キーが表示される (一度のみ)

**使用方法:**
```bash
curl https://cc-api.example.com/api/v1/sessions \
  -H "X-API-Key: ${API_KEY}"
```

**セキュリティ:**
- API キーは安全に保管
- 定期的にローテーション
- 使用しないキーは削除

### 3. Cookie ベース認証

**動作:** OAuth ログイン後、セッション Cookie が発行される

**特徴:**
- HttpOnly フラグ付き (XSS 対策)
- Secure フラグ付き (HTTPS のみ)
- SameSite=Strict (CSRF 対策)

**有効期限:** 30 日 (設定可能)

## AUTH_MODE 設定

管理者は、組織の認証ポリシーに応じて認証モードを設定できます。

### 利用可能なモード

#### 1. both (デフォルト)

```yaml
AUTH_MODE: both
```

**動作:**
- GitHub OAuth と API キーの両方を許可
- ユーザーは好きな方法でログイン可能

**推奨環境:**
- 開発環境
- 柔軟性が必要な環境

#### 2. api_key

```yaml
AUTH_MODE: api_key
```

**動作:**
- API キー認証のみ許可
- OAuth ログインは無効

**推奨環境:**
- 自動化システム
- CI/CD パイプライン
- サービス間通信

#### 3. oauth_only

```yaml
AUTH_MODE: oauth_only
```

**動作:**
- GitHub OAuth のみ許可
- API キーは無効

**推奨環境:**
- 本番環境
- ユーザー認証を厳密に管理したい環境
- 監査ログが必要な環境

### Helm での設定

```yaml
# values.yaml
agentapi-proxy:
  env:
    - name: AUTH_MODE
      value: "oauth_only"
```

## GitHub OAuth セットアップ

### ユーザー向け

#### Personal Access Token (PAT) の作成

1. GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. "Generate new token" をクリック
3. 以下のスコープを選択:
   - `repo` - リポジトリアクセス
   - `read:org` - 組織情報
   - `workflow` - GitHub Actions (オプション)
4. "Generate token" をクリック
5. トークンをコピーして保存

#### ccplant での使用

```bash
# トークンを使用してログイン
export GITHUB_TOKEN="ghp_xxxxx"

# API リクエスト
curl https://cc-api.example.com/api/v1/sessions \
  -H "Authorization: Bearer ${GITHUB_TOKEN}"
```

### 管理者向け

#### OAuth App の作成

1. GitHub Settings → Developer settings → OAuth Apps
2. "New OAuth App" をクリック
3. 以下を入力:
   - Application name: `ccplant`
   - Homepage URL: `https://cc.example.com`
   - Authorization callback URL: `https://cc.example.com/api/auth/callback/github`
4. Client ID と Client Secret をメモ

#### Helm での設定

```yaml
# values.yaml
global:
  github:
    oauth:
      clientId: "Iv1.xxxxxxxxxxxxxxxx"
      clientSecret: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

**セキュリティ:** Secret を使用して管理することを推奨

```bash
kubectl create secret generic github-oauth \
  --from-literal=client-id=YOUR_CLIENT_ID \
  --from-literal=client-secret=YOUR_CLIENT_SECRET
```

## API キー管理

### キーの作成

```bash
# API でキーを作成
curl -X POST https://cc-api.example.com/api/v1/api-keys \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -d '{
    "name": "CI Pipeline",
    "expires_in_days": 90
  }'
```

**レスポンス:**
```json
{
  "api_key_id": "key-123",
  "name": "CI Pipeline",
  "key": "ccplant_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "expires_at": "2024-04-26T12:00:00Z",
  "created_at": "2024-01-27T12:00:00Z"
}
```

### キーの一覧

```bash
curl https://cc-api.example.com/api/v1/api-keys \
  -H "Authorization: Bearer ${GITHUB_TOKEN}"
```

### キーの無効化

```bash
curl -X DELETE https://cc-api.example.com/api/v1/api-keys/{key_id} \
  -H "Authorization: Bearer ${GITHUB_TOKEN}"
```

## セッション永続化

### Cookie 設定

```yaml
# values.yaml
agentapi-ui:
  session:
    cookie_max_age: 2592000  # 30 日
    cookie_secure: true
    cookie_http_only: true
    cookie_same_site: "Strict"
```

### セッション更新

自動更新により、ユーザーは再ログイン不要:

```
Cookie 有効期限の 50% 経過
    ↓
自動的にセッションを更新
    ↓
新しい Cookie を発行
```

## Single Sign-On (SSO)

### SAML 統合 (Enterprise)

```yaml
# values.yaml
agentapi-proxy:
  saml:
    enabled: true
    entity_id: "https://cc.example.com"
    idp_metadata_url: "https://idp.example.com/metadata"
```

### OIDC 統合 (Enterprise)

```yaml
# values.yaml
agentapi-proxy:
  oidc:
    enabled: true
    issuer: "https://accounts.google.com"
    client_id: "xxxxx.apps.googleusercontent.com"
    client_secret: "xxxxx"
```

## トラブルシューティング

### ログインできない

**症状:** GitHub ログイン後、エラーが表示される

**対処:**
1. OAuth App の Callback URL を確認
2. Client ID と Secret を確認
3. ブラウザのクッキーをクリア

### API キーが動作しない

**症状:** API キーでリクエストすると 401 エラー

**対処:**
1. API キーの有効期限を確認
2. AUTH_MODE 設定を確認
3. ヘッダー名を確認 (`X-API-Key`)

### セッションが頻繁に切れる

**症状:** 短時間で再ログインが必要

**対処:**
1. Cookie の有効期限を確認
2. ブラウザの Cookie 設定を確認
3. HTTPS を使用しているか確認

## セキュリティベストプラクティス

### 1. HTTPS を使用

本番環境では必ず HTTPS を使用してください。

### 2. OAuth スコープを最小化

必要最小限のスコープのみを要求します。

### 3. API キーのローテーション

定期的に API キーを更新します (推奨: 90 日ごと)。

### 4. 監査ログ

すべての認証イベントを記録します。

```json
{
  "timestamp": "2024-01-27T12:00:00Z",
  "event": "login_success",
  "user": "username",
  "method": "github_oauth",
  "ip": "192.0.2.1"
}
```

## まとめ

ccplant は柔軟な認証システムにより、セキュアなアクセス制御を実現します。組織のポリシーに合わせて適切な認証方式を選択してください。

### 次のステップ

- [権限管理](./permissions.md) - ユーザーとチームの権限設定
- [設定管理](./settings.md) - 認証設定のカスタマイズ
- [セキュリティ](../operations/security.md) - セキュリティベストプラクティス
