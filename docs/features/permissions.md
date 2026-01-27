# 権限管理

## 概要

ccplant は、ロールベースアクセス制御 (RBAC) により、きめ細かい権限管理を実現します。GitHub のチーム構造と統合し、組織のセキュリティポリシーに合わせた柔軟なアクセス制御が可能です。

## RBAC システムの概要

### アーキテクチャ

```
ユーザー
  ↓
GitHub チーム所属
  ↓
ロール割り当て
  ↓
権限セット
  ↓
リソースアクセス
```

### コンポーネント

1. **ユーザー**: GitHub アカウント
2. **チーム**: GitHub 組織のチーム
3. **ロール**: 権限のグループ (user, admin など)
4. **権限**: 具体的な操作 (session:create など)
5. **リソース**: セッション、Webhook、スケジュールなど

## ユーザーロール

### デフォルトロール

#### 1. user (デフォルト)

**権限:**
- session:create - セッション作成
- session:list - 自分のセッション一覧取得
- session:access - 自分のセッションにアクセス
- session:delete - 自分のセッション削除

**制限:**
- 他人のセッションにはアクセス不可
- Webhook/スケジュール作成不可
- システム設定変更不可

#### 2. developer

**権限:**
- user の全権限
- webhook:create - Webhook 作成
- webhook:list - Webhook 一覧取得
- webhook:delete - 自分の Webhook 削除
- schedule:create - スケジュール作成
- schedule:list - スケジュール一覧取得
- schedule:delete - 自分のスケジュール削除

**用途:** 自動化を必要とする開発者

#### 3. admin

**権限:**
- すべての user と developer の権限
- session:manage_all - 全ユーザーのセッション管理
- webhook:manage_all - 全 Webhook 管理
- schedule:manage_all - 全スケジュール管理
- user:manage - ユーザー管理
- config:manage - システム設定変更

**用途:** システム管理者

#### 4. viewer

**権限:**
- session:list - セッション一覧取得 (読み取りのみ)
- webhook:list - Webhook 一覧取得 (読み取りのみ)
- schedule:list - スケジュール一覧取得 (読み取りのみ)

**用途:** 監査、レポート作成

### カスタムロール

組織固有のロールを定義できます:

```yaml
# auth-config.yaml
custom_roles:
  contractor:
    permissions:
      - session:create
      - session:list
      - session:access
    resource_limits:
      max_sessions: 3
      max_cpu: "2"
      max_memory: "4Gi"
```

## デフォルト権限

新規ユーザーに自動的に付与される権限です。

### 設定

```yaml
# auth-config.yaml
github:
  user_mapping:
    default_role: "user"
    default_permissions:
      - session:create
      - session:list
      - session:delete
      - session:access
```

### 推奨設定

**厳格な環境:**
```yaml
default_permissions:
  - session:list  # 閲覧のみ
```

**標準的な環境:**
```yaml
default_permissions:
  - session:create
  - session:list
  - session:delete
  - session:access
```

**柔軟な環境:**
```yaml
default_permissions:
  - session:create
  - session:list
  - session:delete
  - session:access
  - webhook:create
  - schedule:create
```

## チームマッピング

GitHub のチーム構造を ccplant のロールにマッピングします。

### 設定例

```yaml
# auth-config.yaml
github:
  user_mapping:
    team_role_mapping:
      # エンジニアリングチーム → admin
      "myorg/engineering":
        role: "admin"
        permissions:
          - "*"  # すべての権限

      # 開発チーム → developer
      "myorg/developers":
        role: "developer"
        permissions:
          - session:create
          - session:list
          - session:delete
          - session:access
          - webhook:create
          - webhook:delete
          - schedule:create
          - schedule:delete

      # QA チーム → viewer + limited create
      "myorg/qa":
        role: "qa"
        permissions:
          - session:create
          - session:list
          - session:access

      # 外部契約者 → restricted
      "myorg/contractors":
        role: "contractor"
        permissions:
          - session:create
          - session:list
        resource_limits:
          max_sessions: 2
          max_cpu: "1"
          max_memory: "2Gi"
```

### Helm での設定

```yaml
# values.yaml
agentapi-proxy:
  authConfig:
    github:
      user_mapping:
        team_role_mapping:
          myorg/engineering:
            role: admin
            permissions: ["*"]
          myorg/developers:
            role: developer
            permissions:
              - session:create
              - webhook:create
              - schedule:create
```

## GitHub チーム統合

### チーム情報の取得

ccplant は GitHub API を使用してチーム所属を確認します:

```
1. ユーザーログイン
    ↓
2. GitHub API でチーム一覧取得
   GET /user/teams
    ↓
3. チームロールマッピングを参照
    ↓
4. 権限を計算
    ↓
5. ユーザーコンテキストに設定
```

### 必要な権限

GitHub PAT または OAuth に以下のスコープが必要:

- `read:org` - 組織情報の取得
- `read:team` - チーム情報の取得 (一部の API)

### GitHub App 使用時

GitHub App を使用すると、より詳細なチーム情報を取得できます:

```yaml
# GitHub App 権限
permissions:
  organization:
    members: read
    teams: read
```

## 権限管理

