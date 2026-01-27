# Progressive Web App (PWA) 機能

## 概要

agentapi-ui は Progressive Web App (PWA) として設計されており、ネイティブアプリのような体験を提供します。このドキュメントでは、PWA の機能、設定、インストール方法について詳しく説明します。

## PWA の特徴

### 1. インストール可能

ブラウザからホーム画面にアプリを追加できます。

- **iOS**: Safari の共有メニューから「ホーム画面に追加」
- **Android**: Chrome の「ホーム画面に追加」プロンプト
- **Desktop**: Chrome のアドレスバーのインストールアイコン

### 2. オフライン対応

Service Worker によるキャッシングでオフラインでも動作します。

- 静的アセット（HTML、CSS、JS）のキャッシュ
- API レスポンスのキャッシュ（短時間）
- オフライン時の専用ページ表示

### 3. プッシュ通知

Web Push API によるプッシュ通知をサポートします。

- セッション完了通知
- エラー通知
- スケジュール実行通知

### 4. ネイティブアプリライクな体験

- スプラッシュスクリーン
- フルスクリーン表示
- ホーム画面アイコン
- ステータスバーのカスタマイズ

## PWA マニフェスト

### マニフェスト設定

**ファイル**: `src/app/manifest.ts`

```typescript
export default function manifest(): MetadataRoute.Manifest {
  const appName = process.env.PWA_APP_NAME || 'AgentAPI UI'
  const shortName = process.env.PWA_SHORT_NAME || 'AgentAPI'
  const description = process.env.PWA_DESCRIPTION ||
    'User interface for AgentAPI - AI agent conversation management'

  const customIconUrl = process.env.PWA_ICON_URL

  const icons: MetadataRoute.Manifest['icons'] = customIconUrl
    ? [
        {
          src: customIconUrl,
          sizes: '192x192',
          type: 'image/png',
          purpose: 'maskable',
        },
        {
          src: customIconUrl,
          sizes: '512x512',
          type: 'image/png',
          purpose: 'maskable',
        },
      ]
    : [
        {
          src: '/icon-192x192.png',
          sizes: '192x192',
          type: 'image/png',
          purpose: 'maskable',
        },
        {
          src: '/icon-512x512.png',
          sizes: '512x512',
          type: 'image/png',
          purpose: 'maskable',
        },
      ]

  return {
    name: appName,
    short_name: shortName,
    description: description,
    theme_color: '#000000',
    background_color: '#ffffff',
    display: 'standalone',
    orientation: 'portrait',
    scope: '/',
    start_url: '/',
    icons,
  }
}
```

### マニフェストプロパティ

| プロパティ | 値 | 説明 |
|----------|---|-----|
| `name` | `AgentAPI UI` | フルネーム（インストールプロンプトで表示） |
| `short_name` | `AgentAPI` | 短縮名（ホーム画面で表示） |
| `description` | `User interface for...` | アプリの説明 |
| `theme_color` | `#000000` | テーマカラー（ステータスバー等） |
| `background_color` | `#ffffff` | スプラッシュスクリーンの背景色 |
| `display` | `standalone` | 表示モード（フルスクリーン風） |
| `orientation` | `portrait` | 推奨画面向き |
| `scope` | `/` | PWA のスコープ |
| `start_url` | `/` | 起動時の URL |
| `icons` | 配列 | アプリアイコン |

### アイコンの要件

#### サイズ

- **192x192**: 必須（Android ホーム画面）
- **512x512**: 必須（スプラッシュスクリーン）
- **256x256、384x384**: オプション（追加解像度）

#### フォーマット

- PNG 形式推奨
- 透過背景可
- 正方形

#### Purpose

- `maskable`: Android の適応型アイコンに対応
- `any`: 通常のアイコン表示

### カスタムアイコンの設定

```bash
# 環境変数で設定
PWA_ICON_URL=https://example.com/custom-icon.png
```

カスタムアイコンを設定すると、すべてのサイズでこの URL が使用されます。

## Service Worker

### next-pwa 設定

**ファイル**: `next.config.js`

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

module.exports = withPWA({
  // Next.js 設定
})
```

### 設定オプション

| オプション | 値 | 説明 |
|----------|---|-----|
| `dest` | `public` | Service Worker の出力先 |
| `register` | `true` | 自動登録を有効化 |
| `skipWaiting` | `true` | 新しい SW を即座に有効化 |
| `disable` | 開発環境では `true` | 開発中は無効化 |
| `fallbacks.document` | `/offline` | オフライン時のフォールバックページ |

### キャッシング戦略

#### 1. Network First（API リクエスト）

```
リクエスト
   │
   ├─ ネットワーク接続試行
   │     │
   │     ├─ 成功 → レスポンス返却 + キャッシュ更新
   │     │
   │     └─ 失敗 → キャッシュから返却
   │
   └─ キャッシュが存在しない → エラー
