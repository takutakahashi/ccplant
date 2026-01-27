# Webhook 統合

## 概要

Webhook 機能を使用すると、GitHub などの外部サービスからのイベントをトリガーに、自動的にセッションを起動して AI エージェントにタスクを実行させることができます。プルリクエストのレビュー、Issue への応答、デプロイの自動化など、様々なワークフローを自動化できます。

## Webhook とは

Webhook は、外部サービスからのイベント通知を受け取る HTTP エンドポイントです。イベントが発生すると、サービスが ccplant の Webhook エンドポイントに HTTP POST リクエストを送信し、ccplant がそれに応じてアクションを実行します。

**基本的な流れ:**
```
GitHub でイベント発生
    ↓
Webhook POST リクエスト送信
    ↓
ccplant が受信・検証
    ↓
トリガー条件をチェック
    ↓
セッション起動
    ↓
AI エージェントがタスク実行
```

## GitHub Webhook 統合

GitHub との統合により、リポジトリのイベントに自動応答できます。

### サポートされるイベント

| イベント | トリガータイミング | 用途例 |
|---------|-----------------|--------|
| `push` | コミットがプッシュされた | ビルド実行、テスト実行 |
| `pull_request` | PR が作成・更新された | コードレビュー、CI チェック |
| `pull_request_review` | レビューが投稿された | レビューへの対応 |
| `issues` | Issue が作成・更新された | Issue への自動応答 |
| `issue_comment` | Issue にコメントされた | 質問への回答 |
| `release` | リリースが作成された | リリースノート生成 |
| `workflow_run` | GitHub Actions 完了 | CI 結果の分析 |
| `create` | ブランチ・タグ作成 | 環境セットアップ |
| `delete` | ブランチ・タグ削除 | クリーンアップ |

### Webhook の作成

#### Web UI から作成

1. ダッシュボードで「Webhook」タブを開く
2. 「新規 Webhook」ボタンをクリック
3. Webhook 設定を入力:

**基本設定:**
```
名前: PR 自動レビュー
説明: プルリクエストを自動的にレビューします
有効: ✓
```

**トリガー設定:**
```
イベント: pull_request
アクション: opened, synchronize
リポジトリ: owner/repo (または空欄で全リポジトリ)
```

**セッション設定:**
```
エージェント: code-reviewer
初期メッセージテンプレート:
---
このプルリクエストをレビューしてください。

PR: {{ .pull_request.html_url }}
タイトル: {{ .pull_request.title }}
変更ファイル数: {{ .pull_request.changed_files }}
---
```

4. 「作成」をクリック
5. Webhook URL とシークレットが表示される

**スクリーンショットの説明:**
Webhook 作成フォームには、名前入力欄、イベント選択ドロップダウン、Go Template エディタ、セッション再利用チェックボックスが縦に並んでいます。

#### API から作成

```bash
curl -X POST https://cc-api.example.com/api/v1/webhooks \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "pr-auto-review",
    "description": "Automatic PR review",
    "enabled": true,
    "trigger": {
      "events": ["pull_request"],
      "actions": ["opened", "synchronize"],
      "repository": "owner/repo"
    },
    "session_config": {
      "agent_id": "code-reviewer",
      "message_template": "このプルリクエストをレビューしてください。\n\nPR: {{ .pull_request.html_url }}"
    }
  }'
```

**レスポンス:**
```json
{
  "webhook_id": "webhook-123",
  "name": "pr-auto-review",
  "webhook_url": "https://cc-api.example.com/webhooks/webhook-123",
  "secret": "whsec_xxxxxxxxxxxxxxxxxxxxxxxx",
  "created_at": "2024-01-27T12:00:00Z"
}
```

### GitHub リポジトリへの設定

作成した Webhook を GitHub リポジトリに設定します。

1. GitHub リポジトリの Settings → Webhooks に移動
2. "Add webhook" をクリック
3. 以下を入力:
   - **Payload URL**: `https://cc-api.example.com/webhooks/webhook-123`
   - **Content type**: `application/json`
   - **Secret**: ccplant から取得したシークレット
   - **Which events**: 個別のイベントを選択
4. "Add webhook" をクリック

