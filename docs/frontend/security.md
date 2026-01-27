# セキュリティ実装

## 概要

このドキュメントでは、agentapi-ui のセキュリティ実装について詳しく説明します。Cookie 暗号化、セキュリティヘッダー、CSRF 対策、XSS 防止、セキュアコーディングプラクティスについて解説します。

## Cookie 暗号化

### AES-256-GCM による暗号化

agentapi-ui は API キーやトークンを Cookie に保存する際、AES-256-GCM 暗号化アルゴリズムを使用します。

**ファイル**: `src/lib/cookie-encryption.ts`

#### 暗号化仕様

| 項目 | 値 |
|-----|---|
| アルゴリズム | AES-256-GCM |
| キー長 | 256 ビット (32 バイト) |
| IV 長 | 128 ビット (16 バイト) |
| 認証タグ長 | 128 ビット (16 バイト) |
| ソルト長 | 256 ビット (32 バイト) |
| キー導出 | scrypt |
| エンコーディング | Base64URL |

#### 暗号化処理フロー

```
┌─────────────────────┐
│  平文 API キー       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  暗号化キーの導出    │
│  scrypt(secret, salt)│
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  ランダム IV 生成    │
│  randomBytes(16)     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  AES-256-GCM 暗号化  │
│  + 認証タグ生成      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  salt + iv + tag +   │
│  encrypted を連結    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Base64URL エンコード│
└─────────────────────┘
```

#### 暗号化関数

```typescript
export function encryptCookie(value: string): string {
  try {
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
  } catch (error) {
    console.error('Cookie encryption error:', error);
    throw new Error('Failed to encrypt cookie');
  }
}
```

#### 復号化関数

```typescript
export function decryptCookie(encryptedValue: string): string {
  try {
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
  } catch (error) {
    console.error('Cookie decryption error:', error);
    throw new Error('Failed to decrypt cookie');
  }
}
```

#### キー導出

```typescript
function getEncryptionKey(): Buffer {
  const secret = process.env.COOKIE_SECRET || process.env.NEXT_PUBLIC_COOKIE_SECRET;

  if (!secret) {
    throw new Error(
      'COOKIE_SECRET environment variable is required. ' +
      'Please set a secure secret key (at least 32 characters).'
    );
  }

  if (secret.length < 32) {
    throw new Error(
      'COOKIE_SECRET must be at least 32 characters long.'
    );
  }

  const salt = Buffer.from('agentapi-ui-cookie-salt', 'utf8');
  return scryptSync(secret, salt, keyLength);
}
```

### セキュア Cookie オプション

```typescript
export function getSecureCookieOptions(maxAge: number = 86400) {
  return {
    httpOnly: true,              // JavaScript からアクセス不可
    secure: process.env.NODE_ENV === 'production', // 本番環境では HTTPS のみ
    sameSite: 'lax' as const,    // CSRF 対策
    path: '/',                   // すべてのパスで有効
    maxAge,                      // 秒単位の有効期限（デフォルト: 24時間）
  };
}
```

#### Cookie 属性の説明

| 属性 | 設定値 | 説明 |
|-----|-------|-----|
| `httpOnly` | `true` | JavaScript から Cookie にアクセスできない（XSS 対策） |
| `secure` | `true` (本番) | HTTPS 接続でのみ Cookie を送信 |
| `sameSite` | `lax` | クロスサイトリクエストでの Cookie 送信を制限（CSRF 対策） |
| `path` | `/` | すべてのパスで Cookie が有効 |
| `maxAge` | `86400` | Cookie の有効期限（秒単位） |

### Cookie の使用例

#### ログイン時

```typescript
// src/app/api/auth/login/route.ts
export async function POST(request: NextRequest) {
  const { apiKey } = await request.json();

  // API キーの検証
  const isValid = await validateApiKey(apiKey);
  if (!isValid) {
    return NextResponse.json(
      { error: 'Invalid API key' },
      { status: 401 }
    );
  }

  // Cookie を暗号化して設定
  const encryptedKey = encryptCookie(apiKey);
  const response = NextResponse.json({ success: true });

  response.cookies.set(
    'auth_token',
    encryptedKey,
    getSecureCookieOptions(86400) // 24時間有効
  );

  return response;
}
```

#### API リクエスト時

```typescript
// src/app/api/proxy/[...path]/route.ts
export async function GET(request: NextRequest) {
  // Cookie から API キーを取得
  const authCookie = request.cookies.get('auth_token');

  if (!authCookie) {
    return NextResponse.json(
      { error: 'Unauthorized' },
      { status: 401 }
    );
  }

  try {
    // Cookie を復号化
    const apiKey = decryptCookie(authCookie.value);

    // agentapi-proxy へリクエスト
    const response = await fetch(`${proxyUrl}${path}`, {
      headers: {
        'Authorization': `Bearer ${apiKey}`,
      },
    });

    return response;
  } catch (error) {
    return NextResponse.json(
      { error: 'Invalid token' },
      { status: 401 }
    );
  }
}
```

