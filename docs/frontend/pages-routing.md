# ページ構造とルーティング

## 概要

このドキュメントでは、agentapi-ui のページ構造、ルーティング、各ページの詳細について説明します。Next.js 15 の App Router を使用したファイルベースルーティングの仕組みと、各ページの役割を解説します。

## ルーティング構造

### ルート一覧

```
/                           # ホームページ（リダイレクト）
/login                      # ログインページ
/login/github               # GitHub OAuth コールバック
/chats                      # セッション一覧
/chats/[repo_fullname]      # リポジトリ別セッション一覧
/sessions/new               # 新規セッション作成
/sessions/[sessionId]       # セッション詳細（チャット画面）
/s/[shareToken]             # 共有セッション（読み取り専用）
/agents                     # エージェント一覧
/schedules                  # スケジュール管理
/webhooks                   # Webhook 管理
/settings                   # 設定（リダイレクト）
/settings/personal          # 個人設定
/settings/team              # チーム設定
/agentapi                   # AgentAPI 直接接続
/offline                    # オフラインページ
```

### API Routes

```
/api/auth/login             # ログイン処理
/api/auth/logout            # ログアウト処理
/api/auth/status            # 認証ステータス確認
/api/auth/github/authorize  # GitHub OAuth 認証開始
/api/auth/github/callback   # GitHub OAuth コールバック
/api/config                 # 設定情報取得
/api/manifest               # PWA マニフェスト
/api/encrypt                # Cookie 暗号化
/api/decrypt                # Cookie 復号化
/api/proxy/[...path]        # agentapi-proxy へのプロキシ
/api/user/info              # ユーザー情報取得
```

## ページ詳細

### 1. ホームページ (`/`)

**ファイル**: `src/app/page.tsx`

#### 機能
- 認証済みユーザーを `/chats` へリダイレクト
- 未認証ユーザーを `/login` へリダイレクト

#### 実装例
```typescript
'use client'

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';

export default function Home() {
  const router = useRouter();

  useEffect(() => {
    // 認証状態を確認してリダイレクト
    fetch('/api/auth/status')
      .then(res => res.json())
      .then(data => {
        if (data.authenticated) {
          router.push('/chats');
        } else {
          router.push('/login');
        }
      });
  }, [router]);

  return <LoadingSpinner />;
}
```

### 2. ログインページ (`/login`)

**ファイル**: `src/app/login/page.tsx`

#### 機能
- API キー認証フォーム
- GitHub OAuth ログインボタン
- 認証モード切り替え（AUTH_MODE による制御）

#### AUTH_MODE 設定

| モード | 説明 | 表示 |
|-------|------|------|
| `both` | 両方許可（デフォルト） | API キーフォーム + OAuth ボタン |
| `api_key` | API キーのみ | API キーフォームのみ |
| `oauth_only` | OAuth のみ | OAuth ボタンのみ |

#### UI コンポーネント

```typescript
export default function LoginPage() {
  const { config } = useConfig();
  const [apiKey, setApiKey] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleApiKeyLogin = async () => {
    setIsLoading(true);
    try {
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ apiKey }),
      });

      if (response.ok) {
        router.push('/chats');
      } else {
        showToast('ログインに失敗しました', 'error');
      }
    } finally {
      setIsLoading(false);
    }
  };

  const handleGitHubLogin = () => {
    window.location.href = '/api/auth/github/authorize';
  };

  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="max-w-md w-full space-y-8">
        <h1>{config?.loginTitle || 'AgentAPI UI'}</h1>
        <p>{config?.loginDescription}</p>

        {/* API キーログイン */}
        {config?.authMode !== 'oauth_only' && (
          <div>
            <input
              type="password"
              placeholder="API Key"
              value={apiKey}
              onChange={(e) => setApiKey(e.target.value)}
            />
            <button onClick={handleApiKeyLogin}>
              ログイン
            </button>
          </div>
        )}

        {/* GitHub OAuth */}
        {config?.authMode !== 'api_key' && (
          <button onClick={handleGitHubLogin}>
            <GithubIcon />
            GitHub でログイン
          </button>
        )}
      </div>
    </div>
  );
}
```

#### カスタマイズ可能な項目

