# API エンドポイント仕様

## 概要

agentapi-proxy は REST API、WebSocket、Server-Sent Events (SSE) をサポートする HTTP API サーバーです。メインポート 8080 ですべてのエンドポイントを提供します。

## ベース URL

```
本番環境: https://cc-api.example.com
開発環境: http://localhost:8080
```

## 認証

すべての保護されたエンドポイントは、以下のいずれかの認証方式を必要とします:

### 1. GitHub OAuth トークン (推奨)
```http
Authorization: Bearer {github_personal_access_token}
```

### 2. 静的 API キー (システム間通信用)
```http
X-API-Key: {static_api_key}
```

## REST API エンドポイント

### ヘルスチェック

#### GET /health

システムの稼働状態を確認します。

**認証**: 不要

**レスポンス**
```json
{
  "status": "ok",
  "timestamp": "2024-01-27T12:00:00Z",
  "version": "v1.191.0"
}
```

**ステータスコード**
- `200 OK`: システム正常
- `503 Service Unavailable`: システム異常

**使用例**
```bash
curl http://localhost:8080/health
```

---

### セッション管理

#### POST /api/v1/sessions

新しいセッションを作成します。

**認証**: 必要 (`session:create` パーミッション)

**リクエストボディ**
```json
{
  "name": "my-session",
  "config": {
    "cpu_limit": "2",
    "memory_limit": "4Gi",
    "pvc_enabled": true,
    "pvc_storage_size": "10Gi",
    "mcp_servers": {
      "github": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-github"],
        "env": {
          "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_xxxxx"
        }
      }
    },
    "timeout_minutes": 60
  }
}
```

**リクエストパラメータ**

| フィールド | 型 | 必須 | デフォルト | 説明 |
|----------|-----|------|-----------|------|
| name | string | No | auto-generated | セッション名 |
| config.cpu_limit | string | No | "2" | CPU 制限 |
| config.memory_limit | string | No | "4Gi" | メモリ制限 |
| config.pvc_enabled | boolean | No | false | 永続ボリューム有効化 |
| config.pvc_storage_size | string | No | "10Gi" | PVC サイズ |
| config.mcp_servers | object | No | {} | MCP サーバー設定 |
| config.timeout_minutes | integer | No | 0 | セッションタイムアウト (0=無制限) |

**レスポンス**
```json
{
  "session_id": "session-user123-abc123",
  "name": "my-session",
  "user": "user123",
  "status": "pending",
  "created_at": "2024-01-27T12:00:00Z",
  "connection_url": "wss://cc-api.example.com/ws/sessions/session-user123-abc123",
  "pod_name": "session-user123-abc123",
  "namespace": "default"
}
```

**ステータスコード**
- `201 Created`: セッション作成開始
- `400 Bad Request`: 無効なリクエスト
- `401 Unauthorized`: 認証失敗
- `403 Forbidden`: パーミッション不足
- `429 Too Many Requests`: リソース制限超過

**使用例**
```bash
curl -X POST https://cc-api.example.com/api/v1/sessions \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "dev-session",
    "config": {
      "cpu_limit": "1",
      "memory_limit": "2Gi"
    }
  }'
```

---

#### GET /api/v1/sessions

ユーザーのセッション一覧を取得します。

**認証**: 必要 (`session:list` パーミッション)

**クエリパラメータ**

| パラメータ | 型 | 必須 | デフォルト | 説明 |
|----------|-----|------|-----------|------|
| status | string | No | all | ステータスフィルタ: `running`, `pending`, `terminated`, `all` |
| limit | integer | No | 50 | 取得件数上限 |
| offset | integer | No | 0 | オフセット |

