# API 統合

## 概要

このドキュメントでは、agentapi-ui と agentapi-proxy バックエンドの API 統合について詳しく説明します。API クライアントの実装、認証フロー、データ通信、エラーハンドリングについて解説します。

## API クライアントアーキテクチャ

### AgentAPIProxyClient

agentapi-ui は `AgentAPIProxyClient` クラスを使用して agentapi-proxy と通信します。

**ファイル**: `src/lib/agentapi-proxy-client.ts`

```typescript
export class AgentAPIProxyClient {
  private baseURL: string;
  private apiKey?: string;
  private timeout: number;
  private maxSessions: number;
  private sessionTimeout: number;
  private debug: boolean;

  constructor(config: AgentAPIProxyClientConfig) {
    this.baseURL = config.baseURL.replace(/\/$/, '');
    this.apiKey = config.apiKey;
    this.timeout = config.timeout || 10000;
    this.maxSessions = config.maxSessions || 10;
    this.sessionTimeout = config.sessionTimeout || 300000;
    this.debug = config.debug || false;
  }

  // リクエストヘルパー
  private async request<T>(
    path: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${this.baseURL}${path}`;
    const headers = {
      'Content-Type': 'application/json',
      ...(this.apiKey && { 'Authorization': `Bearer ${this.apiKey}` }),
      ...options.headers,
    };

    const response = await fetch(url, {
      ...options,
      headers,
      signal: AbortSignal.timeout(this.timeout),
    });

    if (!response.ok) {
      throw new AgentAPIProxyError(
        response.status,
        'API_ERROR',
        await response.text()
      );
    }

    return response.json();
  }
}
```

### クライアント初期化

```typescript
// ブラウザ側での初期化
const client = new AgentAPIProxyClient({
  baseURL: '/api/proxy', // Next.js API Routes 経由
  timeout: 30000,
  debug: process.env.NODE_ENV === 'development',
});

// サーバー側での初期化
const client = new AgentAPIProxyClient({
  baseURL: process.env.AGENTAPI_PROXY_URL || 'http://localhost:8080',
  apiKey: await getApiKeyFromCookie(),
  timeout: 30000,
});
```

## 認証フロー

### Cookie ベース認証

agentapi-ui は暗号化された Cookie を使用して認証情報を管理します。

#### 1. ログインフロー（API キー）

```typescript
// 1. ユーザーが API キーを入力
POST /api/auth/login
{
  "apiKey": "user_provided_api_key"
}

// 2. サーバー側で Cookie を暗号化して設定
import { encryptCookie, getSecureCookieOptions } from '@/lib/cookie-encryption';

export async function POST(request: NextRequest) {
  const { apiKey } = await request.json();

  // API キーを暗号化
  const encryptedKey = encryptCookie(apiKey);

  // Cookie を設定
  const response = NextResponse.json({ success: true });
  response.cookies.set(
    'auth_token',
    encryptedKey,
    getSecureCookieOptions(86400) // 24時間
  );

  return response;
}
```

#### 2. ログインフロー（GitHub OAuth）

```typescript
// OAuth フロー
┌──────────┐
│ Browser  │
└────┬─────┘
     │ 1. ユーザーが「GitHub でログイン」をクリック
     ▼
┌────────────────────────┐
│ /api/auth/github/      │
│ authorize              │
└────┬───────────────────┘
     │ 2. GitHub 認証ページへリダイレクト
     ▼
┌──────────┐
│ GitHub   │
│ OAuth    │
└────┬─────┘
     │ 3. ユーザーが認証を承認
     ▼
┌────────────────────────┐
│ /login/github?code=xxx │
└────┬───────────────────┘
     │ 4. 認証コードを受け取る
     ▼
┌────────────────────────┐
│ /api/auth/github/      │
│ callback               │
└────┬───────────────────┘
     │ 5. トークンを取得して Cookie に保存
     ▼
┌────────────────────────┐
│ /chats                 │
└────────────────────────┘
```

**実装**:

```typescript
// src/app/api/auth/github/authorize/route.ts
export async function GET(request: NextRequest) {
  const clientId = process.env.GITHUB_CLIENT_ID;
  const redirectUri = `${process.env.NEXT_PUBLIC_BASE_URL}/login/github`;

  const params = new URLSearchParams({
    client_id: clientId,
    redirect_uri: redirectUri,
    scope: 'user:email,repo',
    state: generateRandomState(), // CSRF 対策
  });

  return NextResponse.redirect(
    `https://github.com/login/oauth/authorize?${params}`
  );
}

