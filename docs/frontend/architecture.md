# フロントエンドアーキテクチャ

## 概要

agentapi-ui は Next.js 15 の App Router を使用したモダンな React アプリケーションです。このドキュメントでは、フロントエンドのアーキテクチャ、ディレクトリ構造、コンポーネント設計、状態管理について詳しく説明します。

## ディレクトリ構造

```
src/
├── app/                          # Next.js App Router
│   ├── api/                      # API Routes (Backend for Frontend)
│   │   ├── auth/                 # 認証 API
│   │   │   ├── login/           # ログイン処理
│   │   │   ├── logout/          # ログアウト処理
│   │   │   ├── status/          # 認証ステータス確認
│   │   │   └── github/          # GitHub OAuth
│   │   ├── proxy/[...path]/     # agentapi-proxy へのプロキシ
│   │   ├── config/              # 設定 API
│   │   ├── encrypt/decrypt/     # Cookie 暗号化 API
│   │   ├── manifest/            # PWA マニフェスト
│   │   └── user/info/           # ユーザー情報
│   ├── components/               # 共有コンポーネント
│   ├── hooks/                    # カスタムフック
│   ├── agentapi/                 # AgentAPI 直接接続ページ
│   ├── agents/                   # エージェント管理ページ
│   ├── chats/                    # チャット一覧ページ
│   ├── login/                    # ログインページ
│   ├── sessions/[sessionId]/     # セッション詳細ページ
│   ├── schedules/                # スケジュール管理ページ
│   ├── webhooks/                 # Webhook 管理ページ
│   ├── settings/                 # 設定ページ
│   ├── offline/                  # オフラインページ
│   ├── s/[shareToken]/           # 共有セッションページ
│   ├── layout.tsx                # ルートレイアウト
│   ├── page.tsx                  # ホームページ
│   ├── globals.css               # グローバルスタイル
│   └── manifest.ts               # PWA マニフェスト定義
├── components/                   # 共有 React コンポーネント
│   ├── settings/                 # 設定関連コンポーネント
│   ├── Toast.tsx                 # トースト通知
│   └── ...
├── contexts/                     # React Context プロバイダー
│   ├── ThemeContext.tsx          # テーマ管理
│   ├── TeamScopeContext.tsx      # チームスコープ管理
│   └── ToastContext.tsx          # トースト通知管理
├── lib/                          # ライブラリとユーティリティ
│   ├── agentapi-proxy-client.ts  # API クライアント
│   ├── cookie-encryption.ts      # Cookie 暗号化
│   ├── api.ts                    # API ヘルパー
│   ├── subscriptions.ts          # プッシュ通知購読
│   ├── oauth-utils.ts            # OAuth ユーティリティ
│   └── encryption-api.ts         # 暗号化 API
├── utils/                        # ユーティリティ関数
│   ├── pushNotification.ts       # プッシュ通知
│   ├── messageTemplateManager.ts # メッセージテンプレート
│   ├── timeUtils.ts              # 時間関連ユーティリティ
│   └── ...
├── types/                        # TypeScript 型定義
│   ├── agentapi.ts               # AgentAPI 型
│   ├── schedule.ts               # スケジュール型
│   ├── webhook.ts                # Webhook 型
│   ├── settings.ts               # 設定型
│   └── user.ts                   # ユーザー型
└── hooks/                        # カスタムフック
    ├── useConfig.ts              # 設定フック
    └── useTheme.ts               # テーマフック
```

## Next.js App Router アーキテクチャ

### App Router の特徴

agentapi-ui は Next.js 15 の App Router を採用しています。これにより以下の利点があります：

1. **ファイルベースルーティング**: ディレクトリ構造が URL 構造に対応
2. **レイアウトの入れ子**: 共通レイアウトの効率的な共有
3. **サーバーコンポーネント**: デフォルトでサーバーサイドレンダリング
4. **ストリーミング**: Suspense によるストリーミング SSR
5. **API Routes**: 同じプロジェクト内で API エンドポイントを定義

### ルートレイアウト