- **LOGIN_TITLE**: ログインページのタイトル
- **LOGIN_DESCRIPTION**: 説明文
- **LOGIN_SUB_DESCRIPTION**: サブテキスト
- **FAVICON_URL**: カスタムファビコン URL
- **AUTH_MODE**: 認証モード

### 3. GitHub OAuth コールバック (`/login/github`)

**ファイル**: `src/app/login/github/page.tsx`

#### 機能
- GitHub OAuth 認証フローの完了処理
- 認証コードの処理
- セッション確立
- ホームページへリダイレクト

#### フロー

```
1. ユーザーが「GitHub でログイン」をクリック
   ↓
2. /api/auth/github/authorize へリダイレクト
   ↓
3. GitHub 認証ページへリダイレクト
   ↓
4. ユーザーが認証を承認
   ↓
5. /login/github?code=xxx へコールバック
   ↓
6. /api/auth/github/callback でトークン取得
   ↓
7. Cookie にトークンを保存
   ↓
8. /chats へリダイレクト
```

### 4. セッション一覧 (`/chats`)

**ファイル**: `src/app/chats/page.tsx`

#### 機能
- すべてのセッションを一覧表示
- セッション検索・フィルタリング
- 新規セッション作成ボタン
- セッション詳細へのナビゲーション

#### 表示項目

```typescript
interface SessionListView {
  sessions: Session[];
  pagination: {
    page: number;
    perPage: number;
    total: number;
    hasNext: boolean;
  };
  filters: {
    status?: 'running' | 'completed' | 'failed';
    repository?: string;
    agent?: string;
    search?: string;
  };
}
```

#### UI レイアウト

```
┌─────────────────────────────────────────┐
│  TopBar                                 │
├──────────┬──────────────────────────────┤
│  Filter  │  Session Cards               │
│  Sidebar │  ┌────────────────────┐      │
│          │  │ ConversationCard   │      │
│ Status   │  │ - Name             │      │
│ □ All    │  │ - Repository       │      │
│ ☑ Active │  │ - Status           │      │
│ □ Done   │  │ - Last updated     │      │
│          │  └────────────────────┘      │
│ Repo     │  ┌────────────────────┐      │
│ ☑ repo1  │  │ ConversationCard   │      │
│ □ repo2  │  └────────────────────┘      │
│          │                              │
│          │  [Load More...]              │
└──────────┴──────────────────────────────┘
```

#### ページネーション

```typescript
const [page, setPage] = useState(1);
const perPage = 20;

const { sessions, hasNext } = await client.listSessions({
  page,
  per_page: perPage,
  status: selectedStatus,
  ...getScopeParams(),
});
```

### 5. リポジトリ別セッション一覧 (`/chats/[repo_fullname]`)

**ファイル**: `src/app/chats/[repo_fullname]/page.tsx`

#### 機能
- 特定リポジトリのセッションのみ表示
- リポジトリ情報の表示
- リポジトリ設定へのリンク

#### パラメータ

```typescript
interface ChatsPageProps {
  params: Promise<{
    repo_fullname: string; // "owner/repo" 形式
  }>;
}
```

### 6. 新規セッション作成 (`/sessions/new`)

**ファイル**: `src/app/sessions/new/page.tsx`

#### 機能
- セッション作成フォーム
- リポジトリ選択
- エージェント選択
- 初期メッセージ入力
- 環境変数設定

#### フォーム構造

```typescript
interface SessionCreateForm {
  repository: string;
  agent: string;
  initialMessage: string;
  branch: string;
  envVars: { key: string; value: string }[];
  scope: 'user' | 'team';
  teamId?: string;
}
```

#### バリデーション

```typescript
const validate = (form: SessionCreateForm) => {
  const errors: Record<string, string> = {};

  if (!form.repository) {
    errors.repository = 'リポジトリを選択してください';
  }

  if (!form.agent) {
    errors.agent = 'エージェントを選択してください';
  }

  if (form.scope === 'team' && !form.teamId) {
    errors.teamId = 'チームを選択してください';
  }

  return errors;
};
```

### 7. セッション詳細 (`/sessions/[sessionId]`)

**ファイル**: `src/app/sessions/[sessionId]/page.tsx`