```

**用途**: API リクエスト、動的コンテンツ

#### 2. Cache First（静的アセット）

```
リクエスト
   │
   ├─ キャッシュ確認
   │     │
   │     ├─ 存在する → キャッシュから返却
   │     │
   │     └─ 存在しない → ネットワークから取得 + キャッシュ
   │
   └─ ネットワークも失敗 → エラー
```

**用途**: CSS、JavaScript、画像、フォント

#### 3. Stale While Revalidate（ページ）

```
リクエスト
   │
   ├─ キャッシュから即座に返却
   │
   └─ バックグラウンドでネットワークから取得
         │
         └─ 成功 → キャッシュ更新（次回のリクエストで使用）
```

**用途**: HTML ページ、頻繁に更新されるコンテンツ

### キャッシュの管理

```typescript
// キャッシュのクリア
if ('caches' in window) {
  caches.keys().then(names => {
    names.forEach(name => {
      caches.delete(name);
    });
  });
}

// Service Worker の更新
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then(registrations => {
    registrations.forEach(registration => {
      registration.update();
    });
  });
}
```

## オフラインページ

**パス**: `/offline`

**ファイル**: `src/app/offline/page.tsx`

### 実装例

```typescript
'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { WifiOffIcon } from 'lucide-react'

export default function OfflinePage() {
  const router = useRouter()
  const [isOnline, setIsOnline] = useState(false)

  useEffect(() => {
    const handleOnline = () => {
      setIsOnline(true)
      // オンラインに戻ったらホームページへリダイレクト
      setTimeout(() => {
        router.push('/')
      }, 1000)
    }

    const handleOffline = () => {
      setIsOnline(false)
    }

    window.addEventListener('online', handleOnline)
    window.addEventListener('offline', handleOffline)

    // 初期状態の確認
    setIsOnline(navigator.onLine)

    return () => {
      window.removeEventListener('online', handleOnline)
      window.removeEventListener('offline', handleOffline)
    }
  }, [router])

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="text-center">
        <WifiOffIcon className="w-16 h-16 mx-auto mb-4 text-gray-400" />
        <h1 className="text-2xl font-bold mb-2">
          {isOnline ? '接続を復元中...' : 'オフラインです'}
        </h1>
        <p className="text-gray-600 mb-4">
          {isOnline
            ? 'インターネット接続が復元されました'
            : 'インターネット接続を確認してください'}
        </p>
        {!isOnline && (
          <button
            onClick={() => window.location.reload()}
            className="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
          >
            再試行
          </button>
        )}
      </div>
    </div>
  )
}
```

### オフラインで利用可能な機能

- ✅ キャッシュされたページの閲覧
- ✅ 以前に読み込んだセッションの表示
- ✅ ローカル設定の変更
- ❌ 新しいセッションの作成
- ❌ メッセージの送信
- ❌ API リクエスト

## プッシュ通知

### VAPID キーの生成

```bash
# VAPID キーペアを生成
npx web-push generate-vapid-keys

# 出力例:
# =============== VAPID keys ===============
# Public Key: BOv-qOWAZ4--eLYAQNk-0jZPDGHH3rrmb4RFaQglVpdz_zQrS5wH1puNS4aWoWSDnRbPO764YURRZt8_B2OMkDQ
# Private Key: mDe1TZnHJAshXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# ==========================================
```

### 環境変数の設定

```bash
# .env
VAPID_PUBLIC_KEY=BOv-qOWAZ4--eLYAQNk-0jZPDGHH3rrmb4RFaQglVpdz_zQrS5wH1puNS4aWoWSDnRbPO764YURRZt8_B2OMkDQ
VAPID_PRIVATE_KEY=mDe1TZnHJAshXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### プッシュ通知の購読

**ファイル**: `src/lib/subscriptions.ts`

