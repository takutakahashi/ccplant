# 主要機能とユーザーインターフェース

## 概要

このドキュメントでは、agentapi-ui の主要機能とユーザーインターフェースについて詳しく説明します。各機能の使い方、UI コンポーネント、ユーザーエクスペリエンスの設計について解説します。

## 1. セッション管理

### セッション一覧（Conversations）

**パス**: `/chats`

セッション一覧ページでは、作成されたすべてのセッションを確認できます。

#### 主要機能

- **セッション検索**: キーワードによるセッション検索
- **フィルタリング**: ステータス、リポジトリ、エージェントでフィルタ
- **ソート**: 作成日時、更新日時、名前でソート
- **ステータス表示**: アクティブ、完了、エラーなどのステータスバッジ
- **クイックアクション**: セッション詳細、削除、共有

#### UI コンポーネント

```typescript
// ConversationCard コンポーネント
interface ConversationCardProps {
  session: Session;
  onClick: () => void;
  onDelete?: (id: string) => void;
  onShare?: (id: string) => void;
}
```

**表示情報**:
- セッション名
- リポジトリ情報
- エージェント名
- ステータスバッジ
- 作成日時・更新日時
- 最終メッセージプレビュー

#### ステータスバッジ

| ステータス | 色 | 説明 |
|----------|---|-----|
| `running` | 青 | 実行中 |
| `pending` | 黄 | 待機中 |
| `completed` | 緑 | 完了 |
| `failed` | 赤 | エラー |
| `stopped` | グレー | 停止 |

### 新規セッション作成

**パス**: `/sessions/new`

新しいセッションを作成するためのモーダル/ページ。

#### 作成フロー

1. **リポジトリ選択**: GitHub リポジトリを選択
2. **エージェント選択**: 使用するエージェントを選択
3. **初期メッセージ**: セッション開始時のメッセージ（オプション）
4. **設定**: ブランチ、環境変数などの設定
5. **作成**: セッションを作成して開始

```typescript
interface CreateSessionRequest {
  repository: string;
  agent_id: string;
  initial_message?: string;
  branch?: string;
  env_vars?: Record<string, string>;
  scope?: 'user' | 'team';
  team_id?: string;
}
```

### セッション詳細（チャット画面）

**パス**: `/sessions/[sessionId]`

セッションの詳細とチャットインターフェース。

#### レイアウト構造

```
┌─────────────────────────────────────────┐
│  TopBar (ナビゲーション)                  │
├─────────────────────────────────────────┤
│                                         │
│  MessageList (メッセージ一覧)            │
│  ├─ UserMessage                         │
│  ├─ AssistantMessage (ストリーミング)    │
│  └─ SystemMessage                       │
│                                         │
├─────────────────────────────────────────┤
│  MessageInput (入力フォーム)             │
│  ├─ テキストエリア                       │
│  ├─ ファイルアップロードボタン            │
│  └─ 送信ボタン                          │
└─────────────────────────────────────────┘
```

#### メッセージ表示

**ユーザーメッセージ**:
```typescript
<div className="flex justify-end">
  <div className="bg-blue-500 text-white rounded-lg p-3">
    {message.content}
  </div>
</div>
```

**アシスタントメッセージ**:
```typescript
<div className="flex justify-start">
  <div className="bg-gray-100 rounded-lg p-3">
    <ReactMarkdown>{message.content}</ReactMarkdown>
  </div>
</div>
```

**システムメッセージ**:
```typescript
<div className="flex justify-center">
  <div className="bg-yellow-50 text-yellow-800 rounded p-2 text-sm">
    {message.content}
  </div>
</div>
```

#### リアルタイムストリーミング

AI の応答はリアルタイムでストリーミング表示されます。

```typescript
// SSE によるストリーミング受信
streamSessionEvents(sessionId, {
  onMessage: (event: SessionEventData) => {
    if (event.type === 'message_chunk') {
      // メッセージを部分的に更新
      setMessages(prev => updateMessageChunk(prev, event.data));
    }
  },
  onError: (error) => {
    showToast('エラーが発生しました', 'error');
  },
  onComplete: () => {
    // ストリーミング完了
    setIsStreaming(false);
  }
});
```

