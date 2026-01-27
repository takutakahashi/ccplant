# プッシュ通知

## 概要

ccplant はブラウザプッシュ通知をサポートし、セッションの完了、エラー発生、スケジュール実行など、重要なイベントをリアルタイムで通知します。作業に集中しながら、必要な情報を逃さず受け取ることができます。

## ブラウザ通知の有効化

### 初回セットアップ

1. ccplant にログイン
2. 画面右上のベルアイコンをクリック
3. 「通知を有効にする」ボタンをクリック
4. ブラウザの通知許可ダイアログで「許可」をクリック
5. 通知が有効化されます

**スクリーンショット説明:**
通知許可ダイアログには、「cc.example.com が通知を送信することを許可しますか?」というメッセージと「ブロック」「許可」ボタンが表示されます。

### 通知設定の確認

```bash
# API で通知設定を確認
curl https://cc-api.example.com/api/v1/users/me/notifications \
  -H "Authorization: Bearer ${GITHUB_TOKEN}"
```

**レスポンス:**
```json
{
  "enabled": true,
  "endpoint": "https://fcm.googleapis.com/...",
  "subscribed_at": "2024-01-27T12:00:00Z",
  "preferences": {
    "session_completion": true,
    "session_error": true,
    "schedule_execution": true
  }
}
```

## 通知タイプ

### 1. セッション完了通知

**トリガー:** セッションが正常に完了

**内容:**
```
タイトル: セッションが完了しました
本文: "feature-dev-session" が正常に完了しました
アクション: [開く] [閉じる]
```

**設定:**
```json
{
  "preferences": {
    "session_completion": true
  }
}
```

### 2. エラー通知

**トリガー:** セッション実行中にエラーが発生

**内容:**
```
タイトル: エラーが発生しました
本文: セッション "deploy-prod" でエラーが発生しました
詳細: Pod crashed (OOMKilled)
アクション: [詳細を見る] [閉じる]
```

**設定:**
```json
{
  "preferences": {
    "session_error": true
  }
}
```

### 3. スケジュール実行通知

**トリガー:** スケジュールが実行された

**内容:**
```
タイトル: スケジュールが実行されました
本文: "nightly-backup" が実行されました
ステータス: 成功
アクション: [結果を見る] [閉じる]
```

**設定:**
```json
{
  "preferences": {
    "schedule_execution": true
  }
}
```

### 4. Webhook トリガー通知

**トリガー:** Webhook が実行された

**内容:**
```
タイトル: Webhook が実行されました
本文: "pr-auto-review" がトリガーされました
PR: #123 "Add new feature"
アクション: [セッションを開く] [閉じる]
```

**設定:**
```json
{
  "preferences": {
    "webhook_trigger": true
  }
}
```

## VAPID 設定

VAPID (Voluntary Application Server Identification) は、プッシュ通知の送信元を識別するための仕組みです。

### VAPID キーの生成

```bash
# Node.js で生成
npx web-push generate-vapid-keys

# 出力例
Public Key:  Bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
Private Key: yxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Helm での設定

```yaml
# values.yaml
agentapi-proxy:
  notifications:
    vapid:
      publicKey: "BxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxGH"
      privateKeySecret:
        name: vapid-keys
        key: private-key
```

### Secret の作成

```bash
kubectl create secret generic vapid-keys \
  --from-literal=private-key=yxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## 通知設定

### 通知の有効化/無効化

#### すべての通知

```bash
# 無効化
curl -X PATCH https://cc-api.example.com/api/v1/users/me/notifications \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -d '{"enabled": false}'

# 有効化
curl -X PATCH https://cc-api.example.com/api/v1/users/me/notifications \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -d '{"enabled": true}'
```

#### 通知タイプ別

```bash
# セッション完了通知のみ無効化
curl -X PATCH https://cc-api.example.com/api/v1/users/me/notifications/preferences \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -d '{
    "session_completion": false,
    "session_error": true,
    "schedule_execution": true
  }'
```

### クワイエットアワー

特定の時間帯は通知を受信しないように設定できます。

```json
{
  "quiet_hours": {
    "enabled": true,
    "start": "22:00",
    "end": "08:00",
    "timezone": "Asia/Tokyo"
  }
}
```

**動作:**
- 22:00 から 08:00 の間は通知を送信しない
- 通知は保留され、08:00 以降にまとめて送信される

### 通知の優先度

```json
{
  "priorities": {
    "session_completion": "low",
    "session_error": "high",
    "schedule_execution": "normal"
  }
}
```

**優先度レベル:**
- `high`: 即座に通知、音あり
- `normal`: 通常通知
- `low`: サイレント通知

## ブラウザ別の設定

### Chrome / Edge

1. 設定 → プライバシーとセキュリティ → サイトの設定
2. 通知
3. cc.example.com を「許可」に設定

### Firefox

1. 設定 → プライバシーとセキュリティ
2. 権限 → 通知 → 設定
3. cc.example.com を「許可」に設定

### Safari

1. システム環境設定 → 通知
2. Safari
3. cc.example.com からの通知を「許可」

## トラブルシューティング

### 通知が届かない

**確認項目:**

1. **ブラウザの通知許可**
   - ブラウザ設定で通知が許可されているか確認

2. **ccplant の通知設定**
   - Web UI で通知が有効になっているか確認

3. **VAPID 設定**
   - VAPID キーが正しく設定されているか確認
   ```bash
   kubectl get secret vapid-keys
   ```

4. **サービスワーカー**
   - ブラウザの開発者ツールで確認
   - Application → Service Workers

### 通知が重複する

**原因:** 複数のタブで ccplant を開いている

**対処:** 
- 1つのタブのみを使用
- または、重複通知を防ぐ設定を有効化:
  ```json
  {
    "deduplicate": true
  }
  ```

### 通知がクリックできない

**原因:** サービスワーカーの問題

**対処:**
1. ブラウザのキャッシュをクリア
2. サービスワーカーを再登録
3. ページをリロード

## セキュリティ

### HTTPS の使用

プッシュ通知は HTTPS でのみ動作します。

### VAPID キーの管理

- Private Key は Secret で管理
- Public Key はフロントエンドに埋め込み可能
- 定期的にキーをローテーション (推奨: 1年ごと)

### エンドポイントの検証

通知エンドポイントは、登録時に検証されます:

```javascript
// サービスワーカーで検証
self.addEventListener('push', (event) => {
  if (!isValidOrigin(event.origin)) {
    return; // 不正なオリジンからの通知を無視
  }
  // 通知を表示
});
```

## ベストプラクティス

### 1. 適切な通知のみ有効化

すべての通知を有効にすると、通知が多すぎて重要な情報を見逃す可能性があります。

### 2. クワイエットアワーを設定

夜間や休日は通知を無効にして、ワークライフバランスを保ちます。

### 3. 優先度を適切に設定

重要な通知（エラーなど）は高優先度に、それ以外は通常または低優先度に設定します。

## まとめ

プッシュ通知により、重要なイベントを逃さず、効率的に作業できます。適切な設定により、必要な情報のみを受け取ることができます。

### 次のステップ

- [設定管理](./settings.md) - 通知設定のカスタマイズ
- [セッション管理](./sessions.md) - セッションイベントの理解
- [スケジュール実行](./schedules.md) - スケジュール通知の活用

### 関連リソース

- [Web Push API](https://developer.mozilla.org/docs/Web/API/Push_API)
- [VAPID 仕様](https://tools.ietf.org/html/rfc8292)