## セキュリティヘッダー

### Next.js でのヘッダー設定

**ファイル**: `next.config.js`

```javascript
module.exports = {
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
          {
            key: 'Permissions-Policy',
            value: 'camera=(), microphone=(), geolocation=(), browsing-topics=()',
          },
        ],
      },
    ];
  },
}
```

### ヘッダーの詳細

#### 1. X-Frame-Options

```
X-Frame-Options: DENY
```

**目的**: クリックジャッキング攻撃の防止

**効果**:
- ページを `<iframe>` 内で表示することを禁止
- すべてのフレーム埋め込みを拒否

#### 2. X-Content-Type-Options

```
X-Content-Type-Options: nosniff
```

**目的**: MIME タイプスニッフィング攻撃の防止

**効果**:
- ブラウザが Content-Type を推測しない
- 宣言された MIME タイプのみを使用

#### 3. Referrer-Policy

```
Referrer-Policy: strict-origin-when-cross-origin
```

**目的**: リファラー情報の漏洩防止

**効果**:
- 同一オリジン: 完全な URL を送信
- クロスオリジン: オリジンのみを送信
- HTTPS → HTTP: リファラーを送信しない

#### 4. Content-Security-Policy (CSP)

```
Content-Security-Policy:
  default-src 'self';
  script-src 'self' 'unsafe-inline' 'unsafe-eval';
  style-src 'self' 'unsafe-inline';
  img-src 'self' data: https:;
  connect-src 'self' https:;
  font-src 'self' data:;
  object-src 'none';
  base-uri 'self';
```

**ディレクティブの説明**:

| ディレクティブ | 値 | 説明 |
|-------------|---|-----|
| `default-src` | `'self'` | デフォルトでは同一オリジンのみ |
| `script-src` | `'self' 'unsafe-inline' 'unsafe-eval'` | スクリプトの読み込み元（Next.js 要件） |
| `style-src` | `'self' 'unsafe-inline'` | スタイルシートの読み込み元 |
| `img-src` | `'self' data: https:` | 画像の読み込み元 |
| `connect-src` | `'self' https:` | XHR、WebSocket の接続先 |
| `font-src` | `'self' data:` | フォントの読み込み元 |
| `object-src` | `'none'` | `<object>` タグを禁止 |
| `base-uri` | `'self'` | `<base>` タグのベース URL |

**注意**: `'unsafe-inline'` と `'unsafe-eval'` は Next.js の動的インポートで必要ですが、セキュリティリスクがあります。本番環境では nonce または hash ベースの CSP を検討してください。

#### 5. Permissions-Policy

```
Permissions-Policy:
  camera=(),
  microphone=(),
  geolocation=(),
  browsing-topics=()
```

**目的**: ブラウザ API の使用制限

**効果**:
- カメラへのアクセスを禁止
- マイクへのアクセスを禁止
- 位置情報へのアクセスを禁止
- ブラウジングトピック API を禁止

## CSRF 対策

### SameSite Cookie 属性

```typescript
{
  sameSite: 'lax'
}
```

**効果**:
- トップレベルナビゲーション: Cookie を送信
- サブリクエスト（画像、iframe など）: Cookie を送信しない
- POST リクエスト（クロスサイト）: Cookie を送信しない

### State パラメータ（OAuth）

```typescript
// OAuth 認証開始時
const state = generateRandomState();
sessionStorage.setItem('oauth_state', state);

const params = new URLSearchParams({
  client_id: clientId,
  redirect_uri: redirectUri,
  scope: 'user:email,repo',
  state: state, // CSRF 対策
});

// コールバック時
const receivedState = searchParams.get('state');
const savedState = sessionStorage.getItem('oauth_state');

if (receivedState !== savedState) {
  throw new Error('Invalid state - possible CSRF attack');
}
```

## XSS 防止

### React の自動エスケープ

React はデフォルトで XSS を防止します。

```typescript
// 安全: 自動的にエスケープされる
<div>{userInput}</div>

// 危険: エスケープされない（使用禁止）
<div dangerouslySetInnerHTML={{ __html: userInput }} />
```

### コンテンツのサニタイゼーション

Markdown をレンダリングする際は、サニタイズされたライブラリを使用します。

```typescript
import ReactMarkdown from 'react-markdown';

// 安全: react-markdown は自動的にサニタイズ
<ReactMarkdown>{message.content}</ReactMarkdown>
```

### URL スキームの検証

```typescript
function isSafeUrl(url: string): boolean {
  try {
    const parsed = new URL(url);
    // HTTPS と HTTP のみ許可
    return ['https:', 'http:'].includes(parsed.protocol);
  } catch {
    return false;
  }
}

// 使用例
if (isSafeUrl(redirectUrl)) {
  router.push(redirectUrl);
} else {
  console.error('Unsafe URL detected:', redirectUrl);
}
```

## インジェクション対策