#### ファイルアップロード

```typescript
// ドラッグ&ドロップまたはクリックでファイル選択
<input
  type="file"
  multiple
  onChange={handleFileUpload}
  className="hidden"
  ref={fileInputRef}
/>

// プレビュー表示
{files.map(file => (
  <div key={file.name} className="file-preview">
    <FileIcon />
    <span>{file.name}</span>
    <button onClick={() => removeFile(file)}>×</button>
  </div>
))}
```

### セッション共有

**パス**: `/s/[shareToken]`

セッションを他のユーザーと共有できます。

#### 共有機能

1. **共有トークン生成**: セッションの共有トークンを生成
2. **共有 URL**: `https://your-domain.com/s/{shareToken}`
3. **読み取り専用**: 共有されたセッションは読み取り専用
4. **有効期限**: 共有トークンの有効期限設定（オプション）

```typescript
interface ShareSession {
  token: string;
  session_id: string;
  expires_at?: string;
  created_at: string;
}
```

## 2. エージェント管理

**パス**: `/agents`

利用可能なエージェントの一覧と管理。

### エージェント一覧

#### 表示情報

- **エージェント名**: エージェントの名前
- **説明**: エージェントの説明
- **ステータス**: 安定版、実験版、非推奨など
- **バージョン**: エージェントのバージョン
- **最終アクティビティ**: 最後に使用された日時

#### フィルタとソート

```typescript
interface AgentListParams {
  status?: 'stable' | 'experimental' | 'deprecated';
  search?: string;
  sort?: 'name' | 'last_used' | 'created_at';
  order?: 'asc' | 'desc';
}
```

### エージェント詳細

各エージェントの詳細情報を表示。

- **機能説明**: エージェントができること
- **使用例**: 具体的な使用例
- **設定項目**: カスタマイズ可能な設定
- **実行履歴**: 過去の実行履歴

## 3. スケジュール管理

**パス**: `/schedules`

定期実行スケジュールの作成と管理。

### スケジュール一覧

#### 表示項目

- **スケジュール名**: わかりやすい名前
- **Cron 式**: 実行スケジュール
- **次回実行時刻**: 次に実行される時刻
- **ステータス**: 有効/無効
- **最終実行結果**: 成功/失敗

#### スケジュールカード

```typescript
interface ScheduleCardProps {
  schedule: Schedule;
  onEdit: (id: string) => void;
  onDelete: (id: string) => void;
  onTrigger: (id: string) => void;
}
```

### スケジュール作成・編集

#### 作成フォーム

```typescript
interface CreateScheduleRequest {
  name: string;
  description?: string;
  cron_expression: string;
  repository: string;
  agent_id: string;
  message: string;
  enabled: boolean;
  scope?: 'user' | 'team';
  team_id?: string;
}
```

#### Cron 式エディタ

視覚的に Cron 式を作成できるエディタ。

```
┌─────────────────────────────────────┐
│  分   時   日   月   曜日              │
│  *    *    *    *    *               │
│  ↓    ↓    ↓    ↓    ↓              │
│  毎分  毎時  毎日  毎月  毎週          │
└─────────────────────────────────────┘

プリセット:
- 毎日午前9時: 0 9 * * *
- 毎週月曜日午前10時: 0 10 * * 1
- 毎月1日午前0時: 0 0 1 * *
```

### スケジュール実行履歴

各スケジュールの実行履歴を表示。

- **実行日時**: いつ実行されたか
- **結果**: 成功/失敗
- **実行時間**: 実行にかかった時間
- **セッション ID**: 作成されたセッションへのリンク
- **エラーメッセージ**: 失敗時のエラー詳細

## 4. Webhook 管理

**パス**: `/webhooks`

Webhook エンドポイントの作成と管理。

### Webhook 一覧

#### 表示項目

- **Webhook 名**: わかりやすい名前
- **URL**: Webhook エンドポイント URL
- **イベント**: トリガーとなるイベント
- **ステータス**: 有効/無効
- **最終実行**: 最後にトリガーされた日時

#### Webhook カード

```typescript
interface WebhookCardProps {
  webhook: Webhook;
  onEdit: (id: string) => void;
  onDelete: (id: string) => void;
  onRegenerateSecret: (id: string) => void;
}
```