**スクリーンショットの説明:**
GitHub の Webhook 設定画面には、Payload URL の入力欄、Content type のドロップダウン、Secret の入力欄、イベント選択のラジオボタンが表示されます。

## Go Template マッチング

Webhook のトリガー条件は、Go Template を使用して柔軟に設定できます。

### 基本構文

Go Template では、`{{ }}` で囲まれた部分が変数や式として評価されます。

```go
{{ .pull_request.title }}           // PR のタイトル
{{ .issue.number }}                  // Issue 番号
{{ .sender.login }}                  // イベント送信者
```

### 条件分岐

特定の条件に一致する場合のみトリガーできます。

#### 例 1: 特定のブランチへの PR のみ

```go
{{ if eq .pull_request.base.ref "main" }}
true
{{ else }}
false
{{ end }}
```

#### 例 2: ラベルが付いている PR のみ

```go
{{ range .pull_request.labels }}
  {{ if eq .name "needs-review" }}
    true
  {{ end }}
{{ end }}
```

#### 例 3: ファイルパスでフィルタ

```go
{{ range .pull_request.files }}
  {{ if hasPrefix .filename "src/" }}
    true
  {{ end }}
{{ end }}
```

### 利用可能な関数

| 関数 | 説明 | 例 |
|-----|------|-----|
| `eq` | 等価比較 | `{{ if eq .action "opened" }}` |
| `ne` | 不等価比較 | `{{ if ne .state "closed" }}` |
| `and` | 論理 AND | `{{ if and (eq .action "opened") (eq .base.ref "main") }}` |
| `or` | 論理 OR | `{{ if or (eq .action "opened") (eq .action "reopened") }}` |
| `not` | 論理 NOT | `{{ if not (eq .draft true) }}` |
| `hasPrefix` | 前方一致 | `{{ if hasPrefix .title "[WIP]" }}` |
| `hasSuffix` | 後方一致 | `{{ if hasSuffix .filename ".py" }}` |
| `contains` | 部分一致 | `{{ if contains .body "urgent" }}` |
| `len` | 長さ取得 | `{{ if gt (len .files) 10 }}` |

### GitHub ペイロード構造

GitHub から送信される主なフィールド:

#### Pull Request イベント

```json
{
  "action": "opened",
  "number": 123,
  "pull_request": {
    "id": 1234567890,
    "number": 123,
    "state": "open",
    "title": "Add new feature",
    "body": "This PR adds...",
    "user": {
      "login": "username"
    },
    "base": {
      "ref": "main",
      "repo": {
        "name": "repo",
        "full_name": "owner/repo"
      }
    },
    "head": {
      "ref": "feature-branch"
    },
    "draft": false,
    "labels": [],
    "changed_files": 5,
    "additions": 150,
    "deletions": 30
  }
}
```

#### Issues イベント

```json
{
  "action": "opened",
  "issue": {
    "number": 456,
    "title": "Bug report",
    "body": "I found a bug...",
    "user": {
      "login": "username"
    },
    "labels": [],
    "state": "open"
  }
}
```

### 実用的な例

#### 例 1: メインブランチへの PR で、ドラフトでないもの

```go
{{ if and (eq .pull_request.base.ref "main") (not .pull_request.draft) }}
true
{{ end }}
```

#### 例 2: "bug" ラベルが付いた Issue

```go
{{ range .issue.labels }}
  {{ if eq .name "bug" }}
    true
  {{ end }}
{{ end }}
```

#### 例 3: 10 ファイル以上変更された PR

```go
{{ if gt .pull_request.changed_files 10 }}
true
{{ end }}
```

## トリガー条件の設定

Webhook のトリガー条件は、以下の 3 つの要素で構成されます。

### 1. Path (パス)

Webhook エンドポイントのパス部分でフィルタします。

```yaml
path: "/webhooks/pr-review"
```

**用途:**
- 異なる Webhook を区別
- 同じエンドポイントで複数の用途を処理

### 2. Method (HTTP メソッド)

HTTP メソッドでフィルタします。

```yaml
method: "POST"
```

**用途:**
- POST のみ受け付ける (通常は POST)
- GET でヘルスチェック

### 3. Go Template (条件式)

