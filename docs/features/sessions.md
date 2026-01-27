# セッション管理

## 概要

セッション管理は ccplant の中核機能です。セッションは AI エージェントとの対話環境を提供し、Kubernetes Pod として実行されます。各セッションは独立したコンテナ環境で動作し、プロジェクトのクローン、コード編集、テスト実行などを安全に行うことができます。

## セッションとは

セッションは以下の要素から構成されます:

- **専用の Kubernetes Pod**: Claude Code が動作する独立したコンテナ環境
- **永続ストレージ (オプション)**: セッション間でデータを保持する PVC
- **設定**: CPU、メモリ、タイムアウトなどのリソース制限
- **MCP サーバー**: 外部ツールとの統合 (GitHub、Slack など)
- **接続情報**: WebSocket URL、認証トークンなど

## 新規セッションの作成

### Web UI から作成

1. ダッシュボードにログイン
2. 「新規セッション」ボタンをクリック
3. セッション設定を入力:
   - **セッション名** (オプション): わかりやすい名前を設定
   - **リポジトリ** (オプション): GitHub リポジトリ URL
   - **ブランチ** (オプション): 作業するブランチ
   - **リソース設定**: CPU とメモリの制限
   - **永続ストレージ**: PVC を有効化するか選択
   - **MCP サーバー**: 必要な MCP サーバーを設定
4. 「作成」をクリック

**スクリーンショットの説明:**
- セッション作成フォームには、名前入力欄、リソーススライダー (CPU: 1-4 コア、メモリ: 2-8GB)、永続ストレージのチェックボックスが表示されます。

### API から作成

```bash
curl -X POST https://cc-api.example.com/api/v1/sessions \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "feature-dev-session",
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
  }'
```

**レスポンス例:**
```json
{
  "session_id": "session-user123-abc123",
  "name": "feature-dev-session",
  "user": "user123",
  "status": "pending",
  "created_at": "2024-01-27T12:00:00Z",
  "connection_url": "wss://cc-api.example.com/ws/sessions/session-user123-abc123",
  "pod_name": "session-user123-abc123",
  "namespace": "default"
}
```

## セッションのライフサイクル

セッションは以下のステータスを持ちます:

### 1. Pending (準備中)
Pod の作成リクエストが送信され、Kubernetes がスケジューリング中の状態です。

**表示される情報:**
- セッション ID
- 作成日時
- ステータス: 黄色のバッジで「準備中」

**通常の所要時間:** 10-30 秒

### 2. Running (実行中)
Pod が起動し、AI エージェントが利用可能な状態です。

**表示される情報:**
- セッション ID
- 接続 URL
- リソース使用状況 (CPU、メモリ)
- 稼働時間
- ステータス: 緑色のバッジで「実行中」

**アクション:**
- チャット画面を開く
- セッションを停止
- セッション設定を表示

### 3. Completed (完了)
セッションが正常に終了した状態です。

**表示される情報:**
- セッション ID
- 実行時間
- 終了日時
- ステータス: 青色のバッジで「完了」

**アクション:**
- セッション履歴を表示
- セッションを削除

### 4. Failed (失敗)
Pod の起動または実行中にエラーが発生した状態です。

**表示される情報:**
- セッション ID
- エラーメッセージ
- エラー発生日時
- ステータス: 赤色のバッジで「失敗」

**アクション:**
- エラー詳細を確認
- セッションを再作成
- セッションを削除

### 5. Terminated (終了)
ユーザーまたはシステムによって停止された状態です。

**表示される情報:**
- セッション ID
- 終了理由
- 終了日時
- ステータス: グレーのバッジで「終了」

## セッション設定オプション

### リソース制限

#### CPU 制限
```yaml
cpu_limit: "2"  # 2 コア
```

**推奨値:**
- 軽量タスク: `"1"` (1 コア)
- 通常タスク: `"2"` (2 コア)
- 重量タスク: `"4"` (4 コア)

#### メモリ制限
```yaml
memory_limit: "4Gi"  # 4 GiB
```

**推奨値:**
- 軽量タスク: `"2Gi"` (2 GiB)
- 通常タスク: `"4Gi"` (4 GiB)
- 重量タスク: `"8Gi"` (8 GiB)

### 永続ストレージ

```yaml
pvc_enabled: true
pvc_storage_size: "10Gi"
```

**用途:**
- セッション間でファイルを保持
- 大きなリポジトリのクローン
- ビルドキャッシュの保存

**注意事項:**
- PVC を有効にすると、セッション作成に時間がかかる場合があります
- PVC はセッション削除時に一緒に削除されます (設定により保持可能)

### タイムアウト設定

```yaml
timeout_minutes: 60  # 60 分でタイムアウト
```

**推奨値:**
- 対話セッション: `60` (1 時間)
- 長時間タスク: `180` (3 時間)
- 無制限: `0` (タイムアウトなし)

**注意:** タイムアウトは非アクティブ時間ではなく、セッションの総実行時間です。

### MCP サーバー設定