```typescript
export async function subscribeToPushNotifications(): Promise<PushSubscription> {
  if (!('serviceWorker' in navigator)) {
    throw new Error('Service Worker not supported')
  }

  if (!('PushManager' in window)) {
    throw new Error('Push notifications not supported')
  }

  // 通知の許可を取得
  const permission = await Notification.requestPermission()
  if (permission !== 'granted') {
    throw new Error('Notification permission denied')
  }

  // Service Worker の登録を取得
  const registration = await navigator.serviceWorker.ready

  // VAPID 公開鍵を取得
  const response = await fetch('/api/config')
  const { vapidPublicKey } = await response.json()

  if (!vapidPublicKey) {
    throw new Error('VAPID public key not configured')
  }

  // プッシュ通知を購読
  const subscription = await registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: urlBase64ToUint8Array(vapidPublicKey),
  })

  // サーバーに購読情報を送信
  await fetch('/api/push/subscribe', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(subscription),
  })

  return subscription
}
```

### プッシュ通知の種類

#### 1. セッション完了通知

```typescript
{
  title: 'セッションが完了しました',
  body: '"プロジェクト setup" が正常に完了しました',
  icon: '/icon-192x192.png',
  badge: '/badge-72x72.png',
  tag: 'session-complete',
  data: {
    sessionId: 'session-123',
    url: '/sessions/session-123',
  },
  actions: [
    { action: 'open', title: '開く' },
    { action: 'close', title: '閉じる' },
  ],
}
```

#### 2. エラー通知

```typescript
{
  title: 'エラーが発生しました',
  body: 'セッション "deploy to prod" でエラーが発生しました',
  icon: '/icon-192x192.png',
  badge: '/badge-72x72.png',
  tag: 'session-error',
  data: {
    sessionId: 'session-456',
    url: '/sessions/session-456',
  },
  requireInteraction: true,
  actions: [
    { action: 'view', title: '詳細を見る' },
    { action: 'close', title: '閉じる' },
  ],
}
```

#### 3. スケジュール実行通知

```typescript
{
  title: 'スケジュールが実行されました',
  body: '"毎日のバックアップ" が実行されました',
  icon: '/icon-192x192.png',
  tag: 'schedule-run',
  data: {
    scheduleId: 'schedule-789',
    sessionId: 'session-999',
    url: '/schedules',
  },
  actions: [
    { action: 'view', title: '結果を見る' },
  ],
}
```

### プッシュ通知の処理

**ファイル**: `public/sw.js` (Service Worker)

```javascript
self.addEventListener('push', function(event) {
  if (!event.data) return

  const data = event.data.json()

  const options = {
    body: data.body,
    icon: data.icon || '/icon-192x192.png',
    badge: data.badge || '/badge-72x72.png',
    tag: data.tag,
    data: data.data,
    actions: data.actions,
    requireInteraction: data.requireInteraction || false,
  }

  event.waitUntil(
    self.registration.showNotification(data.title, options)
  )
})

self.addEventListener('notificationclick', function(event) {
  event.notification.close()

  if (event.action === 'close') {
    return
  }

  const url = event.notification.data?.url || '/'

  event.waitUntil(
    clients.openWindow(url)
  )
})
```

### 通知設定

**ファイル**: `src/components/PushNotificationSettings.tsx`

```typescript
export function PushNotificationSettings() {
  const [enabled, setEnabled] = useState(false)
  const [subscription, setSubscription] = useState<PushSubscription | null>(null)

  const handleEnable = async () => {
    try {
      const sub = await subscribeToPushNotifications()
      setSubscription(sub)
      setEnabled(true)
      showToast('プッシュ通知を有効にしました', 'success')
    } catch (error) {
      showToast('プッシュ通知の有効化に失敗しました', 'error')
    }
  }

  const handleDisable = async () => {
    if (!subscription) return

    try {
      await subscription.unsubscribe()
      await fetch('/api/push/unsubscribe', { method: 'POST' })
      setSubscription(null)
      setEnabled(false)
      showToast('プッシュ通知を無効にしました', 'success')
    } catch (error) {
      showToast('プッシュ通知の無効化に失敗しました', 'error')
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <label>プッシュ通知</label>
        <button
          onClick={enabled ? handleDisable : handleEnable}
          className={enabled ? 'bg-blue-500' : 'bg-gray-300'}
        >
          {enabled ? '有効' : '無効'}
        </button>
      </div>

      {enabled && (
        <div className="space-y-2">
          <label>
            <input type="checkbox" />
            セッション完了時に通知
          </label>
          <label>
            <input type="checkbox" />
            エラー発生時に通知
          </label>
          <label>
            <input type="checkbox" />
            スケジュール実行時に通知
          </label>
        </div>
      )}
    </div>
  )
}
```

## インストールプロンプト

### 自動インストールプロンプト

ブラウザが自動的にインストールプロンプトを表示します。