Go Template でペイロードの内容をチェックします。

```yaml
go_template: |
  {{ if and (eq .pull_request.base.ref "main") (not .pull_request.draft) }}
  true
  {{ end }}
```

**用途:**
- 詳細な条件分岐
- 複雑なフィルタリングロジック

## セッション再利用

Webhook でセッション再利用を有効にすると、毎回新しいセッションを作成する代わりに、既存のセッションにメッセージを送信できます。

### メリット

1. **起動時間の短縮**: Pod 起動を待つ必要がない
2. **コンテキスト保持**: 前の作業内容を参照できる
3. **リソース効率**: 複数の Pod を起動しない

### 設定方法

#### 特定のセッションを再利用

```json
{
  "webhook_id": "webhook-123",
  "reuse_session": true,
  "session_id": "session-user123-abc123"
}
```

指定したセッション ID のセッションが存在し、実行中の場合に再利用します。

#### 最後のセッションを再利用

```json
{
  "webhook_id": "webhook-123",
  "reuse_session": true
}
```

`session_id` を指定しない場合、ユーザーの最後に作成されたセッションを再利用します。

### 動作

```
Webhook トリガー
    ↓
セッション ID を確認
    ↓
┌─────────────────┬─────────────────┐
│ セッションが存在  │ セッションが存在  │
│ かつ実行中       │ しないまたは停止  │
├─────────────────┼─────────────────┤
│ 既存セッション    │ 新規セッション    │
│ にメッセージ送信  │ を作成           │
└─────────────────┴─────────────────┘
```

### 使用例

**継続的な PR レビュー:**
```yaml
# 同じセッションで複数の PR をレビュー
webhook:
  name: "continuous-pr-review"
  events: ["pull_request"]
  reuse_session: true
```

**Issue トラッカー:**
```yaml
# 同じセッションで Issue を追跡
webhook:
  name: "issue-tracker"
  events: ["issues", "issue_comment"]
  reuse_session: true
  session_id: "issue-tracking-session"
```

## Webhook 管理

### Webhook 一覧の表示

Web UI のダッシュボードで、すべての Webhook を確認できます。

**表示される情報:**
- Webhook 名
- 有効/無効ステータス
- トリガーイベント
- 作成日時
- 最終実行日時
- 実行回数

**スクリーンショットの説明:**
Webhook 一覧は、カード形式で表示されます。各カードには、Webhook 名、緑色または灰色のステータスバッジ、イベント一覧、「編集」「削除」ボタンが含まれます。

### Webhook の編集

1. Webhook 一覧で編集したい Webhook を見つける
2. 「編集」ボタンをクリック
3. 設定を変更
4. 「保存」をクリック

**編集可能な項目:**
- 名前
- 説明
- 有効/無効
- トリガーイベント
- トリガー条件 (Go Template)
- メッセージテンプレート
- セッション再利用設定

### Webhook の削除

1. Webhook 一覧で削除したい Webhook を見つける
2. 「削除」ボタンをクリック
3. 確認ダイアログで「削除」をクリック

**注意:**
- 削除すると、Webhook URL が無効になります
- GitHub 側の Webhook 設定も削除する必要があります

### Webhook シークレットの再生成

セキュリティ上の理由で、Webhook シークレットを再生成できます。

1. Webhook 詳細画面を開く
2. 「シークレットを再生成」ボタンをクリック
3. 新しいシークレットが表示される
4. GitHub 側の Webhook 設定を更新

**重要:**
シークレットを再生成すると、古いシークレットは無効になります。GitHub の設定を更新するまで、Webhook は動作しません。

## エラーハンドリング

Webhook 実行中にエラーが発生した場合の処理方法を説明します。

### エラーの種類

#### 1. 検証エラー

**原因:**
- シークレットが一致しない
- ペイロードが無効

**対処:**
- GitHub の Webhook 設定でシークレットを確認
- ペイロード形式を確認

**ログ:**
```json
{
  "error": "webhook validation failed",
  "reason": "invalid signature",
  "webhook_id": "webhook-123"
}
```

#### 2. トリガー条件不一致

**原因:**
- Go Template の条件が false
- イベントタイプが一致しない

**対処:**
- トリガー条件を確認
- Go Template の構文エラーをチェック