// src/app/api/auth/github/callback/route.ts
export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const code = searchParams.get('code');
  const state = searchParams.get('state');

  // CSRF チェック
  if (!validateState(state)) {
    return NextResponse.json({ error: 'Invalid state' }, { status: 400 });
  }

  // トークン取得
  const tokenResponse = await fetch(
    'https://github.com/login/oauth/access_token',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: process.env.GITHUB_CLIENT_ID,
        client_secret: process.env.GITHUB_CLIENT_SECRET,
        code,
      }),
    }
  );

  const { access_token } = await tokenResponse.json();

  // Cookie に保存
  const encryptedToken = encryptCookie(access_token);
  const response = NextResponse.redirect('/chats');
  response.cookies.set('auth_token', encryptedToken, getSecureCookieOptions());

  return response;
}
```

#### 3. 認証状態の確認

```typescript
// src/app/api/auth/status/route.ts
export async function GET(request: NextRequest) {
  const authCookie = request.cookies.get('auth_token');

  if (!authCookie) {
    return NextResponse.json({ authenticated: false });
  }

  try {
    const apiKey = decryptCookie(authCookie.value);

    // API キーの有効性を確認
    const response = await fetch(
      `${process.env.AGENTAPI_PROXY_URL}/v1/user/info`,
      {
        headers: { 'Authorization': `Bearer ${apiKey}` },
      }
    );

    if (response.ok) {
      return NextResponse.json({ authenticated: true });
    }
  } catch (error) {
    console.error('Auth status check failed:', error);
  }

  return NextResponse.json({ authenticated: false });
}
```

### Cookie 暗号化

**ファイル**: `src/lib/cookie-encryption.ts`

#### 暗号化アルゴリズム

- **アルゴリズム**: AES-256-GCM
- **キー導出**: scrypt (32 バイト)
- **IV**: ランダム生成 (16 バイト)
- **認証タグ**: 16 バイト

#### 暗号化処理

```typescript
export function encryptCookie(value: string): string {
  const key = getEncryptionKey();
  const iv = randomBytes(ivLength);
  const salt = randomBytes(saltLength);

  const cipher = createCipheriv(algorithm, key, iv);

  const encrypted = Buffer.concat([
    cipher.update(value, 'utf8'),
    cipher.final()
  ]);

  const tag = cipher.getAuthTag();

  // 結合: salt + iv + tag + encrypted
  const combined = Buffer.concat([salt, iv, tag, encrypted]);

  return combined.toString('base64url');
}
```

#### 復号化処理

```typescript
export function decryptCookie(encryptedValue: string): string {
  const key = getEncryptionKey();
  const combined = Buffer.from(encryptedValue, 'base64url');

  // 分解: salt + iv + tag + encrypted
  const iv = combined.subarray(saltLength, saltLength + ivLength);
  const tag = combined.subarray(saltLength + ivLength, saltLength + ivLength + tagLength);
  const encrypted = combined.subarray(saltLength + ivLength + tagLength);

  const decipher = createDecipheriv(algorithm, key, iv);
  decipher.setAuthTag(tag);

  const decrypted = Buffer.concat([
    decipher.update(encrypted),
    decipher.final()
  ]);

  return decrypted.toString('utf8');
}
```

#### セキュア Cookie オプション

```typescript
export function getSecureCookieOptions(maxAge: number = 86400) {
  return {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax' as const,
    path: '/',
    maxAge, // デフォルト: 24時間
  };
}
```

## API Routes プロキシ

### プロキシパターン

agentapi-ui は Next.js API Routes を使用して agentapi-proxy へのリクエストをプロキシします。

**ファイル**: `src/app/api/proxy/[...path]/route.ts`

```typescript
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  const resolvedParams = await params;
  const path = resolvedParams.path.join('/');

  // Cookie から API キーを取得
  const authCookie = request.cookies.get('auth_token');
  if (!authCookie) {
    return NextResponse.json(
      { error: 'Unauthorized' },
      { status: 401 }
    );
  }

  const apiKey = decryptCookie(authCookie.value);

  // agentapi-proxy へリクエストをプロキシ
  const proxyUrl = process.env.AGENTAPI_PROXY_URL;
  const url = `${proxyUrl}/v1/${path}`;

  // クエリパラメータをコピー
  const searchParams = new URL(request.url).searchParams;
  const fullUrl = `${url}?${searchParams}`;

  const response = await fetch(fullUrl, {
    method: request.method,
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
  });

  // レスポンスをそのまま返す
  return new NextResponse(response.body, {
    status: response.status,
    headers: response.headers,
  });
}

export async function POST(request: NextRequest, context: any) {
  return handleProxyRequest(request, context, 'POST');
}

export async function PUT(request: NextRequest, context: any) {
  return handleProxyRequest(request, context, 'PUT');
}