**レスポンス**
```json
{
  "sessions": [
    {
      "session_id": "session-user123-abc123",
      "name": "my-session",
      "user": "user123",
      "status": "running",
      "created_at": "2024-01-27T12:00:00Z",
      "updated_at": "2024-01-27T12:05:00Z",
      "connection_url": "wss://cc-api.example.com/ws/sessions/session-user123-abc123",
      "resources": {
        "cpu_usage": "0.5",
        "memory_usage": "1Gi"
      }
    }
  ],
  "total": 1,
  "limit": 50,
  "offset": 0
}
```

**ステータスコード**
- `200 OK`: 成功
- `401 Unauthorized`: 認証失敗
- `403 Forbidden`: パーミッション不足

**使用例**
```bash
curl https://cc-api.example.com/api/v1/sessions?status=running \
  -H "Authorization: Bearer ${GITHUB_TOKEN}"
```

---

#### GET /api/v1/sessions/{session_id}

特定のセッション詳細を取得します。

**認証**: 必要 (`session:access` パーミッション または セッション所有者)

**パスパラメータ**
- `session_id`: セッション ID

**レスポンス**
```json
{
  "session_id": "session-user123-abc123",
  "name": "my-session",
  "user": "user123",
  "status": "running",
  "created_at": "2024-01-27T12:00:00Z",
  "updated_at": "2024-01-27T12:05:00Z",
  "connection_url": "wss://cc-api.example.com/ws/sessions/session-user123-abc123",
  "pod_name": "session-user123-abc123",
  "namespace": "default",
  "config": {
    "cpu_limit": "2",
    "memory_limit": "4Gi",
    "pvc_enabled": true,
    "pvc_storage_size": "10Gi"
  },
  "resources": {
    "cpu_usage": "0.5",
    "cpu_limit": "2",
    "memory_usage": "1Gi",
    "memory_limit": "4Gi"
  },
  "pod_status": {
    "phase": "Running",
    "conditions": [
      {
        "type": "Ready",
        "status": "True",
        "last_transition_time": "2024-01-27T12:02:00Z"
      }
    ],
    "container_statuses": [
      {
        "name": "claude-code",
        "ready": true,
        "restart_count": 0
      }
    ]
  }
}
```

**ステータスコード**
- `200 OK`: 成功
- `401 Unauthorized`: 認証失敗
- `403 Forbidden`: パーミッション不足
- `404 Not Found`: セッション未存在

**使用例**
```bash
curl https://cc-api.example.com/api/v1/sessions/session-user123-abc123 \
  -H "Authorization: Bearer ${GITHUB_TOKEN}"
```

---

#### DELETE /api/v1/sessions/{session_id}

セッションを削除します。

**認証**: 必要 (`session:delete` パーミッション または セッション所有者)

**パスパラメータ**
- `session_id`: セッション ID

**クエリパラメータ**

| パラメータ | 型 | 必須 | デフォルト | 説明 |
|----------|-----|------|-----------|------|
| force | boolean | No | false | 強制削除 (graceful shutdown スキップ) |
| delete_pvc | boolean | No | true | PVC も削除 |

**レスポンス**
```json
{
  "session_id": "session-user123-abc123",
  "status": "terminating",
  "message": "Session deletion initiated"
}
```

**ステータスコード**
- `202 Accepted`: 削除開始
- `401 Unauthorized`: 認証失敗
- `403 Forbidden`: パーミッション不足
- `404 Not Found`: セッション未存在

**使用例**
```bash
curl -X DELETE https://cc-api.example.com/api/v1/sessions/session-user123-abc123 \
  -H "Authorization: Bearer ${GITHUB_TOKEN}"
```

---

### ユーザー管理

#### GET /api/v1/users/me

現在認証されているユーザー情報を取得します。

**認証**: 必要

**レスポンス**
```json
{
  "user_id": "user123",
  "github_username": "takutakahashi",
  "email": "user@example.com",
  "role": "user",
  "permissions": [
    "session:create",
    "session:list",
    "session:delete",
    "session:access"
  ],
  "teams": [
    {
      "name": "engineering",
      "role": "admin",
      "permissions": [
        "session:create",
        "session:list",
        "session:delete",
        "session:access",
        "user:manage"
      ]
    }
  ],
  "quota": {
    "max_sessions": 5,
    "current_sessions": 2,
    "max_cpu_per_session": "4",
    "max_memory_per_session": "8Gi"
  }
}
```