```typescript
// src/app/layout.tsx
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        <link rel="icon" href="/favicon.ico" />
        <link rel="apple-touch-icon" href="/icon-192x192.png" />
        <link rel="manifest" href="/api/manifest" />
      </head>
      <body className={inter.className}>
        <ThemeProvider>
          <TeamScopeProvider>
            <ToastProvider>
              {children}
              <ToastContainer />
              <PushNotificationAutoInit />
              <DynamicFavicon />
              <Analytics />
            </ToastProvider>
          </TeamScopeProvider>
        </ThemeProvider>
      </body>
    </html>
  )
}
```

### ページコンポーネント

```typescript
// src/app/sessions/[sessionId]/page.tsx
'use client'

export default function SessionPage({ params }: SessionPageProps) {
  const resolvedParams = use(params)

  return (
    <div className="h-dvh bg-gray-50">
      <Suspense fallback={<LoadingSpinner />}>
        <AgentAPIChat sessionId={resolvedParams.sessionId} />
      </Suspense>
    </div>
  )
}
```

## コンポーネントアーキテクチャ

### コンポーネント設計原則

1. **単一責任の原則**: 各コンポーネントは単一の責任を持つ
2. **再利用性**: 汎用的なコンポーネントは共有ディレクトリに配置
3. **型安全性**: すべてのコンポーネントは TypeScript で型定義
4. **テスタビリティ**: ユニットテストが容易な設計

### コンポーネント階層

```
RootLayout
├── ThemeProvider
│   ├── TeamScopeProvider
│   │   ├── ToastProvider
│   │   │   ├── Page Components
│   │   │   │   ├── TopBar
│   │   │   │   ├── AgentAPIChat
│   │   │   │   │   ├── MessageList
│   │   │   │   │   ├── MessageInput
│   │   │   │   │   └── SessionInfo
│   │   │   │   ├── ConversationCard
│   │   │   │   ├── WebhookCard
│   │   │   │   └── ScheduleCard
│   │   │   ├── ToastContainer
│   │   │   ├── PushNotificationAutoInit
│   │   │   └── DynamicFavicon
```

### 主要コンポーネント

#### 1. AgentAPIChat
セッションのメインチャットインターフェース

```typescript
interface AgentAPIChatProps {
  sessionId: string;
  shared?: boolean;
}

// 機能:
// - メッセージの表示とスクロール管理
// - リアルタイムメッセージストリーミング
// - メッセージ送信フォーム
// - ファイルアップロード
// - セッションステータス表示
```

#### 2. ConversationCard
チャット一覧のカード表示

```typescript
interface ConversationCardProps {
  session: Session;
  onClick: () => void;
}

// 機能:
// - セッション情報の表示
// - ステータスバッジ
// - 最終更新時刻
// - クリックでセッション詳細へ遷移
```

#### 3. TopBar
ナビゲーションバー

```typescript
// 機能:
// - ページタイトル表示
// - ナビゲーションメニュー
// - ユーザー情報表示
// - チーム切り替え
// - ログアウトボタン
```

#### 4. WebhookCard / ScheduleCard
Webhook とスケジュールのカード表示

```typescript
// 機能:
// - リソース情報の表示
// - アクション（編集、削除、実行）
// - ステータス表示
// - 実行履歴へのリンク
```

## 状態管理

### React Context API

agentapi-ui は状態管理に React Context API を使用しています。

#### 1. ThemeContext

```typescript
interface ThemeContextType {
  mainColor: string;
  setMainColor: (color: string) => void;
  resetToDefault: () => void;
}
```

**責任**:
- メインカラーの管理
- CSS カスタムプロパティの更新
- localStorage への永続化

**使用例**:
```typescript
const { mainColor, setMainColor } = useTheme();
```

#### 2. TeamScopeContext

```typescript
interface TeamScopeContextType {
  selectedTeam: string | null;
  availableTeams: string[];
  setAvailableTeams: (teams: string[]) => void;
  selectTeam: (team: string | null) => void;
  getScopeParams: () => { scope: ResourceScope; team_id?: string };
  isTeamScope: boolean;
  isLoading: boolean;
}
```

**責任**:
- チームスコープの管理
- 個人/チームスコープの切り替え
- API リクエストのスコープパラメータ生成
- localStorage への永続化