export async function DELETE(request: NextRequest, context: any) {
  return handleProxyRequest(request, context, 'DELETE');
}

export async function PATCH(request: NextRequest, context: any) {
  return handleProxyRequest(request, context, 'PATCH');
}
```

### プロキシの利点

1. **CORS 問題の回避**: 同一オリジンからのリクエストになる
2. **API キーの保護**: クライアントに API キーを露出しない
3. **リクエスト/レスポンスの加工**: 必要に応じてデータを変換可能
4. **エラーハンドリングの統一**: 統一的なエラー処理

## API エンドポイント

### セッション管理

#### セッション一覧取得

```typescript
// GET /api/proxy/sessions
const sessions = await client.listSessions({
  page: 1,
  per_page: 20,
  status: 'running',
  scope: 'user',
});

// レスポンス
interface SessionListResponse {
  sessions: Session[];
  pagination: {
    page: number;
    per_page: number;
    total: number;
    total_pages: number;
  };
}
```

#### セッション作成

```typescript
// POST /api/proxy/sessions
const session = await client.createSession({
  repository: 'owner/repo',
  agent_id: 'claude-code',
  initial_message: 'プロジェクトのセットアップをお願いします',
  scope: 'user',
});

// レスポンス
interface Session {
  id: string;
  repository: string;
  agent_id: string;
  status: 'pending' | 'running' | 'completed' | 'failed';
  created_at: string;
  updated_at: string;
}
```

#### セッション詳細取得

```typescript
// GET /api/proxy/sessions/:id
const session = await client.getSession(sessionId);
```

#### セッション削除

```typescript
// DELETE /api/proxy/sessions/:id
await client.deleteSession(sessionId);
```

### メッセージ管理

#### メッセージ一覧取得

```typescript
// GET /api/proxy/sessions/:id/messages
const { messages, pagination } = await client.listMessages(sessionId, {
  page: 1,
  per_page: 50,
  order: 'asc',
});

// レスポンス
interface SessionMessage {
  id: string;
  session_id: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  created_at: string;
}
```

#### メッセージ送信

```typescript
// POST /api/proxy/sessions/:id/messages
const message = await client.sendMessage(sessionId, {
  content: 'テストを実行してください',
  files?: [
    {
      name: 'test.js',
      content: 'console.log("test");',
    }
  ],
});
```

### ストリーミング通信

#### Server-Sent Events (SSE)

```typescript
// GET /api/proxy/sessions/:id/events?stream=true
await client.streamSessionEvents(sessionId, {
  onMessage: (event: SessionEventData) => {
    switch (event.type) {
      case 'message_start':
        // 新しいメッセージの開始
        startNewMessage(event.data);
        break;

      case 'message_chunk':
        // メッセージの部分更新
        updateMessage(event.data);
        break;

      case 'message_complete':
        // メッセージの完了
        finalizeMessage(event.data);
        break;

      case 'status_change':
        // ステータスの変更
        updateSessionStatus(event.data);
        break;

      case 'error':
        // エラー発生
        handleError(event.data);
        break;
    }
  },
  onError: (error) => {
    console.error('Streaming error:', error);
    showToast('ストリーミングエラー', 'error');
  },
  onComplete: () => {
    console.log('Streaming completed');
    setIsStreaming(false);
  },
});
```

#### イベントデータ型

```typescript
interface SessionEventData {
  type: 'message_start' | 'message_chunk' | 'message_complete' | 'status_change' | 'error';
  data: {
    message_id?: string;
    content?: string;
    delta?: string;
    status?: SessionStatus;
    error?: string;
  };
  timestamp: string;
}
```

### エージェント管理

```typescript
// GET /api/proxy/agents
const agents = await client.listAgents({
  status: 'stable',
  search: 'claude',
});

// GET /api/proxy/agents/:id
const agent = await client.getAgent(agentId);
```

### スケジュール管理

```typescript
// GET /api/proxy/schedules
const schedules = await client.listSchedules({
  scope: 'user',
});

// POST /api/proxy/schedules
const schedule = await client.createSchedule({
  name: '毎日のバックアップ',
  cron_expression: '0 9 * * *',
  repository: 'owner/repo',
  agent_id: 'claude-code',
  message: 'バックアップを実行してください',
  enabled: true,
});

// PUT /api/proxy/schedules/:id
await client.updateSchedule(scheduleId, {
  enabled: false,
});

// DELETE /api/proxy/schedules/:id
await client.deleteSchedule(scheduleId);

// POST /api/proxy/schedules/:id/trigger
const result = await client.triggerSchedule(scheduleId);
```

### Webhook 管理

```typescript
// GET /api/proxy/webhooks
const webhooks = await client.listWebhooks({
  scope: 'user',
});

