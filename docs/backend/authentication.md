# 認証と認可

## 概要

agentapi-proxy は多層的な認証・認可システムを実装しており、GitHub OAuth、GitHub App、静的 API キーをサポートします。ロールベースアクセス制御 (RBAC) により、きめ細かい権限管理を実現します。

## 認証方式

### 1. GitHub OAuth 2.0

#### 概要
ユーザー認証の主要な方式です。GitHub の Personal Access Token または OAuth アプリケーションフローを使用します。

#### 設定

**環境変数**
```yaml
AGENTAPI_AUTH_ENABLED: "true"
AGENTAPI_AUTH_GITHUB_ENABLED: "true"
AGENTAPI_AUTH_GITHUB_BASE_URL: "https://api.github.com"
AGENTAPI_AUTH_GITHUB_TOKEN_HEADER: "Authorization"
AGENTAPI_AUTH_GITHUB_OAUTH_CLIENT_ID: "Iv1.xxxxxxxxxxxxxxxx"
AGENTAPI_AUTH_GITHUB_OAUTH_CLIENT_SECRET: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
AGENTAPI_AUTH_GITHUB_OAUTH_SCOPE: "read:user read:org repo workflow"
```

**GitHub Enterprise の場合**
```yaml
# values.yaml
global:
  github:
    enterprise:
      enabled: true
      baseUrl: "https://github.example.com"
    oauth:
      clientId: "Iv1.xxxxxxxxxxxxxxxx"
      clientSecret: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

#### 認証フロー

```
1. ユーザーがフロントエンド UI にアクセス
   │
   ▼
2. フロントエンドが OAuth 開始エンドポイントにリダイレクト
   GET /api/v1/github/oauth/authorize?redirect_uri=https://cc-dev.example.com/callback
   │
   ▼
3. agentapi-proxy が GitHub OAuth ページにリダイレクト
   https://github.com/login/oauth/authorize?
     client_id={client_id}&
     scope=read:user read:org repo workflow&
     state={csrf_token}
   │
   ▼
4. ユーザーが GitHub で認証・認可
   │
   ▼
5. GitHub が agentapi-proxy のコールバックにリダイレクト
   GET /api/v1/github/oauth/callback?code={auth_code}&state={csrf_token}
   │
   ▼
6. agentapi-proxy がアクセストークンを取得
   POST https://github.com/login/oauth/access_token
   {
     "client_id": "{client_id}",
     "client_secret": "{client_secret}",
     "code": "{auth_code}"
   }
   │
   ▼
7. セッションクッキーを設定してフロントエンドにリダイレクト
   Set-Cookie: session={encrypted_token}; HttpOnly; Secure; SameSite=Strict
   Location: https://cc-dev.example.com/callback
   │
   ▼
8. 以降のリクエストはセッションクッキーまたは Authorization ヘッダーで認証
   Authorization: Bearer {github_token}
```

#### トークンスコープ

| スコープ | 用途 |
|---------|------|
| `read:user` | ユーザー基本情報の取得 |
| `read:org` | 組織・チーム情報の取得 (RBAC用) |
| `repo` | リポジトリアクセス (セッション内での Git 操作用) |
| `workflow` | GitHub Actions ワークフロー操作 (オプション) |

#### トークン検証

リクエストごとに以下の検証を実行:

```go
// 1. トークンの存在確認
token := extractTokenFromRequest(req)
if token == "" {
    return ErrUnauthorized
}

// 2. GitHub API でトークン検証
user, err := githubClient.GetUser(token)
if err != nil {
    return ErrInvalidToken
}

// 3. ユーザー情報をコンテキストに設定
ctx := context.WithValue(req.Context(), "user", user)
```

---

### 2. GitHub App

#### 概要
GitHub App による高度な統合と権限管理を提供します。ユーザー認証と組織レベルの権限管理を組み合わせることができます。

#### GitHub App の作成

1. GitHub 組織設定で新しい GitHub App を作成
2. 必要な権限を設定:
   - **Repository permissions**:
     - Contents: Read & Write
     - Metadata: Read
     - Pull requests: Read & Write
   - **Organization permissions**:
     - Members: Read
3. Private Key を生成してダウンロード

#### 設定

**Secret の作成**
```bash
# Private Key を Secret に保存
kubectl create secret generic github-app \
  --from-file=private-key=/path/to/github-app.pem \
  --namespace=default