### 権限の確認

#### Web UI

1. 設定画面 → プロフィール
2. 「権限」セクションで現在の権限を確認

#### API

```bash
curl https://cc-api.example.com/api/v1/users/me \
  -H "Authorization: Bearer ${GITHUB_TOKEN}"
```

**レスポンス:**
```json
{
  "user_id": "user123",
  "github_username": "username",
  "role": "developer",
  "permissions": [
    "session:create",
    "session:list",
    "webhook:create"
  ],
  "teams": [
    {
      "name": "developers",
      "org": "myorg",
      "role": "developer"
    }
  ]
}
```

### 権限の変更

管理者のみが権限を変更できます。

#### 特定ユーザーへの権限付与

```yaml
# auth-config.yaml
github:
  user_mapping:
    user_role_mapping:
      "specific-username":
        role: "admin"
        permissions:
          - "*"
```

#### チーム全体への権限付与

```yaml
github:
  user_mapping:
    team_role_mapping:
      "myorg/new-team":
        role: "developer"
        permissions:
          - session:create
          - webhook:create
```

### 権限の削除

1. `auth-config.yaml` から該当エントリを削除
2. ConfigMap を更新
3. agentapi-proxy を再起動

```bash
kubectl rollout restart deployment/ccplant-agentapi-proxy
```

## チーム共有セッション

チームメンバーが共有できるセッションを作成できます。

### 設定

```json
{
  "name": "team-shared-session",
  "scope": "team",
  "team_id": "myorg/developers",
  "config": {
    "shared": true
  }
}
```

### アクセス制御

- チームメンバー全員がアクセス可能
- チーム外のユーザーはアクセス不可
- `session:manage_all` 権限を持つ admin はアクセス可能

## リソース制限

ユーザーやチームごとにリソース制限を設定できます。

### 設定例

```yaml
github:
  user_mapping:
    team_role_mapping:
      "myorg/developers":
        role: "developer"
        resource_limits:
          max_sessions: 10           # 最大同時セッション数
          max_cpu_per_session: "4"   # セッションあたりの最大 CPU
          max_memory_per_session: "8Gi"  # セッションあたりの最大メモリ
          max_pvc_size: "50Gi"       # PVC の最大サイズ
```

### 制限の確認

```bash
curl https://cc-api.example.com/api/v1/users/me/quota \
  -H "Authorization: Bearer ${GITHUB_TOKEN}"
```

**レスポンス:**
```json
{
  "max_sessions": 10,
  "current_sessions": 3,
  "max_cpu_per_session": "4",
  "max_memory_per_session": "8Gi",
  "max_pvc_size": "50Gi"
}
```

## 権限リファレンス

### セッション関連

| 権限 | 説明 | デフォルトロール |
|------|------|----------------|
| session:create | セッション作成 | user |
| session:list | 自分のセッション一覧 | user |
| session:access | 自分のセッションにアクセス | user |
| session:delete | 自分のセッション削除 | user |
| session:manage_all | 全ユーザーのセッション管理 | admin |

### Webhook 関連

| 権限 | 説明 | デフォルトロール |
|------|------|----------------|
| webhook:create | Webhook 作成 | developer |
| webhook:list | 自分の Webhook 一覧 | developer |
| webhook:delete | 自分の Webhook 削除 | developer |
| webhook:manage_all | 全 Webhook 管理 | admin |

### スケジュール関連

| 権限 | 説明 | デフォルトロール |
|------|------|----------------|
| schedule:create | スケジュール作成 | developer |
| schedule:list | 自分のスケジュール一覧 | developer |
| schedule:delete | 自分のスケジュール削除 | developer |
| schedule:manage_all | 全スケジュール管理 | admin |

### システム関連

| 権限 | 説明 | デフォルトロール |
|------|------|----------------|
| user:manage | ユーザー管理 | admin |
| config:manage | システム設定変更 | admin |
| * | すべての権限 | admin |

## トラブルシューティング

### 権限が反映されない

**症状:** チームに追加したが、権限が変わらない

**対処:**
1. ログアウト・ログインして GitHub 情報を更新
2. auth-config ConfigMap を確認
3. agentapi-proxy のログを確認

### チーム情報が取得できない

**症状:** GitHub チームに所属しているが、ccplant で認識されない

**対処:**
1. GitHub トークンのスコープを確認 (`read:org`)
2. GitHub 組織の OAuth 設定を確認
3. GitHub App の権限を確認

## ベストプラクティス

### 1. 最小権限の原則

必要最小限の権限のみを付与します。

### 2. チームベースの管理

個別ユーザーではなく、チーム単位で権限を管理します。

### 3. 定期的なレビュー

3ヶ月ごとに権限設定をレビューします。

### 4. 監査ログの確認

権限に関連するイベントを定期的に確認します。

## まとめ

適切な権限管理により、セキュアで効率的なチーム開発環境を実現できます。組織の構造に合わせて柔軟に設定してください。

### 次のステップ

- [認証](./authentication.md) - 認証方式の設定
- [セキュリティ](../operations/security.md) - セキュリティベストプラクティス
- [監査](../operations/monitoring.md#監査ログ) - 監査ログの確認