**ログ:**
```json
{
  "info": "webhook trigger condition not met",
  "webhook_id": "webhook-123",
  "event": "pull_request",
  "action": "closed"
}
```

#### 3. セッション作成エラー

**原因:**
- リソース不足
- 権限不足
- 設定エラー

**対処:**
- クラスターのリソースを確認
- ユーザーの権限を確認
- セッション設定を確認

**ログ:**
```json
{
  "error": "failed to create session",
  "reason": "insufficient resources",
  "webhook_id": "webhook-123"
}
```

### リトライ機能

Webhook が一時的なエラーで失敗した場合、自動的にリトライされます。

**リトライ設定:**
```yaml
retry:
  max_attempts: 3      # 最大 3 回リトライ
  initial_delay: 5s    # 初回リトライまで 5 秒
  max_delay: 60s       # 最大 60 秒まで増加
  multiplier: 2        # 遅延を 2 倍ずつ増加
```

**リトライスケジュール:**
- 1 回目: 5 秒後
- 2 回目: 10 秒後
- 3 回目: 20 秒後

### エラー通知

Webhook エラーは以下の方法で通知されます:

1. **Web UI**: Webhook 一覧にエラーバッジが表示
2. **メール**: 設定されている場合、メール通知
3. **プッシュ通知**: ブラウザ通知が有効な場合
4. **ログ**: システムログに記録

## 実用例

### 例 1: GitHub プルリクエストの自動レビュー

**目的:** PR が作成されたら自動的にコードレビューを実行

**設定:**
```yaml
name: "pr-auto-review"
events: ["pull_request"]
actions: ["opened", "synchronize"]
go_template: |
  {{ if and (eq .pull_request.base.ref "main") (not .pull_request.draft) }}
  true
  {{ end }}
message_template: |
  このプルリクエストをレビューしてください。

  PR: {{ .pull_request.html_url }}
  タイトル: {{ .pull_request.title }}
  ブランチ: {{ .pull_request.head.ref }} → {{ .pull_request.base.ref }}
  変更ファイル数: {{ .pull_request.changed_files }}
  追加行数: {{ .pull_request.additions }}
  削除行数: {{ .pull_request.deletions }}

  以下の点を確認してください:
  1. コードの品質
  2. テストの充実度
  3. ドキュメントの更新
```

### 例 2: Issue への自動応答

**目的:** "question" ラベルが付いた Issue に自動応答

**設定:**
```yaml
name: "issue-auto-response"
events: ["issues"]
actions: ["labeled"]
go_template: |
  {{ range .issue.labels }}
    {{ if eq .name "question" }}
    true
    {{ end }}
  {{ end }}
message_template: |
  以下の Issue に回答してください。

  Issue: {{ .issue.html_url }}
  タイトル: {{ .issue.title }}
  内容:
  {{ .issue.body }}

  FAQ や過去の Issue を参照して、適切な回答を提供してください。
```

### 例 3: リリース後の自動テスト

**目的:** リリースが作成されたら自動テストを実行

**設定:**
```yaml
name: "release-auto-test"
events: ["release"]
actions: ["published"]
message_template: |
  リリース {{ .release.tag_name }} の自動テストを実行してください。

  リリースノート:
  {{ .release.body }}

  以下のテストを実行:
  1. 統合テスト
  2. パフォーマンステスト
  3. セキュリティスキャン

  結果を Issue として報告してください。
```

### 例 4: 大規模 PR の警告

**目的:** 変更が大きすぎる PR に警告コメントを投稿

**設定:**
```yaml
name: "large-pr-warning"
events: ["pull_request"]
actions: ["opened"]
go_template: |
  {{ if gt .pull_request.changed_files 20 }}
  true
  {{ end }}
message_template: |
  この PR は {{ .pull_request.changed_files }} ファイルを変更しています。

  大規模な PR は以下の理由で推奨されません:
  - レビューが困難
  - バグの混入リスクが高い
  - マージコンフリクトが発生しやすい

  可能であれば、以下のように分割することを検討してください:
  1. リファクタリング
  2. 新機能の実装
  3. テストの追加

  それでも分割が難しい場合は、PR の説明を充実させてください。
```

