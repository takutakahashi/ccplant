# MCP サーバー

## 概要

MCP (Model Context Protocol) は、AI モデルが外部ツールやサービスと通信するための標準プロトコルです。MCP サーバーを使用することで、AI エージェントの機能を大幅に拡張し、GitHub、データベース、ファイルシステムなど様々な外部リソースにアクセスできるようになります。

## MCP サーバーとは

MCP サーバーは、AI エージェントが利用できるツールセットを提供するプロセスです。

**仕組み:**
```
AI エージェント
    ↓
MCP Protocol
    ↓
MCP サーバー (GitHub, Filesystem など)
    ↓
外部サービス/リソース
```

**主な機能:**
- **ツール呼び出し**: AI が外部ツールを実行
- **リソースアクセス**: ファイル、データベースなどへのアクセス
- **プロンプト**: 事前定義されたプロンプトテンプレート

## 利用可能な MCP サーバー

### 1. GitHub MCP Server

**用途:** GitHub API との統合

**機能:**
- リポジトリ情報の取得
- Issue の作成・更新
- プルリクエストの作成・レビュー
- ファイルの読み書き
- ブランチ操作

**設定:**
```json
{
  "github": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-github"],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_xxxxx"
    }
  }
}
```

### 2. Filesystem MCP Server

**用途:** ローカルファイルシステムへのアクセス

**機能:**
- ファイルの読み書き
- ディレクトリ一覧取得
- ファイル検索
- ファイル移動・削除

**設定:**
```json
{
  "filesystem": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-filesystem"],
    "env": {
      "ALLOWED_PATHS": "/workspace:/tmp"
    }
  }
}
```

### 3. Brave Search MCP Server

**用途:** Web 検索

**機能:**
- Web 検索
- ニュース検索
- 画像検索

**設定:**
```json
{
  "brave-search": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-brave-search"],
    "env": {
      "BRAVE_API_KEY": "BSA_xxxxx"
    }
  }
}
```

### 4. Postgres MCP Server

**用途:** PostgreSQL データベースアクセス

**機能:**
- SQL クエリ実行
- スキーマ情報取得
- テーブル操作

**設定:**
```json
{
  "postgres": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-postgres"],
    "env": {
      "DATABASE_URL": "postgresql://user:pass@host:5432/db"
    }
  }
}
```

### 5. Slack MCP Server

**用途:** Slack 統合

**機能:**
- メッセージ送信
- チャンネル一覧取得
- ユーザー情報取得

**設定:**
```json
{
  "slack": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-slack"],
    "env": {
      "SLACK_BOT_TOKEN": "xoxb-xxxxx"
    }
  }
}
```

## MCP サーバーの設定

### セッション作成時の設定

```bash
curl -X POST https://cc-api.example.com/api/v1/sessions \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -d '{
    "name": "dev-session",
    "config": {
      "mcp_servers": {
        "github": {
          "command": "npx",
          "args": ["-y", "@modelcontextprotocol/server-github"],
          "env": {
            "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_xxxxx"
          }
        },
        "filesystem": {
          "command": "npx",
          "args": ["-y", "@modelcontextprotocol/server-filesystem"],
          "env": {
            "ALLOWED_PATHS": "/workspace"
          }
        }
      }
    }
  }'
```

### デフォルト MCP サーバー

ユーザー設定でデフォルトの MCP サーバーを設定できます:

```yaml
# user-config.yaml
default_mcp_servers:
  github:
    command: "npx"
    args: ["-y", "@modelcontextprotocol/server-github"]
    env:
      GITHUB_PERSONAL_ACCESS_TOKEN: "${GITHUB_TOKEN}"
  filesystem:
    command: "npx"
    args: ["-y", "@modelcontextprotocol/server-filesystem"]
```

### エージェントテンプレート

エージェントに MCP サーバーを含めることができます:

```yaml
# agent.yaml
name: "github-expert"
mcp_servers:
  github:
    command: "npx"
    args: ["-y", "@modelcontextprotocol/server-github"]
  brave-search:
    command: "npx"
    args: ["-y", "@modelcontextprotocol/server-brave-search"]
```

## セッション Pod 内の MCP サーバー

MCP サーバーは、セッション Pod 内で個別のプロセスとして実行されます。