**使用例**:
```typescript
const { selectedTeam, selectTeam, getScopeParams } = useTeamScope();
const params = getScopeParams(); // { scope: 'team', team_id: 'team-123' }
```

#### 3. ToastContext

```typescript
interface ToastContextType {
  showToast: (message: string, type?: 'success' | 'error' | 'info') => void;
}
```

**責任**:
- トースト通知の表示
- 自動非表示タイマーの管理
- 複数トーストのキュー管理

**使用例**:
```typescript
const { showToast } = useToast();
showToast('保存しました', 'success');
```

### ローカルステート vs グローバルステート

| 状態の種類 | 管理方法 | 例 |
|---------|---------|---|
| ページローカル | useState | フォーム入力値、モーダル開閉状態 |
| 共有 UI 状態 | Context | テーマ、トースト通知 |
| ユーザー設定 | Context + localStorage | チーム選択、カラー設定 |
| サーバーデータ | SWR / Fetch | セッション一覧、メッセージ |

## API クライアントアーキテクチャ

### AgentAPIProxyClient クラス

```typescript
export class AgentAPIProxyClient {
  private baseURL: string;
  private apiKey?: string;
  private timeout: number;

  constructor(config: AgentAPIProxyClientConfig) {
    this.baseURL = config.baseURL.replace(/\/$/, '');
    this.apiKey = config.apiKey;
    this.timeout = config.timeout || 10000;
  }

  // セッション管理
  async listSessions(params?: SessionListParams): Promise<SessionListResponse>
  async createSession(request: CreateSessionRequest): Promise<Session>
  async getSession(id: string): Promise<Session>
  async deleteSession(id: string): Promise<void>

  // メッセージ管理
  async listMessages(sessionId: string, params?: SessionMessageListParams)
  async sendMessage(sessionId: string, request: SendSessionMessageRequest)
  async streamSessionEvents(sessionId: string, options: SessionEventsOptions)

  // エージェント管理
  async listAgents(params?: AgentListParams): Promise<AgentListResponse>
  async getAgent(id: string): Promise<Agent>

  // スケジュール管理
  async listSchedules(params?: ScheduleListParams): Promise<ScheduleListResponse>
  async createSchedule(request: CreateScheduleRequest): Promise<Schedule>
  async updateSchedule(id: string, request: UpdateScheduleRequest): Promise<Schedule>
  async deleteSchedule(id: string): Promise<void>
  async triggerSchedule(id: string): Promise<TriggerScheduleResponse>

  // Webhook 管理
  async listWebhooks(params?: WebhookListParams): Promise<WebhookListResponse>
  async createWebhook(request: CreateWebhookRequest): Promise<Webhook>
  async updateWebhook(id: string, request: UpdateWebhookRequest): Promise<Webhook>
  async deleteWebhook(id: string): Promise<void>
  async regenerateSecret(id: string): Promise<RegenerateSecretResponse>
}
```

### API Routes プロキシパターン

```typescript
// src/app/api/proxy/[...path]/route.ts
export async function GET(request: NextRequest) {
  const apiKey = await getApiKeyFromCookie(request);
  const proxyUrl = process.env.AGENTAPI_PROXY_URL;

  // agentapi-proxy へリクエストをプロキシ
  const response = await fetch(`${proxyUrl}${path}`, {
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
  });

  return response;
}
```

**利点**:
1. CORS の問題を回避
2. API キーをクライアントに露出しない
3. リクエスト/レスポンスの加工が可能
4. 認証の一元管理

## リアルタイム通信

### Server-Sent Events (SSE)

```typescript
async streamSessionEvents(
  sessionId: string,
  options: SessionEventsOptions
): Promise<void> {
  const url = `${this.baseURL}/v1/sessions/${sessionId}/events?stream=true`;

  const response = await fetch(url, {
    headers: {
      'Accept': 'text/event-stream',
      'Authorization': `Bearer ${this.apiKey}`,
    },
  });

  const reader = response.body?.getReader();
  const decoder = new TextDecoder();

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    const chunk = decoder.decode(value);
    const lines = chunk.split('\n');

    for (const line of lines) {
      if (line.startsWith('data: ')) {
        const data = JSON.parse(line.slice(6));
        options.onMessage?.(data);
      }
    }
  }
}
```

