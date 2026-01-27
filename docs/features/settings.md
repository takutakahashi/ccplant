# 設定管理

## 概要

ccplant の設定は、グローバル設定と個人設定の2つのレベルで管理されます。グローバル設定は管理者が管理し、個人設定は各ユーザーが自由にカスタマイズできます。

## 設定の階層

```
グローバル設定 (管理者のみ)
    ├── API 設定
    ├── OAuth 設定
    └── システムデフォルト
         ↓
個人設定 (ユーザー)
    ├── 表示設定
    ├── 通知設定
    └── プロフィール
```

**優先順位:** 個人設定 > グローバル設定

## グローバル設定

管理者が管理する、システム全体に適用される設定です。

### API 設定

#### ベース URL

```yaml
# values.yaml
global:
  hostname: cc.example.com        # フロントエンド
  apiHostname: cc-api.example.com # バックエンド
```

#### タイムアウト

```yaml
agentapi-proxy:
  config:
    api:
      timeout: 30s           # API タイムアウト
      max_request_size: 50mb # 最大リクエストサイズ
```

### OAuth 設定

#### GitHub OAuth

```yaml
global:
  github:
    oauth:
      clientId: "Iv1.xxxxxxxxxxxxxxxx"
      clientSecret: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

#### 認証モード

```yaml
agentapi-proxy:
  env:
    - name: AUTH_MODE
      value: "oauth_only"  # oauth_only, api_key, または both
```

### デフォルトリソース制限

```yaml
agentapi-proxy:
  kubernetesSession:
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 2000m
        memory: 4Gi
```

### グローバル MCP サーバー

すべてのセッションで利用可能な MCP サーバー:

```yaml
agentapi-proxy:
  config:
    global_mcp_servers:
      github:
        command: "npx"
        args: ["-y", "@modelcontextprotocol/server-github"]