### アーキテクチャ

```
Session Pod
├── Claude Code (メインプロセス)
├── MCP Server: GitHub
├── MCP Server: Filesystem
└── MCP Server: Brave Search
```

### プロセス管理

- 各 MCP サーバーは独立したプロセス
- セッション開始時に自動起動
- セッション終了時に自動停止
- クラッシュ時は自動再起動

### 通信

Claude Code と MCP サーバー間は、標準入出力 (stdio) または HTTP で通信します。

```
Claude Code
    ↓ (stdio/HTTP)
MCP Server
    ↓
External Service
```

## カスタム MCP サーバーの作成

### Python での実装

```python
from mcp.server import MCPServer, Tool

class MyCustomServer(MCPServer):
    def __init__(self):
        super().__init__("my-custom-server")

    @Tool(
        name="custom_tool",
        description="カスタムツールの説明"
    )
    async def custom_tool(self, arg1: str, arg2: int):
        # ツールの実装
        return {"result": f"Processed {arg1} with {arg2}"}

if __name__ == "__main__":
    server = MyCustomServer()
    server.run()
```

### Node.js での実装

```javascript
import { MCPServer } from '@modelcontextprotocol/sdk';

const server = new MCPServer({
  name: 'my-custom-server',
  version: '1.0.0'
});

server.tool({
  name: 'custom_tool',
  description: 'カスタムツールの説明',
  parameters: {
    type: 'object',
    properties: {
      arg1: { type: 'string' },
      arg2: { type: 'number' }
    }
  },
  handler: async ({ arg1, arg2 }) => {
    return { result: `Processed ${arg1} with ${arg2}` };
  }
});

server.start();
```

### セッションでの使用

```json
{
  "mcp_servers": {
    "my-custom": {
      "command": "python",
      "args": ["/path/to/my_server.py"],
      "env": {
        "API_KEY": "xxxxx"
      }
    }
  }
}
```

## セキュリティ

### 環境変数の管理

機密情報は Secret で管理します:

```bash
# Secret を作成
kubectl create secret generic mcp-secrets \
  --from-literal=github-token=ghp_xxxxx \
  --from-literal=slack-token=xoxb-xxxxx
```

### アクセス制御

MCP サーバーごとにアクセス制限を設定:

```yaml
mcp_servers:
  filesystem:
    command: "npx"
    args: ["-y", "@modelcontextprotocol/server-filesystem"]
    env:
      ALLOWED_PATHS: "/workspace:/tmp"  # アクセス可能なパスを制限
      READONLY: "false"  # 読み取り専用モード
```

### ネットワーク制限

外部 MCP サーバーへの接続を制限:

```yaml
network_policy:
  allowed_hosts:
    - "api.github.com"
    - "slack.com"
```

## トラブルシューティング

### MCP サーバーが起動しない

**症状:** セッション内で MCP サーバーが利用できない

**対処:**
1. セッション Pod のログを確認
   ```bash
   kubectl logs {pod_name}
   ```

2. 環境変数を確認
3. コマンドとパスを確認

### ツールが見つからない

**症状:** AI がツールを使用できない

**対処:**
1. MCP サーバーが起動しているか確認
2. ツール名が正しいか確認
3. MCP サーバーのログを確認

## ベストプラクティス

### 1. 必要な MCP サーバーのみ設定

不要な MCP サーバーはリソースを消費するため、必要なもののみ設定します。

### 2. 環境変数を適切に管理

API キーなどの機密情報は Secret で管理します。

### 3. アクセス制限を設定

ファイルシステムやデータベースアクセスには、適切な制限を設定します。

## まとめ

MCP サーバーにより、AI エージェントの能力を大幅に拡張できます。適切なサーバーを選択・設定することで、強力な自動化ワークフローを構築できます。

### 次のステップ

- [エージェント管理](./agents.md) - MCP サーバーを含むエージェントの作成
- [セッション管理](./sessions.md) - セッション作成時の MCP 設定
- [設定管理](./settings.md) - デフォルト MCP サーバーの設定

### 関連リソース

- [MCP 公式ドキュメント](https://modelcontextprotocol.io/)
- [MCP Server リポジトリ](https://github.com/modelcontextprotocol/servers)