**ステータスコード**
- `200 OK`: 成功
- `401 Unauthorized`: 認証失敗

**使用例**
```bash
curl https://cc-api.example.com/api/v1/users/me \
  -H "Authorization: Bearer ${GITHUB_TOKEN}"
```

---

### GitHub 統合

#### GET /api/v1/github/oauth/authorize

GitHub OAuth 認証フローを開始します。

**認証**: 不要

**クエリパラメータ**

| パラメータ | 型 | 必須 | 説明 |
|----------|-----|------|------|
| redirect_uri | string | No | 認証後のリダイレクト URI |

**レスポンス**: GitHub 認証ページへのリダイレクト

**ステータスコード**
- `302 Found`: GitHub へリダイレクト

**使用例**
```bash
# ブラウザでアクセス
open "https://cc-api.example.com/api/v1/github/oauth/authorize?redirect_uri=https://cc-dev.example.com/callback"
```

---

#### GET /api/v1/github/oauth/callback

GitHub OAuth コールバックを処理します。

**認証**: 不要

**クエリパラメータ**

| パラメータ | 型 | 必須 | 説明 |
|----------|-----|------|------|
| code | string | Yes | GitHub 認証コード |
| state | string | Yes | CSRF トークン |

**レスポンス**: フロントエンドへのリダイレクト (セッションクッキー設定済み)

---

#### GET /api/v1/github/app/installation

GitHub App インストール状態を確認します。

**認証**: 必要

**レスポンス**
```json
{
  "installed": true,
  "installation_id": 12345678,
  "account": {
    "login": "my-org",
    "type": "Organization"
  },
  "permissions": {
    "contents": "read",
    "metadata": "read",
    "pull_requests": "write"
  },
  "repositories_count": 25
}
```

**ステータスコード**
- `200 OK`: 成功
- `401 Unauthorized`: 認証失敗
- `404 Not Found`: インストール未検出

---

## WebSocket API

### エンドポイント

```
wss://cc-api.example.com/ws/sessions/{session_id}
```

### 接続

**認証**
```javascript
const ws = new WebSocket(
  'wss://cc-api.example.com/ws/sessions/session-user123-abc123',
  {
    headers: {
      'Authorization': `Bearer ${githubToken}`
    }
  }
);
```

### メッセージフォーマット

#### クライアント → サーバー

```json
{
  "type": "command",
  "data": {
    "command": "execute",
    "payload": {
      "code": "print('Hello, World!')",
      "language": "python"
    }
  },
  "request_id": "req-123"
}
```

#### サーバー → クライアント

```json
{
  "type": "output",
  "data": {
    "stream": "stdout",
    "content": "Hello, World!\n"
  },
  "request_id": "req-123",
  "timestamp": "2024-01-27T12:00:00Z"
}
```

### メッセージタイプ

| タイプ | 方向 | 説明 |
|--------|------|------|
| `command` | C→S | コマンド実行要求 |
| `input` | C→S | ユーザー入力 |
| `output` | S→C | 標準出力/エラー出力 |
| `status` | S→C | セッションステータス更新 |
| `error` | S→C | エラーメッセージ |
| `ping` | C→S | 接続維持 |
| `pong` | S→C | ping レスポンス |

### エラーハンドリング

```json
{
  "type": "error",
  "data": {
    "code": "SESSION_NOT_READY",
    "message": "Session pod is not ready yet",
    "details": {
      "pod_phase": "Pending",
      "reason": "ContainerCreating"
    }
  }
}
```

### 接続切断

```json
{
  "type": "close",
  "data": {
    "reason": "session_terminated",
    "code": 1000
  }
}
```