```yaml
mcp_servers:
  github:
    command: "npx"
    args: ["-y", "@modelcontextprotocol/server-github"]
    env:
      GITHUB_PERSONAL_ACCESS_TOKEN: "ghp_xxxxx"
  filesystem:
    command: "npx"
    args: ["-y", "@modelcontextprotocol/server-filesystem"]
    env:
      ALLOWED_PATHS: "/workspace"
```

詳細は [MCP サーバードキュメント](./mcp-servers.md)を参照してください。

## セッションの表示とアクセス

### セッション一覧の表示

Web UI のダッシュボードには、すべてのセッションが一覧表示されます。

**一覧に表示される情報:**
- セッション名
- ステータスバッジ
- 作成日時 / 更新日時
- リソース使用状況
- クイックアクション (開く、削除)

### セッションのソート

セッション一覧は以下の条件でソートできます:

#### 開始日時順 (started_at)
```
最新のセッション → 古いセッション
```

セッションが作成された日時順に表示します。デフォルトのソート順です。

**使用例:**
- 最近作成したセッションをすぐに見つけたい
- セッション作成の履歴を確認したい

#### 更新日時順 (updated_at)
```
最近更新されたセッション → 更新されていないセッション
```

セッションが最後に更新された日時順に表示します。

**使用例:**
- アクティブに作業中のセッションを確認したい
- 最近のアクティビティを追跡したい

**Web UI での操作:**
1. セッション一覧の右上にある「ソート」ドロップダウンをクリック
2. 「開始日時」または「更新日時」を選択

**API での指定:**
```bash
# 開始日時順
curl https://cc-api.example.com/api/v1/sessions?sort=started_at&order=desc

# 更新日時順
curl https://cc-api.example.com/api/v1/sessions?sort=updated_at&order=desc
```

### セッションのフィルタリング

#### ステータスでフィルタ
```bash
# 実行中のセッションのみ表示
curl https://cc-api.example.com/api/v1/sessions?status=running

# 完了したセッションのみ表示
curl https://cc-api.example.com/api/v1/sessions?status=completed
```

**利用可能なステータス:**
- `running` - 実行中
- `pending` - 準備中
- `completed` - 完了
- `failed` - 失敗
- `terminated` - 終了
- `all` - すべて (デフォルト)

### セッション詳細の表示

特定のセッションの詳細情報を確認できます。

**Web UI:**
1. セッション一覧から対象のセッションをクリック
2. セッション詳細ページが表示されます

**表示される情報:**
- セッション基本情報 (ID、名前、ユーザー)
- 現在のステータス
- リソース使用状況 (CPU、メモリの使用量とリミット)
- Pod 情報 (Pod 名、Namespace、Phase)
- 設定情報 (リソース制限、PVC、MCP サーバー)
- 接続情報 (WebSocket URL)

**API:**
```bash
curl https://cc-api.example.com/api/v1/sessions/{session_id} \
  -H "Authorization: Bearer ${GITHUB_TOKEN}"
```

## セッションの削除

### Web UI から削除

1. セッション一覧で削除したいセッションを見つける
2. セッションの右側にある「...」メニューをクリック
3. 「削除」を選択
4. 確認ダイアログで「削除」をクリック

**削除オプション:**
- **PVC も削除**: チェックを入れると永続ストレージも削除されます (デフォルト: ON)
- **強制削除**: 正常に終了できない場合に強制的に削除します

### API から削除

```bash
# 通常の削除
curl -X DELETE https://cc-api.example.com/api/v1/sessions/{session_id} \
  -H "Authorization: Bearer ${GITHUB_TOKEN}"

# PVC を保持して削除
curl -X DELETE https://cc-api.example.com/api/v1/sessions/{session_id}?delete_pvc=false \
  -H "Authorization: Bearer ${GITHUB_TOKEN}"

# 強制削除
curl -X DELETE https://cc-api.example.com/api/v1/sessions/{session_id}?force=true \
  -H "Authorization: Bearer ${GITHUB_TOKEN}"
```

**削除プロセス:**
1. セッション削除リクエストを受信
2. Pod に graceful shutdown シグナルを送信
3. 30 秒待機 (強制削除の場合はスキップ)
4. Pod を削除
5. PVC を削除 (delete_pvc=true の場合)
6. セッション記録をデータベースに保存

## Webhook によるセッション再利用

Webhook を使用して、既存のセッションを再利用することができます。これにより、毎回新しいセッションを作成する代わりに、同じセッション内でタスクを実行できます。

### 設定方法

Webhook 作成時に「セッション再利用」オプションを有効にします。

**Web UI:**
1. Webhook 設定画面で「セッション再利用」にチェック
2. 「再利用するセッション ID」を入力 (オプション)
   - 指定しない場合、最後に作成されたセッションが使用されます

**API:**
```json
{
  "name": "pr-review-webhook",
  "events": ["pull_request"],
  "reuse_session": true,
  "session_id": "session-user123-abc123"  // オプション
}
```

### 動作

1. Webhook がトリガーされる
2. 指定されたセッション ID (または最後のセッション) を確認
3. セッションが実行中の場合:
   - 新しいメッセージをそのセッションに送信
4. セッションが存在しないまたは終了している場合:
   - 新しいセッションを作成