### WebSocket（将来的な実装）

現在は SSE を使用していますが、双方向通信が必要な機能では WebSocket の使用を検討しています。

## フック設計

### カスタムフック一覧

#### 1. useConfig

```typescript
export function useConfig() {
  const [config, setConfig] = useState<AppConfig | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch('/api/config')
      .then(res => res.json())
      .then(setConfig)
      .finally(() => setLoading(false));
  }, []);

  return { config, loading };
}
```

#### 2. usePageVisibility

```typescript
export function usePageVisibility() {
  const [isVisible, setIsVisible] = useState(true);

  useEffect(() => {
    const handleVisibilityChange = () => {
      setIsVisible(!document.hidden);
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  }, []);

  return isVisible;
}
```

## スタイリングアーキテクチャ

### Tailwind CSS

agentapi-ui は Tailwind CSS を使用してスタイリングしています。

#### CSS カスタムプロパティ

```css
:root {
  --main-color: #3b82f6;
  --main-color-rgb: 59, 130, 246;
  --main-color-light: #60a5fa;
  --main-color-dark: #2563eb;
}
```

#### ダークモード対応（将来予定）

```css
@media (prefers-color-scheme: dark) {
  :root {
    --background: #000000;
    --foreground: #ffffff;
  }
}
```

#### レスポンシブブレークポイント

```javascript
// tailwind.config.js
module.exports = {
  theme: {
    screens: {
      'sm': '640px',   // モバイル
      'md': '768px',   // タブレット
      'lg': '1024px',  // デスクトップ
      'xl': '1280px',  // ワイドデスクトップ
      '2xl': '1536px', // 超ワイド
    }
  }
}
```

## パフォーマンス最適化

### コード分割

```typescript
// 動的インポート
const DynamicComponent = dynamic(() => import('./HeavyComponent'), {
  loading: () => <LoadingSpinner />,
  ssr: false, // クライアントサイドのみ
});
```

### 画像最適化

```typescript
import Image from 'next/image';

<Image
  src={user.avatarUrl}
  alt={user.name}
  width={40}
  height={40}
  loading="lazy"
/>
```

### メモ化

```typescript
const MemoizedComponent = memo(function ExpensiveComponent({ data }) {
  // 重い計算処理
  const result = useMemo(() => processData(data), [data]);

  return <div>{result}</div>;
});
```

## エラーハンドリング

### エラーバウンダリ

```typescript
// src/app/error.tsx
'use client'

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <div>
      <h2>エラーが発生しました</h2>
      <button onClick={() => reset()}>再試行</button>
    </div>
  )
}
```

### API エラーハンドリング

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

## テスト戦略

### ユニットテスト（Vitest）

```typescript
// src/app/__tests__/page.test.tsx
import { render, screen } from '@testing-library/react';
import { describe, it, expect } from 'vitest';
import Page from '../page';

describe('Home Page', () => {
  it('renders without crashing', () => {
    render(<Page />);
    expect(screen.getByText('AgentAPI UI')).toBeInTheDocument();
  });
});
```

### E2E テスト（Playwright）

```typescript
// e2e/login.spec.ts
import { test, expect } from '@playwright/test';

test('ログインフロー', async ({ page }) => {
  await page.goto('/login');
  await page.fill('input[name="apiKey"]', 'test-key');
  await page.click('button[type="submit"]');
  await expect(page).toHaveURL('/');
});
```

## セキュリティアーキテクチャ

### Cookie 暗号化レイヤー

```typescript
// Browser → Encrypted Cookie → API Route → agentapi-proxy
[Browser]
   ↓ API Key
[encryptCookie(apiKey)]
   ↓ Encrypted Cookie
[NextRequest with Cookie]
   ↓
[decryptCookie(cookie)]
   ↓ API Key
[agentapi-proxy with Bearer token]
```

詳細は [セキュリティドキュメント](./security.md) を参照してください。

## 次のステップ

- [機能と UI](./features.md) - 主要機能の詳細
- [ページとルーティング](./pages-routing.md) - 各ページの詳細
- [API 統合](./api-integration.md) - API 通信の詳細
- [セキュリティ](./security.md) - セキュリティ実装の詳細