```

**環境変数**
```yaml
# GitHub App ID
GITHUB_APP_ID: "123456"

# Private Key の場所
GITHUB_APP_PEM_PATH: "/etc/github-app/private-key"

# または環境変数で直接指定
GITHUB_APP_PEM: |
  -----BEGIN RSA PRIVATE KEY-----
  ...
  -----END RSA PRIVATE KEY-----
```

**Helm 設定**
```yaml
# values.yaml
agentapi-proxy:
  github:
    app:
      id: "123456"
      privateKey:
        secretName: github-app
        key: private-key
```

#### 認証フロー

```
1. ユーザーが GitHub OAuth で認証
   │
   ▼
2. agentapi-proxy がユーザーの GitHub App インストール状態を確認
   GET /user/installations (GitHub App as User)
   │
   ▼
3. Installation Access Token を取得
   POST /app/installations/{installation_id}/access_tokens
   Headers:
     Authorization: Bearer {jwt_token}  # App JWT
   │
   ▼
4. Installation Token を使用して GitHub API にアクセス
   - より高い Rate Limit
   - より詳細な監査ログ
   - 組織レベルの権限管理
```

#### JWT 生成

```go
import (
    "time"
    "github.com/golang-jwt/jwt/v5"
)

func generateAppJWT(appID string, privateKey []byte) (string, error) {
    now := time.Now()
    claims := jwt.MapClaims{
        "iat": now.Unix(),
        "exp": now.Add(10 * time.Minute).Unix(),
        "iss": appID,
    }

    token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
    key, _ := jwt.ParseRSAPrivateKeyFromPEM(privateKey)
    return token.SignedString(key)
}
```

---

### 3. 静的 API キー

#### 概要
システム間通信や自動化スクリプト用の認証方式です。

#### 設定

**Secret の作成**
```bash
# API キーを生成
API_KEY=$(openssl rand -hex 32)

# Secret に保存
kubectl create secret generic agentapi-static-keys \
  --from-literal=ci-key="${API_KEY}" \
  --namespace=default
```

**環境変数**
```yaml
AGENTAPI_AUTH_STATIC_ENABLED: "true"
AGENTAPI_AUTH_STATIC_HEADER_NAME: "X-API-Key"
AGENTAPI_AUTH_STATIC_KEYS_SECRET: "agentapi-static-keys"
```

#### 使用方法

```bash
curl -X POST https://cc-api.example.com/api/v1/sessions \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"name": "ci-session"}'
```

#### セキュリティ考慮事項

- API キーは Secret で管理
- キーのローテーションを定期的に実施
- 用途ごとに異なるキーを発行
- IP ホワイトリストと併用推奨

---

## 認可 (Authorization)

### ロールベースアクセス制御 (RBAC)

#### 設定ファイル

```yaml
# /etc/auth-config/auth-config.yaml
github:
  user_mapping:
    # デフォルトロールとパーミッション
    default_role: "user"
    default_permissions:
      - "session:create"
      - "session:list"
      - "session:delete"
      - "session:access"

    # チームごとのロールマッピング
    team_role_mapping:
      # engineering チームには admin ロール
      "my-org/engineering":
        role: "admin"
        permissions:
          - "session:create"
          - "session:list"
          - "session:delete"
          - "session:access"
          - "user:manage"
          - "config:manage"

      # devops チームには operator ロール
      "my-org/devops":
        role: "operator"
        permissions:
          - "session:create"
          - "session:list"
          - "session:delete"
          - "session:access"
          - "session:manage_all"

      # external-contractors チームには制限付きアクセス
      "my-org/external-contractors":
        role: "limited"
        permissions:
          - "session:create"
          - "session:list"
          - "session:access"

    # 特定ユーザーへの直接ロール割り当て
    user_role_mapping:
      "takutakahashi":
        role: "superadmin"
        permissions:
          - "*"  # すべての権限
```

#### Helm での設定

```yaml
# values.yaml
agentapi-proxy:
  authConfig:
    github:
      user_mapping:
        default_role: user
        default_permissions:
          - session:create
          - session:list
          - session:delete
          - session:access
        team_role_mapping:
          my-org/engineering:
            role: admin
            permissions:
              - session:create
              - session:list
              - session:delete
              - session:access
              - user:manage
              - config:manage