#### 機能
- メッセージ一覧表示
- リアルタイムメッセージストリーミング
- メッセージ送信
- ファイルアップロード
- セッション情報表示

#### パラメータ

```typescript
interface SessionPageProps {
  params: Promise<{
    sessionId: string;
  }>;
}
```

#### メッセージローディング

```typescript
const loadMessages = async (sessionId: string) => {
  const { messages, pagination } = await client.listMessages(sessionId, {
    page: 1,
    per_page: 50,
    order: 'asc',
  });

  setMessages(messages);

  // 最新メッセージまでスクロール
  scrollToBottom();
};
```

#### ストリーミング接続

```typescript
useEffect(() => {
  const stopStreaming = client.streamSessionEvents(sessionId, {
    onMessage: (event) => {
      if (event.type === 'message_chunk') {
        updateStreamingMessage(event.data);
      } else if (event.type === 'message_complete') {
        finalizeMessage(event.data);
      }
    },
    onError: (error) => {
      showToast('ストリーミングエラー', 'error');
    },
  });

  return () => stopStreaming();
}, [sessionId]);
```

### 8. 共有セッション (`/s/[shareToken]`)

**ファイル**: `src/app/s/[shareToken]/page.tsx`

#### 機能
- 共有セッションの読み取り専用表示
- メッセージの閲覧のみ（送信不可）
- 共有情報の表示

#### パラメータ

```typescript
interface SharedSessionPageProps {
  params: Promise<{
    shareToken: string;
  }>;
}
```

#### UI の違い

```typescript
// 共有セッションではメッセージ入力を非表示
{!isShared && (
  <MessageInput
    onSend={handleSendMessage}
    disabled={isStreaming}
  />
)}

// 共有バナー表示
{isShared && (
  <div className="bg-blue-50 p-2 text-center">
    <InfoIcon className="inline mr-2" />
    これは共有セッションです（読み取り専用）
  </div>
)}
```

### 9. エージェント一覧 (`/agents`)

**ファイル**: `src/app/agents/page.tsx`

#### 機能
- 利用可能なエージェントの一覧
- エージェント検索・フィルタ
- エージェント詳細表示

#### 表示レイアウト

```
┌─────────────────────────────────────────┐
│  TopBar                                 │
├─────────────────────────────────────────┤
│  Search: [___________________] [Filter] │
├─────────────────────────────────────────┤
│  Agent Cards                            │
│  ┌─────────────────────────────────┐   │
│  │ AgentCard                       │   │
│  │ - Name: Claude Code             │   │
│  │ - Status: Stable                │   │
│  │ - Description: ...              │   │
│  │ [Use This Agent]                │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### 10. スケジュール管理 (`/schedules`)

**ファイル**: `src/app/schedules/page.tsx`

#### 機能
- スケジュール一覧表示
- 新規スケジュール作成
- スケジュール編集・削除
- 即時実行（トリガー）

#### アクション

```typescript
const handleTrigger = async (scheduleId: string) => {
  const result = await client.triggerSchedule(scheduleId);
  showToast('スケジュールを実行しました', 'success');
  router.push(`/sessions/${result.session_id}`);
};

const handleDelete = async (scheduleId: string) => {
  if (confirm('このスケジュールを削除しますか?')) {
    await client.deleteSchedule(scheduleId);
    showToast('削除しました', 'success');
    refreshSchedules();
  }
};
```

### 11. Webhook 管理 (`/webhooks`)

**ファイル**: `src/app/webhooks/page.tsx`

#### 機能
- Webhook 一覧表示
- 新規 Webhook 作成
- Webhook 編集・削除
- シークレット再生成

#### Webhook URL 表示

```typescript
<div className="webhook-url">
  <label>Webhook URL</label>
  <div className="flex items-center">
    <code className="flex-1">
      {`${baseUrl}/api/webhooks/${webhook.id}`}
    </code>
    <button onClick={() => copyToClipboard(webhook.url)}>
      <CopyIcon />
    </button>
  </div>