**Close Codes**
- `1000`: 正常終了
- `1001`: 切断 (going away)
- `1008`: ポリシー違反 (認証失敗など)
- `1011`: サーバーエラー

---

## Server-Sent Events (SSE) API

### エンドポイント

```
https://cc-api.example.com/sse/sessions/{session_id}
```

### 接続

```javascript
const eventSource = new EventSource(
  'https://cc-api.example.com/sse/sessions/session-user123-abc123',
  {
    headers: {
      'Authorization': `Bearer ${githubToken}`
    }
  }
);

eventSource.addEventListener('status', (event) => {
  const data = JSON.parse(event.data);
  console.log('Status:', data);
});

eventSource.addEventListener('output', (event) => {
  const data = JSON.parse(event.data);
  console.log('Output:', data.content);
});
```

### イベントタイプ

| イベント | 説明 | データ例 |
|---------|------|---------|
| `status` | ステータス更新 | `{"status": "running", "timestamp": "..."}` |
| `output` | 出力ストリーム | `{"stream": "stdout", "content": "..."}` |
| `metrics` | リソースメトリクス | `{"cpu": "0.5", "memory": "1Gi"}` |
| `error` | エラー発生 | `{"code": "...", "message": "..."}` |

### ハートビート

サーバーは 30 秒ごとにハートビートを送信します:

```
: heartbeat
```

---

## エラーレスポンス

すべてのエラーレスポンスは以下の形式です:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {
      "field": "additional context"
    },
    "request_id": "req-123",
    "timestamp": "2024-01-27T12:00:00Z"
  }
}
```

### エラーコード一覧

| コード | HTTP ステータス | 説明 |
|--------|----------------|------|
| `UNAUTHORIZED` | 401 | 認証失敗 |
| `FORBIDDEN` | 403 | パーミッション不足 |
| `NOT_FOUND` | 404 | リソース未存在 |
| `INVALID_REQUEST` | 400 | 無効なリクエスト |
| `RESOURCE_QUOTA_EXCEEDED` | 429 | リソース上限超過 |
| `SESSION_NOT_READY` | 503 | セッション準備中 |
| `POD_START_TIMEOUT` | 504 | Pod 起動タイムアウト |
| `INTERNAL_ERROR` | 500 | 内部エラー |

---

## レート制限

### 制限値

| エンドポイント | 制限 | ウィンドウ |
|--------------|------|-----------|
| `/api/v1/sessions` (POST) | 10 requests | 1 分 |
| `/api/v1/sessions` (GET) | 100 requests | 1 分 |
| `/api/v1/users/*` | 60 requests | 1 分 |
| その他 | 1000 requests | 1 分 |

### ヘッダー

```http
X-RateLimit-Limit: 10
X-RateLimit-Remaining: 8
X-RateLimit-Reset: 1706356800
```

### レート制限超過時

```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded",
    "details": {
      "limit": 10,
      "reset_at": "2024-01-27T12:10:00Z"
    }
  }
}
```

HTTP ステータス: `429 Too Many Requests`

---

## CORS

### 許可されたオリジン

```
https://cc-dev.example.com
https://cc-api.example.com
```

### レスポンスヘッダー

```http
Access-Control-Allow-Origin: https://cc-dev.example.com
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Authorization, Content-Type
Access-Control-Max-Age: 86400
```

---

## ページネーション

リスト取得 API は以下のパラメータをサポートします:

```http
GET /api/v1/sessions?limit=20&offset=40
```

**レスポンス**
```json
{
  "items": [...],
  "total": 150,
  "limit": 20,
  "offset": 40,
  "has_more": true,
  "next_offset": 60
}
```

---

## バージョニング

API バージョンは URL パスに含まれます:

```
/api/v1/...  - Current stable version
/api/v2/...  - Future version (when available)
```

現在のバージョン: `v1`

バージョンは後方互換性を保ちながら更新されます。破壊的変更が必要な場合は新しいバージョンが導入されます。