// POST /api/proxy/webhooks
const webhook = await client.createWebhook({
  name: 'プッシュ時にテスト実行',
  events: ['push'],
  repository: 'owner/repo',
  agent_id: 'claude-code',
  message_template: 'プッシュされたコミット: {{commit.message}}',
  enabled: true,
});

// PUT /api/proxy/webhooks/:id
await client.updateWebhook(webhookId, {
  enabled: false,
});

// DELETE /api/proxy/webhooks/:id
await client.deleteWebhook(webhookId);

// POST /api/proxy/webhooks/:id/regenerate-secret
const { secret } = await client.regenerateSecret(webhookId);
```

### ユーザー情報

```typescript
// GET /api/proxy/user/info
const userInfo = await client.getUserInfo();

interface ProxyUserInfo {
  id: string;
  login: string;
  name?: string;
  email?: string;
  avatar_url?: string;
  teams?: string[];
}
```

## エラーハンドリング

### カスタムエラークラス

```typescript
export class AgentAPIProxyError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
    public details?: Record<string, unknown>
  ) {
    super(message);
    this.name = 'AgentAPIProxyError';
  }
}
```

### エラー処理パターン

```typescript
try {
  const session = await client.createSession(request);
  showToast('セッションを作成しました', 'success');
  router.push(`/sessions/${session.id}`);
} catch (error) {
  if (error instanceof AgentAPIProxyError) {
    switch (error.status) {
      case 400:
        showToast('リクエストが不正です', 'error');
        break;
      case 401:
        showToast('認証が必要です', 'error');
        router.push('/login');
        break;
      case 403:
        showToast('権限がありません', 'error');
        break;
      case 404:
        showToast('リソースが見つかりません', 'error');
        break;
      case 429:
        showToast('リクエストが多すぎます', 'error');
        break;
      case 500:
        showToast('サーバーエラーが発生しました', 'error');
        break;
      default:
        showToast('エラーが発生しました', 'error');
    }
  } else {
    console.error('Unexpected error:', error);
    showToast('予期しないエラーが発生しました', 'error');
  }
}
```

### リトライロジック

```typescript
async function fetchWithRetry<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3,
  delay: number = 1000
): Promise<T> {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      if (i === maxRetries - 1) throw error;

      // 指数バックオフ
      const waitTime = delay * Math.pow(2, i);
      await new Promise(resolve => setTimeout(resolve, waitTime));
    }
  }

  throw new Error('Max retries exceeded');
}

// 使用例
const session = await fetchWithRetry(
  () => client.getSession(sessionId),
  3,
  1000
);
```

## データキャッシング

### localStorage キャッシュ

```typescript
// src/utils/cache.ts
export class LocalStorageCache {
  private prefix: string;
  private ttl: number;

  constructor(prefix: string = 'agentapi_cache_', ttl: number = 3600000) {
    this.prefix = prefix;
    this.ttl = ttl;
  }

  set<T>(key: string, value: T): void {
    const item = {
      value,
      timestamp: Date.now(),
    };
    localStorage.setItem(this.prefix + key, JSON.stringify(item));
  }

  get<T>(key: string): T | null {
    const item = localStorage.getItem(this.prefix + key);
    if (!item) return null;

    const { value, timestamp } = JSON.parse(item);

    // TTL チェック
    if (Date.now() - timestamp > this.ttl) {
      this.remove(key);
      return null;
    }

    return value;
  }

  remove(key: string): void {
    localStorage.removeItem(this.prefix + key);
  }

  clear(): void {
    const keys = Object.keys(localStorage);
    keys.forEach(key => {
      if (key.startsWith(this.prefix)) {
        localStorage.removeItem(key);
      }
    });
  }
}
```

## レート制限

### レート制限の処理

```typescript
// レート制限のレスポンスヘッダーを確認
const response = await fetch(url, options);

const rateLimit = {
  limit: parseInt(response.headers.get('X-RateLimit-Limit') || '0'),
  remaining: parseInt(response.headers.get('X-RateLimit-Remaining') || '0'),
  reset: parseInt(response.headers.get('X-RateLimit-Reset') || '0'),
};

if (rateLimit.remaining < 10) {
  showToast('API レート制限に近づいています', 'warning');
}

if (response.status === 429) {
  const resetTime = new Date(rateLimit.reset * 1000);
  showToast(
    `レート制限に達しました。${resetTime.toLocaleTimeString()}に再試行してください`,
    'error'
  );
}
```

## 次のステップ

- [セキュリティ](./security.md) - セキュリティ実装の詳細
- [設定リファレンス](./configuration.md) - 環境変数と設定
- [アーキテクチャ](./architecture.md) - アーキテクチャの詳細