### Webhook 作成・編集

#### 作成フォーム

```typescript
interface CreateWebhookRequest {
  name: string;
  description?: string;
  events: string[];
  repository: string;
  agent_id: string;
  message_template: string;
  enabled: boolean;
  scope?: 'user' | 'team';
  team_id?: string;
}
```

#### イベント選択

利用可能なイベント:
- `push`: Git プッシュ
- `pull_request`: プルリクエスト
- `issues`: Issue の作成・更新
- `issue_comment`: Issue コメント
- `release`: リリース作成

### Webhook シークレット

```typescript
// シークレットの表示（初回のみ）
<div className="bg-yellow-50 p-4 rounded">
  <p className="font-semibold">Webhook シークレット</p>
  <code className="bg-white px-2 py-1 rounded">
    {webhook.secret}
  </code>
  <p className="text-sm text-yellow-700 mt-2">
    ⚠️ このシークレットは一度しか表示されません。
    安全な場所に保管してください。
  </p>
</div>

// シークレット再生成
<button onClick={handleRegenerateSecret}>
  シークレットを再生成
</button>
```

### Webhook 実行履歴

各 Webhook の実行履歴を表示。

- **実行日時**: いつトリガーされたか
- **イベント**: どのイベントでトリガーされたか
- **結果**: 成功/失敗
- **ペイロード**: 受信したペイロード
- **セッション ID**: 作成されたセッションへのリンク

## 5. 設定管理

### 個人設定

**パス**: `/settings/personal`

個人用の設定を管理。

#### 設定項目

##### GitHub トークン設定
```typescript
interface GithubTokenSettings {
  token: string;
  send_on_session_start: boolean;
  repositories: string[];
}
```

##### Claude OAuth 設定
```typescript
interface ClaudeOAuthSettings {
  access_token: string;
  refresh_token: string;
  expires_at: string;
}
```

##### Bedrock 設定
```typescript
interface BedrockSettings {
  region: string;
  access_key_id: string;
  secret_access_key: string;
  model_id: string;
}
```

##### MCP サーバー設定
```typescript
interface MCPServerSettings {
  servers: {
    name: string;
    url: string;
    api_key?: string;
  }[];
}
```

##### プラグイン設定
```typescript
interface PluginSettings {
  enabled_plugins: string[];
  plugin_configs: Record<string, Record<string, unknown>>;
}
```

##### キーバインド設定
```typescript
interface KeyBindingSettings {
  send_message: string;  // デフォルト: "Cmd+Enter" / "Ctrl+Enter"
  new_session: string;
  search: string;
}
```

##### フォント設定
```typescript
interface FontSettings {
  font_family: string;
  font_size: number;
  line_height: number;
}
```

##### 実験的機能
```typescript
interface ExperimentalSettings {
  enable_code_suggestions: boolean;
  enable_auto_completion: boolean;
  enable_advanced_formatting: boolean;
}
```

### チーム設定

**パス**: `/settings/team`

チーム全体で共有する設定を管理。

#### チーム設定の特徴

- **チームメンバー**: チームメンバーの一覧と権限管理
- **共有設定**: チーム全体で共有する設定
- **デフォルト値**: 新規メンバーのデフォルト設定
- **権限管理**: 各メンバーの権限レベル

### 設定の優先順位

```
個人設定 > チーム設定 > デフォルト設定
```

## 6. PWA 機能

### インストール

#### インストールプロンプト

```typescript
// インストール可能になったら表示
<div className="install-prompt">
  <p>ホーム画面に AgentAPI UI を追加しますか?</p>
  <button onClick={handleInstall}>インストール</button>
  <button onClick={handleDismiss}>後で</button>
</div>
```

#### インストール後の体験

- **スプラッシュスクリーン**: アプリ起動時のスプラッシュ画面
- **スタンドアロンモード**: ブラウザの UI なしで動作
- **ホーム画面アイコン**: カスタマイズ可能なアイコン

### オフラインサポート

**パス**: `/offline`

ネットワーク接続がない場合のオフラインページ。

