# エージェント管理

## 概要

エージェント (Agent) は、特定のタスクや用途に特化した AI の動作設定です。コードレビュー、ドキュメント生成、バグ修正など、目的に応じて最適化されたエージェントを選択・カスタマイズできます。

## エージェントとは

エージェントは以下の要素から構成されます:

- **システムプロンプト**: AI の役割と振る舞いを定義
- **ツール設定**: 利用可能な MCP サーバーとツール
- **デフォルト設定**: CPU、メモリなどのリソース設定
- **テンプレート**: よく使うメッセージパターン

## エージェント一覧

### 組み込みエージェント

ccplant には、以下の組み込みエージェントが用意されています:

#### 1. Claude Code (デフォルト)
**用途:** 汎用的なコーディングアシスタント

**特徴:**
- すべてのプログラミング言語に対応
- ファイル操作、Git 操作、ビルド実行が可能
- 柔軟なタスク対応

**推奨用途:**
- 新機能の実装
- リファクタリング
- バグ修正
- 技術調査

#### 2. Code Reviewer
**用途:** コードレビュー専門

**特徴:**
- コード品質チェック
- ベストプラクティスの提案
- セキュリティの脆弱性検出
- パフォーマンスの最適化提案

**推奨用途:**
- プルリクエストのレビュー
- コード監査
- リファクタリング提案

#### 3. Documentation Writer
**用途:** ドキュメント作成

**特徴:**
- API ドキュメント生成
- README 作成
- チュートリアル作成
- コメント生成

**推奨用途:**
- プロジェクトドキュメント
- API リファレンス
- ユーザーガイド

#### 4. Test Engineer
**用途:** テスト作成とテスト実行

**特徴:**
- ユニットテスト生成
- 統合テスト作成
- テストカバレッジ向上
- テストケース提案

**推奨用途:**
- テスト駆動開発
- レガシーコードへのテスト追加
- テストカバレッジ改善

#### 5. DevOps Engineer
**用途:** インフラとデプロイメント

**特徴:**
- CI/CD パイプライン構築
- Kubernetes マニフェスト作成
- Terraform コード生成
- Docker イメージ最適化

**推奨用途:**
- インフラのコード化
- デプロイメント自動化
- モニタリング設定

## エージェントマーケットプレイス

### コミュニティエージェント

ユーザーが作成・共有したエージェントをインストールできます。

**カテゴリ:**
- プログラミング言語特化 (Python, Go, Rust など)
- フレームワーク特化 (React, Django, Spring など)
- ドメイン特化 (Machine Learning, Security など)

### エージェントの検索

```bash
# Web UI で検索
- カテゴリ別
- タグ別
- 人気順
- 評価順

# API で検索
curl https://cc-api.example.com/api/v1/agents?category=code-review
```

### エージェントのインストール

#### Web UI から

1. エージェント一覧を開く
2. 「マーケットプレイス」タブをクリック
3. インストールしたいエージェントを見つける
4. 「インストール」ボタンをクリック
5. 権限を確認して「インストール」

#### API から

```bash
curl -X POST https://cc-api.example.com/api/v1/agents/install \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -d '{
    "agent_id": "community/python-expert",
    "version": "1.0.0"
  }'
```

## カスタムエージェントの作成

### エージェント設定ファイル

```yaml
# agent.yaml
name: "my-custom-agent"
version: "1.0.0"
description: "カスタムエージェントの説明"

# システムプロンプト
system_prompt: |
  あなたは経験豊富な Python エンジニアです。
  以下のルールに従ってください:
  1. PEP 8 スタイルガイドを遵守
  2. 型ヒントを常に使用
  3. docstring を必ず記述
  4. テストファーストで開発

# デフォルト設定
defaults:
  cpu_limit: "2"
  memory_limit: "4Gi"
  timeout_minutes: 60

# MCP サーバー
mcp_servers:
  github:
    command: "npx"
    args: ["-y", "@modelcontextprotocol/server-github"]
  filesystem:
    command: "npx"
    args: ["-y", "@modelcontextprotocol/server-filesystem"]

# メッセージテンプレート
templates:
  - name: "code_review"
    content: |
      以下のコードをレビューしてください:
      {{ .code }}

      チェック項目:
      1. PEP 8 準拠
      2. 型ヒント
      3. テストの有無
```

### エージェントのパブリッシュ

```bash
# エージェントをパッケージ化
ccplant agent package agent.yaml

# マーケットプレイスに公開
ccplant agent publish my-custom-agent-1.0.0.tar.gz
```

## エージェントテンプレート

よく使うパターンをテンプレート化して再利用できます。

### テンプレートの種類

#### 1. コードレビューテンプレート
```
このファイルをレビューしてください: {{ .file }}

確認ポイント:
- コード品質
- セキュリティ
- パフォーマンス
```

#### 2. バグ修正テンプレート
```
以下のバグを修正してください:

エラーメッセージ:
{{ .error }}

再現手順:
{{ .steps }}
```

#### 3. リファクタリングテンプレート
```
以下のコードをリファクタリングしてください:
{{ .code }}

目標:
- 可読性の向上
- DRY 原則の適用
- テスタビリティの向上
```

### テンプレートの使用

```typescript
// セッション作成時にテンプレートを指定
{
  "agent_id": "code-reviewer",
  "template": "code_review",
  "variables": {
    "file": "src/auth.py"
  }
}
```

## エージェント設定

### リソース制限

エージェントごとにデフォルトのリソース制限を設定できます:

```yaml
defaults:
  cpu_limit: "2"
  memory_limit: "4Gi"
  pvc_enabled: true
  pvc_storage_size: "10Gi"
```

### 権限設定

エージェントが実行できる操作を制限:

```yaml
permissions:
  file_operations: true
  git_operations: true
  network_access: true
  shell_execution: false
```

## ベストプラクティス

### 1. 目的に応じたエージェントを選択

```
✓ コードレビュー → Code Reviewer
✓ ドキュメント作成 → Documentation Writer
✓ テスト作成 → Test Engineer

✗ すべてのタスクに汎用エージェントを使用
```

### 2. カスタムエージェントの活用

プロジェクト固有のルールやスタイルは、カスタムエージェントとして定義します。

### 3. テンプレートで効率化

よく使うパターンはテンプレート化して再利用します。

## まとめ

適切なエージェントを選択・カスタマイズすることで、AI の能力を最大限に活用できます。

### 次のステップ

- [MCP サーバー](./mcp-servers.md) - エージェントの機能拡張
- [セッション管理](./sessions.md) - エージェントの実行環境
- [設定管理](./settings.md) - デフォルト設定のカスタマイズ