#### iOS Safari
1. Safari でサイトを開く
2. 共有ボタンをタップ
3. 「ホーム画面に追加」を選択

#### Android Chrome
1. Chrome でサイトを開く
2. 自動的にプロンプトが表示される
3. 「インストール」をタップ

#### Desktop Chrome
1. Chrome でサイトを開く
2. アドレスバーのインストールアイコンをクリック
3. 「インストール」をクリック

### カスタムインストールプロンプト

```typescript
'use client'

import { useEffect, useState } from 'react'

export function InstallPrompt() {
  const [deferredPrompt, setDeferredPrompt] = useState<any>(null)
  const [showPrompt, setShowPrompt] = useState(false)

  useEffect(() => {
    const handler = (e: Event) => {
      // デフォルトのプロンプトを防止
      e.preventDefault()
      // プロンプトを保存
      setDeferredPrompt(e)
      setShowPrompt(true)
    }

    window.addEventListener('beforeinstallprompt', handler)

    return () => {
      window.removeEventListener('beforeinstallprompt', handler)
    }
  }, [])

  const handleInstall = async () => {
    if (!deferredPrompt) return

    // プロンプトを表示
    deferredPrompt.prompt()

    // ユーザーの選択を待つ
    const { outcome } = await deferredPrompt.userChoice

    if (outcome === 'accepted') {
      console.log('User accepted the install prompt')
    }

    setDeferredPrompt(null)
    setShowPrompt(false)
  }

  const handleDismiss = () => {
    setShowPrompt(false)
  }

  if (!showPrompt) return null

  return (
    <div className="fixed bottom-0 left-0 right-0 bg-blue-500 text-white p-4">
      <div className="max-w-4xl mx-auto flex items-center justify-between">
        <div>
          <p className="font-semibold">ホーム画面に追加</p>
          <p className="text-sm">AgentAPI UI をインストールしますか?</p>
        </div>
        <div className="flex space-x-2">
          <button
            onClick={handleInstall}
            className="px-4 py-2 bg-white text-blue-500 rounded"
          >
            インストール
          </button>
          <button
            onClick={handleDismiss}
            className="px-4 py-2 bg-blue-600 rounded"
          >
            後で
          </button>
        </div>
      </div>
    </div>
  )
}
```

## PWA のデバッグ

### Chrome DevTools

1. **Application タブ**を開く
2. **Manifest** セクションでマニフェストを確認
3. **Service Workers** セクションで Service Worker を確認
4. **Cache Storage** でキャッシュを確認
5. **Push Messaging** でプッシュ通知をテスト

### Service Worker のデバッグ

```bash
# Service Worker のログ
chrome://serviceworker-internals/

# キャッシュの確認
chrome://cache/
```

### プッシュ通知のテスト

```typescript
// テスト通知を送信
async function sendTestNotification() {
  const response = await fetch('/api/push/test', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      title: 'テスト通知',
      body: 'これはテスト通知です',
    }),
  })

  if (response.ok) {
    console.log('Test notification sent')
  }
}
```

## パフォーマンス最適化

### Lighthouse スコア

PWA の品質を測定するために Lighthouse を使用します。

```bash
# Lighthouse を実行
npx lighthouse https://your-domain.com --view

# PWA カテゴリのチェック項目:
# ✅ インストール可能
# ✅ PWA に最適化されている
# ✅ オフラインで動作する
# ✅ ホーム画面に追加可能
```

### 目標スコア

- **Performance**: 90+
- **Accessibility**: 90+
- **Best Practices**: 90+
- **SEO**: 90+
- **PWA**: 完全準拠

## トラブルシューティング

### Service Worker が登録されない

**原因**: HTTPS が必須（localhost を除く）

**解決方法**:
```bash
# 開発環境で HTTPS を使用
npm run dev -- --https
```

### プッシュ通知が届かない

**確認事項**:
1. VAPID キーが正しく設定されているか
2. 通知の許可が得られているか
3. Service Worker が登録されているか
4. ブラウザがプッシュ通知をサポートしているか

### キャッシュが更新されない

**解決方法**:
```typescript
// Service Worker を強制更新
navigator.serviceWorker.getRegistrations().then(registrations => {
  registrations.forEach(registration => {
    registration.unregister()
  })
  window.location.reload()
})
```

## 次のステップ

- [設定リファレンス](./configuration.md) - PWA 設定の詳細
- [機能と UI](./features.md) - PWA 機能の使い方
- [アーキテクチャ](./architecture.md) - PWA アーキテクチャの詳細