```typescript
// Service Worker によるキャッシング
workbox.routing.registerRoute(
  /^https:\/\/your-domain\.com\/api\//,
  new workbox.strategies.NetworkFirst({
    cacheName: 'api-cache',
    plugins: [
      new workbox.expiration.ExpirationPlugin({
        maxEntries: 50,
        maxAgeSeconds: 5 * 60, // 5分
      }),
    ],
  })
);
```

### プッシュ通知

#### 通知許可のリクエスト

```typescript
// 通知許可を取得
async function requestNotificationPermission() {
  const permission = await Notification.requestPermission();
  if (permission === 'granted') {
    // プッシュ通知の購読を開始
    await subscribeToPushNotifications();
  }
}
```

#### プッシュ通知の種類

1. **セッション完了通知**
   ```
   タイトル: セッションが完了しました
   本文: "プロジェクト setup" が正常に完了しました
   アクション: [開く] [閉じる]
   ```

2. **エラー通知**
   ```
   タイトル: エラーが発生しました
   本文: セッション "deploy to prod" でエラーが発生しました
   アクション: [詳細を見る] [閉じる]
   ```

3. **スケジュール実行通知**
   ```
   タイトル: スケジュールが実行されました
   本文: "毎日のバックアップ" が実行されました
   アクション: [結果を見る] [閉じる]
   ```

#### プッシュ通知設定

```typescript
interface PushNotificationSettings {
  enabled: boolean;
  notify_on_completion: boolean;
  notify_on_error: boolean;
  notify_on_schedule: boolean;
  quiet_hours: {
    enabled: boolean;
    start: string; // "22:00"
    end: string;   // "08:00"
  };
}
```

## 7. モバイル機能

### タッチジェスチャ

- **スワイプ**: メッセージのスワイプで削除
- **ロングプレス**: メッセージのコピー、共有
- **ピンチズーム**: 画像の拡大・縮小
- **プルトゥリフレッシュ**: 一覧の更新

### モバイル最適化

```css
/* 動的ビューポートハイト */
.h-dvh {
  height: 100dvh;
}

/* セーフエリア対応 */
.safe-area-top {
  padding-top: env(safe-area-inset-top);
}

.safe-area-bottom {
  padding-bottom: env(safe-area-inset-bottom);
}
```

### ハプティックフィードバック

```typescript
// ボタンタップ時の振動
function hapticFeedback(type: 'light' | 'medium' | 'heavy') {
  if ('vibrate' in navigator) {
    const patterns = {
      light: 10,
      medium: 20,
      heavy: 30,
    };
    navigator.vibrate(patterns[type]);
  }
}
```

## 8. アクセシビリティ

### キーボードナビゲーション

- **Tab**: 次の要素へ移動
- **Shift+Tab**: 前の要素へ移動
- **Enter**: 選択/決定
- **Esc**: モーダルを閉じる
- **Cmd/Ctrl + K**: クイック検索

### スクリーンリーダー対応

```typescript
<button
  aria-label="メッセージを送信"
  aria-disabled={isSending}
  onClick={handleSend}
>
  <SendIcon aria-hidden="true" />
</button>
```

### フォーカス管理

```typescript
// モーダルオープン時のフォーカストラップ
useEffect(() => {
  if (isOpen) {
    const firstFocusable = modalRef.current?.querySelector('button, input');
    firstFocusable?.focus();
  }
}, [isOpen]);
```

## 9. テーマカスタマイズ

### カラー設定

```typescript
const { mainColor, setMainColor } = useTheme();

// カラーピッカー
<input
  type="color"
  value={mainColor}
  onChange={(e) => setMainColor(e.target.value)}
/>
```

### プリセットテーマ

```typescript
const presetThemes = [
  { name: 'ブルー', color: '#3b82f6' },
  { name: 'グリーン', color: '#10b981' },
  { name: 'パープル', color: '#8b5cf6' },
  { name: 'ピンク', color: '#ec4899' },
  { name: 'オレンジ', color: '#f59e0b' },
];
```

## 次のステップ

- [ページとルーティング](./pages-routing.md) - 各ページの詳細
- [API 統合](./api-integration.md) - API 通信の詳細
- [PWA 機能](./pwa.md) - PWA 機能の詳細
- [設定リファレンス](./configuration.md) - 設定項目の詳細