## セキュリティ

### Webhook シークレットの検証

すべての Webhook リクエストは、シークレットを使用して検証されます。

**検証プロセス:**
```
1. リクエストヘッダーから署名を取得
   X-Hub-Signature-256: sha256=xxxxx

2. リクエストボディとシークレットから署名を計算
   HMAC-SHA256(secret, body)

3. 署名を比較
   計算した署名 == 受信した署名

4. 一致しない場合、リクエストを拒否
```

**Go コード例:**
```go
func verifySignature(secret, body, signature string) bool {
    mac := hmac.New(sha256.New, []byte(secret))
    mac.Write([]byte(body))
    expected := "sha256=" + hex.EncodeToString(mac.Sum(nil))
    return hmac.Equal([]byte(expected), []byte(signature))
}
```

### HTTPS の使用

本番環境では必ず HTTPS を使用してください。

**理由:**
- ペイロードの暗号化
- 中間者攻撃の防止
- シークレットの保護

### IP ホワイトリスト (オプション)

GitHub からのリクエストのみを許可する場合、IP ホワイトリストを設定できます。

**GitHub の IP アドレス:**
```
https://api.github.com/meta
```

**Ingress での設定:**
```yaml
nginx.ingress.kubernetes.io/whitelist-source-range: |
  192.30.252.0/22,
  185.199.108.0/22,
  140.82.112.0/20
```

## トラブルシューティング

### Webhook が実行されない

**確認項目:**

1. **Webhook が有効か**
   - Web UI で Webhook のステータスを確認

2. **GitHub の Webhook 設定**
   - GitHub リポジトリの Settings → Webhooks で確認
   - "Recent Deliveries" でリクエストが送信されているか

3. **トリガー条件**
   - Go Template の条件が true を返すか
   - イベントタイプとアクションが一致しているか

4. **ログの確認**
   ```bash
   kubectl logs -f deployment/ccplant-agentapi-proxy | grep webhook
   ```

### GitHub で "Bad Request" エラー

**原因:**
- Webhook URL が間違っている
- エンドポイントが到達不可能

**対処:**
- URL を確認
- DNS 設定を確認
- ファイアウォール設定を確認

### 署名検証エラー

**原因:**
- シークレットが一致しない

**対処:**
1. ccplant の Webhook 詳細でシークレットを確認
2. GitHub の Webhook 設定でシークレットを更新
3. "Redeliver" で再送信してテスト

## ベストプラクティス

### 1. わかりやすい名前を付ける

Webhook の目的が明確にわかる名前を付けます。

```
✓ "pr-code-review"
✓ "issue-auto-label"
✓ "release-changelog-gen"

✗ "webhook-1"
✗ "test"
```

### 2. トリガー条件を適切に設定

不要なセッション起動を避けるため、トリガー条件を適切に設定します。

```go
// ドラフト PR を除外
{{ if not .pull_request.draft }}
true
{{ end }}

// 特定のブランチのみ
{{ if eq .pull_request.base.ref "main" }}
true
{{ end }}
```

### 3. メッセージテンプレートを充実させる

AI が適切に動作できるよう、十分な情報を提供します。

```
✓ 詳細な情報を含む
✓ コンテキストを提供
✓ 期待される動作を明示

✗ 最小限の情報のみ
```

### 4. セッション再利用を活用

関連するタスクは、同じセッションで実行することでコンテキストを保持します。

### 5. エラー通知を設定

Webhook が失敗した場合に気づけるよう、通知を設定します。

## まとめ

Webhook 統合により、外部イベントに自動的に応答する強力なワークフローを構築できます。適切な設定とセキュリティ対策により、開発プロセスを大幅に自動化できます。

### 次のステップ

- [スケジュール実行](./schedules.md) - 定期的なタスクの自動化
- [セッション管理](./sessions.md) - セッションの再利用方法
- [エージェント管理](./agents.md) - 適切なエージェントの選択

### 関連リソース

- [GitHub Webhook ドキュメント](https://docs.github.com/webhooks)
- [Go Template ドキュメント](https://pkg.go.dev/text/template)
- [バックエンド Webhook 実装](../backend/webhooks-schedules.md)