### 使用例

**継続的なコードレビュー:**
```yaml
# 同じセッションで複数の PR をレビュー
webhook:
  name: "pr-continuous-review"
  events: ["pull_request"]
  reuse_session: true
  # セッションが作業コンテキストを保持
```

**定期的なモニタリング:**
```yaml
# 同じセッションで定期的にチェック
schedule:
  cron: "0 * * * *"  # 毎時
  reuse_session: true
  session_id: "monitoring-session"
```

### メリット

- **起動時間の短縮**: Pod 起動を待つ必要がない
- **コンテキスト保持**: 前のタスクの情報を参照可能
- **リソース効率**: 複数の Pod を起動する必要がない

### 注意事項

- セッションが長時間実行されると、リソースを占有し続けます
- セッション再利用時は、前のタスクのファイル変更が残っている可能性があります
- タイムアウト設定に注意してください

## トラブルシューティング

### Pod が起動しない

**症状:**
セッションが長時間 `Pending` 状態のまま

**原因と対処:**

1. **リソース不足**
   ```bash
   # クラスターのリソース状況を確認
   kubectl describe nodes
   ```
   - CPU またはメモリが不足している場合、リソース制限を下げる
   - または、クラスターにノードを追加

2. **イメージの Pull エラー**
   ```bash
   # Pod のイベントを確認
   kubectl describe pod {pod_name}
   ```
   - イメージレジストリの認証情報を確認
   - イメージ名とタグが正しいか確認

3. **PVC の作成失敗**
   ```bash
   # PVC の状態を確認
   kubectl get pvc
   ```
   - StorageClass が利用可能か確認
   - ストレージ容量が十分にあるか確認

### セッションに接続できない

**症状:**
セッションは `Running` だが、チャット画面に接続できない

**原因と対処:**

1. **Pod が Ready でない**
   ```bash
   # Pod の状態を確認
   kubectl get pod {pod_name}
   ```
   - Ready が 1/1 になるまで待つ
   - ログを確認してエラーを特定

2. **WebSocket 接続の問題**
   - ブラウザのコンソールでエラーメッセージを確認
   - Ingress の WebSocket 設定を確認
   - ファイアウォール設定を確認

3. **認証エラー**
   - トークンが有効か確認
   - セッションの所有者か確認
   - 権限を確認

### セッションが突然終了する

**症状:**
作業中にセッションが `Terminated` になる

**原因と対処:**

1. **タイムアウト**
   - タイムアウト設定を確認
   - 必要に応じてタイムアウトを延長

2. **リソース制限超過 (OOMKilled)**
   ```bash
   # Pod のログを確認
   kubectl logs {pod_name}
   ```
   - メモリ制限を増やす

3. **ノードのメンテナンス**
   - クラスター管理者に確認

## ベストプラクティス

### 1. セッション名を付ける

わかりやすい名前を付けることで、後から見つけやすくなります。

```bash
# 良い例
"feature-auth-implementation"
"bugfix-memory-leak"
"review-pr-123"

# 悪い例
"session-1"
"test"
"aaa"
```

### 2. 適切なリソース制限を設定

タスクに応じて適切なリソースを割り当てます。

```yaml
# 軽量タスク (ドキュメント編集など)
cpu_limit: "1"
memory_limit: "2Gi"

# 通常タスク (コード編集、テスト実行)
cpu_limit: "2"
memory_limit: "4Gi"

# 重量タスク (ビルド、大規模テスト)
cpu_limit: "4"
memory_limit: "8Gi"
```

### 3. PVC を適切に使用

長時間のタスクや大きなリポジトリを扱う場合にのみ PVC を有効化します。

**PVC を使用すべき場合:**
- 大きなリポジトリ (> 1GB)
- セッション間でファイルを保持したい
- ビルドキャッシュを再利用したい

**PVC を使用しなくて良い場合:**
- 短時間のタスク (< 30 分)
- 小さなリポジトリ (< 100MB)
- 一時的な作業

### 4. 使わないセッションは削除

リソースを効率的に使用するため、使用しなくなったセッションは削除します。

**自動削除の設定:**
```yaml
# Webhook やスケジュールで自動削除を設定
auto_delete_on_complete: true
auto_delete_after_hours: 24
```

### 5. タイムアウトを設定

セッションが無期限に実行されないよう、適切なタイムアウトを設定します。

```yaml
# 推奨: 1-3 時間
timeout_minutes: 60
```

## まとめ

セッション管理は ccplant の基盤となる機能です。適切な設定と管理により、効率的かつ安全に AI エージェントを活用できます。

### 次のステップ

- [チャットインターフェース](./chat.md) - セッション内での AI との対話方法
- [Webhook 統合](./webhooks.md) - セッションの自動起動
- [スケジュール実行](./schedules.md) - 定期的なセッション実行
- [MCP サーバー](./mcp-servers.md) - セッションの機能拡張

### 関連リソース

- [API エンドポイント](../backend/api-endpoints.md#セッション管理)
- [Kubernetes セッション管理](../backend/kubernetes-sessions.md)
- [トラブルシューティング](../deployment/troubleshooting.md)