</div>
```

### 12. 個人設定 (`/settings/personal`)

**ファイル**: `src/app/settings/personal/page.tsx`

#### 機能
- 個人設定の表示・編集
- GitHub トークン設定
- Claude OAuth 設定
- Bedrock 設定
- MCP サーバー設定
- プラグイン設定
- UI カスタマイズ

#### 設定セクション

```typescript
<SettingsAccordion title="GitHub トークン">
  <GithubTokenSettings />
</SettingsAccordion>

<SettingsAccordion title="Claude OAuth">
  <ClaudeOAuthSettings />
</SettingsAccordion>

<SettingsAccordion title="Bedrock 設定">
  <BedrockSettings />
</SettingsAccordion>

<SettingsAccordion title="MCP サーバー">
  <MCPServerSettings />
</SettingsAccordion>

<SettingsAccordion title="プラグイン">
  <PluginSettings />
</SettingsAccordion>

<SettingsAccordion title="キーバインド">
  <KeyBindingSettings />
</SettingsAccordion>

<SettingsAccordion title="フォント">
  <FontSettings />
</SettingsAccordion>

<SettingsAccordion title="実験的機能">
  <ExperimentalSettings />
</SettingsAccordion>
```

### 13. チーム設定 (`/settings/team`)

**ファイル**: `src/app/settings/team/page.tsx`

#### 機能
- チーム設定の表示・編集
- チームメンバー管理
- チーム共有設定

#### 権限チェック

```typescript
const { selectedTeam, isTeamScope } = useTeamScope();

if (!isTeamScope) {
  return (
    <div>
      <p>チームを選択してください</p>
    </div>
  );
}
```

### 14. AgentAPI 直接接続 (`/agentapi`)

**ファイル**: `src/app/agentapi/page.tsx`

#### 機能
- AgentAPI への直接接続
- プロキシを経由しない通信
- URL パラメータでセッション指定可能

#### URL パラメータ

```
/agentapi?session=<session_id>
```

### 15. オフラインページ (`/offline`)

**ファイル**: `src/app/offline/page.tsx`

#### 機能
- ネットワーク接続なし時の表示
- オフラインで利用可能な機能の案内
- 再接続の検出

#### UI

```typescript
export default function OfflinePage() {
  const [isOnline, setIsOnline] = useState(false);

  useEffect(() => {
    const handleOnline = () => {
      setIsOnline(true);
      router.push('/');
    };

    window.addEventListener('online', handleOnline);
    return () => window.removeEventListener('online', handleOnline);
  }, []);

  return (
    <div className="flex items-center justify-center min-h-screen">
      <div className="text-center">
        <WifiOffIcon className="w-16 h-16 mx-auto mb-4" />
        <h1>オフラインです</h1>
        <p>インターネット接続を確認してください</p>
        {isOnline && <p>再接続しました...</p>}
      </div>
    </div>
  );
}
```

## ナビゲーション

### TopBar ナビゲーション

```typescript
const navigation = [
  { name: 'チャット', href: '/chats', icon: MessageSquare },
  { name: 'エージェント', href: '/agents', icon: Bot },
  { name: 'スケジュール', href: '/schedules', icon: Clock },
  { name: 'Webhook', href: '/webhooks', icon: Webhook },
  { name: '設定', href: '/settings/personal', icon: Settings },
];
```

### モバイルナビゲーション

```typescript
// ハンバーガーメニュー
<MobileMenu>
  {navigation.map((item) => (
    <MobileMenuItem key={item.name} {...item} />
  ))}
</MobileMenu>
```

## リダイレクト処理

### 認証リダイレクト

```typescript
// middleware.ts
export function middleware(request: NextRequest) {
  const authCookie = request.cookies.get('auth_token');
  const { pathname } = request.nextUrl;

  // 未認証ユーザーを /login へリダイレクト
  if (!authCookie && !pathname.startsWith('/login')) {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  // 認証済みユーザーが /login にアクセスしたら / へリダイレクト
  if (authCookie && pathname === '/login') {
    return NextResponse.redirect(new URL('/', request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    '/((?!api|_next/static|_next/image|favicon.ico|manifest.json|sw.js).*)',
  ],
};
```

## 次のステップ

- [API 統合](./api-integration.md) - API 通信の詳細
- [機能と UI](./features.md) - 各ページの機能詳細
- [設定リファレンス](./configuration.md) - 設定項目の詳細