### SQL インジェクション

agentapi-ui はフロントエンドのため、直接 SQL を実行しません。すべてのデータベースアクセスは agentapi-proxy を経由します。

### コマンドインジェクション

ユーザー入力を直接コマンドに渡すことはありません。すべての処理は agentapi-proxy の API を通じて行われます。

### Path Traversal

```typescript
// ファイルパスの検証
function sanitizeFilePath(path: string): string {
  // パストラバーサルパターンを除去
  return path.replace(/\.\./g, '').replace(/^\//, '');
}
```

## 認証とアクセス制御

### 認証状態の確認

```typescript
// Middleware でのチェック
export function middleware(request: NextRequest) {
  const authCookie = request.cookies.get('auth_token');
  const { pathname } = request.nextUrl;

  // 未認証ユーザーを /login へリダイレクト
  if (!authCookie && !pathname.startsWith('/login')) {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  return NextResponse.next();
}
```

### API キーの検証

```typescript
async function validateApiKey(apiKey: string): Promise<boolean> {
  try {
    const response = await fetch(
      `${process.env.AGENTAPI_PROXY_URL}/v1/user/info`,
      {
        headers: { 'Authorization': `Bearer ${apiKey}` },
      }
    );
    return response.ok;
  } catch {
    return false;
  }
}
```

## セキュアコーディングプラクティス

### 1. 環境変数の管理

```typescript
// ✅ 良い例: サーバー側でのみ使用
const apiKey = process.env.API_KEY;

// ❌ 悪い例: クライアント側で露出
const apiKey = process.env.NEXT_PUBLIC_API_KEY;
```

**ルール**:
- 機密情報には `NEXT_PUBLIC_` プレフィックスを使用しない
- サーバー側でのみアクセスする環境変数を使用

### 2. ログの適切な処理

```typescript
// ✅ 良い例: 機密情報をマスク
console.log('API request', {
  url: '/api/sessions',
  userId: user.id,
  apiKey: '***masked***',
});

// ❌ 悪い例: 機密情報を出力
console.log('API request', {
  url: '/api/sessions',
  apiKey: apiKey,
});
```

### 3. エラーメッセージ

```typescript
// ✅ 良い例: 一般的なエラーメッセージ
catch (error) {
  showToast('ログインに失敗しました', 'error');
}

// ❌ 悪い例: 詳細なエラー情報を露出
catch (error) {
  showToast(`Error: ${error.message}`, 'error');
}
```

### 4. タイムアウトの設定

```typescript
// タイムアウトを設定してリソース枯渇を防ぐ
const response = await fetch(url, {
  signal: AbortSignal.timeout(10000), // 10秒
});
```

### 5. レート制限の遵守

```typescript
// レート制限ヘッダーの確認
const rateLimit = {
  limit: parseInt(response.headers.get('X-RateLimit-Limit') || '0'),
  remaining: parseInt(response.headers.get('X-RateLimit-Remaining') || '0'),
  reset: parseInt(response.headers.get('X-RateLimit-Reset') || '0'),
};

if (rateLimit.remaining < 10) {
  console.warn('Approaching rate limit:', rateLimit);
}
```

## セキュリティ監査

### 定期的なセキュリティチェック

#### 1. 依存関係の監査

```bash
# npm audit
npm audit

# または bun audit
bun audit

# 脆弱性の修正
npm audit fix
```

#### 2. セキュリティスキャン

```bash
# ESLint でセキュリティルールをチェック
npm run lint

# または専用ツールを使用
npx eslint-plugin-security
```

#### 3. ペネトレーションテスト

定期的にペネトレーションテストを実施し、脆弱性を発見します。

### セキュリティチェックリスト

- [ ] Cookie が適切に暗号化されている
- [ ] セキュリティヘッダーが設定されている
- [ ] CSRF 対策が実装されている
- [ ] XSS 防止策が実装されている
- [ ] 認証が適切に実装されている
- [ ] 機密情報がログに出力されていない
- [ ] HTTPS が強制されている（本番環境）
- [ ] 依存関係が最新かつ安全
- [ ] エラーメッセージが適切
- [ ] タイムアウトが設定されている

## インシデント対応

### セキュリティインシデントが発生した場合

1. **即座の対応**:
   - 影響を受けたユーザーのセッションを無効化
   - `COOKIE_SECRET` を変更してすべての Cookie を無効化
   - 脆弱性を修正

2. **調査**:
   - ログを確認して影響範囲を特定
   - どのデータが漏洩したか確認

3. **修正とデプロイ**:
   - セキュリティパッチを適用
   - 緊急デプロイを実施

4. **通知**:
   - 影響を受けたユーザーに通知
   - セキュリティアドバイザリを公開

## 次のステップ

- [設定リファレンス](./configuration.md) - セキュリティ関連の設定
- [API 統合](./api-integration.md) - セキュアな API 通信
- [運用ガイド](../operations/security.md) - セキュリティベストプラクティス