```

#### パーミッション一覧

| パーミッション | 説明 |
|--------------|------|
| `session:create` | 新しいセッションを作成 |
| `session:list` | 自分のセッション一覧を取得 |
| `session:access` | 自分のセッションに接続 |
| `session:delete` | 自分のセッションを削除 |
| `session:manage_all` | すべてのユーザーのセッションを管理 |
| `user:manage` | ユーザー設定を管理 |
| `config:manage` | システム設定を変更 |
| `*` | すべての権限 (スーパー管理者用) |

#### 認可フロー

```
1. リクエスト受信
   │
   ▼
2. 認証処理
   - トークン検証
   - ユーザー識別
   │
   ▼
3. ユーザー情報取得
   - GitHub API でユーザー詳細取得
   - GET /user
   │
   ▼
4. チーム情報取得 (GitHub App または PAT)
   - GET /user/teams
   - GET /orgs/{org}/teams/{team}/memberships/{username}
   │
   ▼
5. ロール解決
   - user_role_mapping をチェック
   - team_role_mapping をチェック
   - default_role を適用
   │
   ▼
6. パーミッション解決
   - ロールに紐づくパーミッションを集約
   - カスタムパーミッションをマージ
   │
   ▼
7. 認可チェック
   - 必要なパーミッションを確認
   - 一致すればリクエスト処理を続行
   - 不一致なら 403 Forbidden を返却
```

#### コード例

```go
type AuthorizationMiddleware struct {
    config *AuthConfig
}

func (m *AuthorizationMiddleware) CheckPermission(
    user *User,
    permission string,
) error {
    // 1. ユーザーの直接ロールをチェック
    if userRole, ok := m.config.UserRoleMapping[user.Username]; ok {
        if hasPermission(userRole.Permissions, permission) {
            return nil
        }
    }

    // 2. ユーザーのチームロールをチェック
    for _, team := range user.Teams {
        teamKey := fmt.Sprintf("%s/%s", team.Org, team.Name)
        if teamRole, ok := m.config.TeamRoleMapping[teamKey]; ok {
            if hasPermission(teamRole.Permissions, permission) {
                return nil
            }
        }
    }

    // 3. デフォルトパーミッションをチェック
    if hasPermission(m.config.DefaultPermissions, permission) {
        return nil
    }

    return ErrForbidden
}

func hasPermission(permissions []string, required string) bool {
    for _, p := range permissions {
        if p == "*" || p == required {
            return true
        }
    }
    return false
}
```

---

## Kubernetes RBAC

### ServiceAccount とロール

agentapi-proxy は 2 つの ServiceAccount を使用します:

#### 1. agentapi-proxy ServiceAccount

**用途**: agentapi-proxy Deployment が使用

**権限**:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: agentapi-proxy-session-manager
rules:
  # Pod 管理
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch", "create", "delete"]

  # Pod ログ取得
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get"]

  # Service 管理
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list", "create", "delete"]

  # PVC 管理
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "create", "delete"]

  # Deployment 管理
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "delete"]

  # Secret 管理 (MCP servers, credentials)
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "create", "update", "delete", "patch"]

  # ConfigMap 管理
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "create", "update", "patch", "delete"]

  # Leader Election (スケジュールワーカー用)
  - apiGroups: ["coordination.k8s.io"]
    resources: ["leases"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

#### 2. agentapi-proxy-session ServiceAccount

**用途**: セッション Pod が使用

**権限** (最小権限):
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: agentapi-proxy-session
rules:
  # 自身の Pod 情報取得
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]

  # 自身のログ取得
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get"]

  # ConfigMap 読み取り
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list"]

  # Secret 書き込み (credentials-sync 用)
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["create", "update"]
```

**セキュリティ原則**:
- セッション Pod は自分自身の Secret のみ作成/更新可能
- 他の Pod や Secret へのアクセス不可
- Namespace 内の最小限のリソースのみ参照可能

---

## セキュリティベストプラクティス

### 1. トークン管理

```yaml
# ✅ 推奨: Secret で管理
apiVersion: v1
kind: Secret
metadata:
  name: github-oauth
type: Opaque
stringData:
  client-id: "Iv1.xxxxxxxxxxxxxxxx"
  client-secret: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

```yaml
# ❌ 非推奨: 平文での保存
env:
  - name: GITHUB_CLIENT_SECRET
    value: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"  # 危険!