```

## 個人設定

各ユーザーが自由にカスタマイズできる設定です。

### 表示設定

#### フォント設定

**フォントサイズ: 12-20px**

```json
{
  "display": {
    "font_size": 14,
    "min_font_size": 12,
    "max_font_size": 20
  }
}
```

**設定方法:**
1. 設定画面を開く
2. 「表示」セクションに移動
3. フォントサイズスライダーを調整 (12-20px)
4. リアルタイムでプレビュー表示
5. 自動保存

**フォントファミリー:**

```json
{
  "display": {
    "font_family": "Sans-serif"  // または "Monospace"
  }
}
```

**利用可能なフォント:**
- **Sans-serif**: モダンで読みやすい、UI に適している
- **Monospace**: コーディングに最適、等幅フォント

**カスタムフォント:**
```json
{
  "display": {
    "custom_font": "Fira Code, JetBrains Mono, monospace"
  }
}
```

#### テーマ

```json
{
  "display": {
    "theme": "light",  // light, dark, または auto
    "accent_color": "#3b82f6"
  }
}
```

**テーマオプション:**
- `light`: ライトモード
- `dark`: ダークモード
- `auto`: システム設定に従う

#### レイアウト

```json
{
  "display": {
    "sidebar_width": 250,
    "compact_mode": false,
    "show_timestamps": true
  }
}
```

### 通知設定

#### 通知の有効化

```json
{
  "notifications": {
    "enabled": true,
    "preferences": {
      "session_completion": true,
      "session_error": true,
      "schedule_execution": true,
      "webhook_trigger": false
    }
  }
}
```

#### クワイエットアワー

```json
{
  "notifications": {
    "quiet_hours": {
      "enabled": true,
      "start": "22:00",
      "end": "08:00",
      "timezone": "Asia/Tokyo"
    }
  }
}
```

### キーボードショートカット

```json
{
  "keyboard": {
    "send_message": "Cmd+Enter",  // Mac
    // "send_message": "Ctrl+Enter",  // Windows/Linux
    "new_session": "Cmd+N",
    "search": "Cmd+K"
  }
}
```

**カスタマイズ:**
1. 設定画面 → キーボードショートカット
2. 変更したいショートカットをクリック
3. 新しいキーコンビネーションを押す
4. 保存

### デフォルト MCP サーバー

個人用のデフォルト MCP サーバー設定:

```json
{
  "default_mcp_servers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

### プロフィール情報

```json
{
  "profile": {
    "display_name": "Taku Takahashi",
    "email": "taku@example.com",
    "timezone": "Asia/Tokyo",
    "language": "ja"
  }
}
```

## Single Profile Mode

Single Profile Mode では、複数のプロフィールを作成し、簡単に切り替えることができます。

### プロフィールの作成

```json
{
  "profiles": [
    {
      "name": "work",
      "display_name": "Work Profile",
      "settings": {
        "display": {
          "theme": "light",
          "font_size": 14
        },
        "default_mcp_servers": {
          "github": {...}
        }
      }
    },
    {
      "name": "personal",
      "display_name": "Personal Profile",
      "settings": {
        "display": {
          "theme": "dark",
          "font_size": 16
        }
      }
    }
  ],
  "active_profile": "work"
}
```

### プロフィールの切り替え

**Web UI:**
1. 画面右上のプロフィールアイコンをクリック
2. 「プロフィール切り替え」を選択
3. 切り替え先のプロフィールを選択

**API:**
```bash
curl -X PATCH https://cc-api.example.com/api/v1/users/me/profile \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -d '{"active_profile": "personal"}'
```

### プロフィールの管理

```bash
# プロフィール一覧
GET /api/v1/users/me/profiles

# プロフィール作成
POST /api/v1/users/me/profiles
{
  "name": "new-profile",
  "display_name": "New Profile"
}

# プロフィール削除
DELETE /api/v1/users/me/profiles/{profile_name}
```

## 設定のエクスポート/インポート

### エクスポート

```bash
# すべての設定をエクスポート
curl https://cc-api.example.com/api/v1/users/me/settings/export \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  > settings.json
```

### インポート

```bash
# 設定をインポート
curl -X POST https://cc-api.example.com/api/v1/users/me/settings/import \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @settings.json
```

### バックアップ

定期的に設定をバックアップすることを推奨します:

```bash
# 毎週自動バックアップ
0 0 * * 0 ccplant settings export > ~/backups/ccplant-settings-$(date +\%Y\%m\%d).json
```

## 設定の同期

複数のデバイス間で設定を同期できます。

### 有効化

```json
{
  "sync": {
    "enabled": true,
    "auto_sync": true,
    "sync_interval": 3600  // 1 時間ごと
  }
}
```

### 同期対象

```json
{
  "sync": {
    "items": {
      "display_settings": true,
      "keyboard_shortcuts": true,
      "notification_preferences": true,
      "mcp_servers": false  // 機密情報を含むため false 推奨
    }
  }
}
```

## 設定 API

### 設定の取得

```bash
# すべての設定を取得
curl https://cc-api.example.com/api/v1/users/me/settings \
  -H "Authorization: Bearer ${GITHUB_TOKEN}"

# 特定のセクションのみ取得
curl https://cc-api.example.com/api/v1/users/me/settings/display \
  -H "Authorization: Bearer ${GITHUB_TOKEN}"
```

### 設定の更新

```bash
# 設定を更新
curl -X PATCH https://cc-api.example.com/api/v1/users/me/settings \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -d '{
    "display": {
      "font_size": 16,
      "theme": "dark"
    }
  }'
```

### 設定のリセット

```bash
# すべての設定をデフォルトに戻す
curl -X POST https://cc-api.example.com/api/v1/users/me/settings/reset \
  -H "Authorization: Bearer ${GITHUB_TOKEN}"

# 特定のセクションのみリセット
curl -X POST https://cc-api.example.com/api/v1/users/me/settings/reset?section=display \
  -H "Authorization: Bearer ${GITHUB_TOKEN}"
```

## トラブルシューティング

### 設定が保存されない

**症状:** 設定を変更しても、リロード後に元に戻る

**対処:**
1. ブラウザの Cookie が有効か確認
2. ローカルストレージが有効か確認
3. API レスポンスを確認

### 設定が反映されない

**症状:** 設定を変更しても、見た目が変わらない

**対処:**
1. ページをリロード (Cmd/Ctrl+Shift+R)
2. ブラウザのキャッシュをクリア
3. 設定 API を確認

### 同期が動作しない

**症状:** 複数のデバイスで設定が同期されない

**対処:**
1. 同期設定が有効か確認
2. ネットワーク接続を確認
3. 最終同期日時を確認

## セキュリティ

### 機密情報の管理

MCP サーバーの認証情報など、機密情報を含む設定は:
- Secret で管理
- 同期対象から除外
- エクスポート時にマスク

### 暗号化

設定は以下のように暗号化されます:
- 保存時: AES-256-GCM で暗号化
- 転送時: HTTPS/TLS
- エクスポート: オプションで暗号化

## ベストプラクティス

### 1. 定期的にバックアップ

設定を定期的にエクスポートして、バックアップを保存します。

### 2. プロフィールを活用

仕事用と個人用でプロフィールを分けて管理します。

### 3. 機密情報を分離

API キーなどの機密情報は、設定ではなく Secret で管理します。

### 4. デフォルト設定を確認

新機能の追加時は、デフォルト設定を確認してカスタマイズします。

## まとめ

適切な設定により、ccplant を自分の使いやすいようにカスタマイズできます。個人設定とグローバル設定を理解し、効率的に活用してください。

### 次のステップ

- [チャットインターフェース](./chat.md) - フォント設定の活用
- [通知設定](./notifications.md) - プッシュ通知のカスタマイズ
- [セッション管理](./sessions.md) - デフォルトセッション設定

### 関連リソース

- [フロントエンド設定](../frontend/configuration.md)
- [バックエンド設定](../backend/configuration.md)
- [デプロイメント設定](../deployment/configuration.md)