```

### 2. トークンローテーション

```bash
# GitHub App Private Key を定期的に更新
# 1. 新しい Private Key を生成
# 2. Secret を更新
kubectl create secret generic github-app \
  --from-file=private-key=/path/to/new-key.pem \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. agentapi-proxy を再起動して新しいキーを読み込み
kubectl rollout restart deployment/ccplant-agentapi-proxy
```

### 3. アクセス監査

すべての認証・認可イベントをログに記録:

```json
{
  "timestamp": "2024-01-27T12:00:00Z",
  "level": "info",
  "event": "authorization_check",
  "user": "takutakahashi",
  "action": "session:create",
  "resource": "session-user123-abc123",
  "result": "allowed",
  "role": "admin",
  "permissions": ["session:create", "session:list", "..."]
}
```

### 4. レート制限

```yaml
# ユーザーごとのレート制限
rate_limits:
  - user_role: "user"
    requests_per_minute: 60
    sessions_per_hour: 10

  - user_role: "admin"
    requests_per_minute: 300
    sessions_per_hour: 50
```

### 5. IP ホワイトリスト (オプション)

```yaml
# Ingress レベルでの制限
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: agentapi-proxy
  annotations:
    nginx.ingress.kubernetes.io/whitelist-source-range: |
      10.0.0.0/8,
      192.168.0.0/16,
      203.0.113.0/24
```

---

## トラブルシューティング

### 認証失敗

#### 症状
```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Invalid GitHub token"
  }
}
```

#### 原因と対処

1. **トークンが無効**
   ```bash
   # トークンを検証
   curl -H "Authorization: Bearer ${GITHUB_TOKEN}" \
     https://api.github.com/user
   ```

2. **トークンスコープ不足**
   - 必要なスコープ: `read:user`, `read:org`
   - GitHub の Personal Access Token 設定で確認

3. **GitHub Enterprise の設定ミス**
   ```yaml
   # BASE_URL を確認
   AGENTAPI_AUTH_GITHUB_BASE_URL: "https://github.example.com/api/v3"
   ```

### 認可失敗

#### 症状
```json
{
  "error": {
    "code": "FORBIDDEN",
    "message": "Missing required permission: session:create"
  }
}
```

#### 原因と対処

1. **ロール設定の確認**
   ```bash
   # 自分のロールとパーミッションを確認
   curl -H "Authorization: Bearer ${GITHUB_TOKEN}" \
     https://cc-api.example.com/api/v1/users/me
   ```

2. **チーム所属の確認**
   ```bash
   # GitHub でチーム所属を確認
   curl -H "Authorization: Bearer ${GITHUB_TOKEN}" \
     https://api.github.com/user/teams
   ```

3. **設定ファイルの確認**
   ```bash
   # ConfigMap を確認
   kubectl get configmap ccplant-agentapi-proxy-auth-config -o yaml
   ```

### GitHub App 統合の問題

#### 症状
```
Failed to get installation token: 404 Not Found
```

#### 対処

1. **GitHub App のインストール確認**
   - GitHub 組織設定で App がインストールされているか確認
   - 必要なリポジトリへのアクセスが許可されているか確認

2. **Private Key の確認**
   ```bash
   # Secret を確認
   kubectl get secret github-app -o yaml

   # Private Key をデコード
   kubectl get secret github-app -o jsonpath='{.data.private-key}' | base64 -d
   ```

3. **App ID の確認**
   ```bash
   # 環境変数を確認
   kubectl get deployment ccplant-agentapi-proxy -o yaml | grep GITHUB_APP_ID
   ```

---

## まとめ

agentapi-proxy の認証・認可システムは:

- **多層防御**: OAuth、GitHub App、API キーの組み合わせ
- **きめ細かい制御**: RBAC によるパーミッション管理
- **Kubernetes ネイティブ**: ServiceAccount による最小権限の原則
- **監査可能**: すべての認証・認可イベントをログ記録
- **拡張可能**: チームやユーザーごとのカスタマイズが可能

適切な設定により、セキュアかつ柔軟なマルチユーザー環境を実現できます。
