# コントリビューションガイド

ccplant プロジェクトへのコントリビューション方法を説明します。

## 目次

- [コントリビューションの種類](#コントリビューションの種類)
- [開発環境のセットアップ](#開発環境のセットアップ)
- [ブランチ戦略](#ブランチ戦略)
- [コーディング規約](#コーディング規約)
- [コミットメッセージ規約](#コミットメッセージ規約)
- [プルリクエストプロセス](#プルリクエストプロセス)
- [コードレビューガイドライン](#コードレビューガイドライン)
- [イシュー報告](#イシュー報告)
- [コミュニティガイドライン](#コミュニティガイドライン)

## コントリビューションの種類

ccplant プロジェクトへのコントリビューションには、以下のような形があります:

### 1. コード関連

- **機能追加**: 新しい機能の実装
- **バグ修正**: 既存の問題の修正
- **リファクタリング**: コードの改善と最適化
- **テスト**: テストカバレッジの向上

### 2. ドキュメント関連

- **ドキュメント追加**: 新しいドキュメントの作成
- **ドキュメント改善**: 既存ドキュメントの修正・拡充
- **翻訳**: 多言語対応
- **サンプル追加**: 使用例の追加

### 3. その他

- **イシュー報告**: バグや改善提案の報告
- **イシュートリアージ**: イシューの分類や優先度付け
- **レビュー**: プルリクエストのレビュー
- **コミュニティサポート**: 質問への回答

## 開発環境のセットアップ

コントリビューションを始める前に、開発環境をセットアップしてください。

### クイックスタート

```bash
# 1. リポジトリをフォーク
# GitHub UI で "Fork" ボタンをクリック

# 2. フォークしたリポジトリをクローン
git clone https://github.com/YOUR_USERNAME/ccplant.git
cd ccplant

# 3. upstream リモートを追加
git remote add upstream https://github.com/takutakahashi/ccplant.git

# 4. 開発ツールをインストール
mise install

# 5. Helm 依存関係を更新
cd charts/ccplant
helm dependency update
cd ../..

# 6. 動作確認
docker compose up -d
curl http://localhost:8080/health
curl http://localhost:3000
docker compose down
```

詳細は [開発環境セットアップガイド](./setup.md) を参照してください。

## ブランチ戦略

### ブランチ命名規則

プロジェクトでは以下のブランチ命名規則を使用しています:

```
<type>/<short-description>
```

#### ブランチタイプ

| タイプ | 用途 | 例 |
|--------|------|-----|
| `feature/` | 新機能開発 | `feature/add-monitoring-dashboard` |
| `fix/` | バグ修正 | `fix/health-check-timeout` |
| `docs/` | ドキュメント更新 | `docs/update-contributing-guide` |
| `test/` | テスト追加・改善 | `test/add-e2e-tests` |
| `refactor/` | リファクタリング | `refactor/simplify-values-structure` |
| `chore/` | ビルド・CI 関連 | `chore/update-dependencies` |

### ブランチ作成の例

```bash
# 最新の main から作業ブランチを作成
git checkout main
git pull upstream main
git checkout -b feature/add-monitoring-dashboard

# 作業を実施
# ...

# コミット
git add .
git commit -m "feat: add monitoring dashboard"

# プッシュ
git push origin feature/add-monitoring-dashboard
```

### メインブランチ

- **main**: 本番リリース用の安定ブランチ
  - 常にリリース可能な状態を維持
  - 直接プッシュは禁止 (PR 経由でのみマージ)
  - すべてのテストが通過していること

## コーディング規約

### YAML ファイル

```yaml
# ✅ Good: 2 スペースインデント、明確な構造
global:
  hostname: example.com
  apiHostname: api.example.com

  github:
    oauth:
      clientId: ""
      clientSecret: ""

# ❌ Bad: インデント不統一、構造不明確
global:
 hostname: example.com
 github:
  oauth:
   clientId: ""
```

### ベストプラクティス

#### 1. values.yaml の記述

```yaml
# ✅ Good: コメントで説明、デフォルト値を明示
# Backend のレプリカ数
# 本番環境では 2 以上を推奨
replicaCount: 2

# ✅ Good: グループ化と見出し
# =============================================================================
# Backend 設定
# =============================================================================
backend:
  image:
    repository: ghcr.io/takutakahashi/agentapi-proxy
    tag: latest
```

#### 2. Helm テンプレートのベストプラクティス

```yaml
# ✅ Good: 条件分岐は明確に
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
# ...
{{- end }}

# ✅ Good: デフォルト値の設定
image: {{ .Values.image.repository }}:{{ .Values.image.tag | default "latest" }}

# ✅ Good: 適切なインデント
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
```

#### 3. ドキュメント

```markdown
# ✅ Good: 実行可能なコード例
```bash
# コマンドの説明
helm install ccplant ./charts/ccplant

# 期待される出力
NAME: ccplant
NAMESPACE: default
```

# ✅ Good: 構造化された目次
## 目次
- [セクション1](#セクション1)
- [セクション2](#セクション2)
```

## コミットメッセージ規約

### Conventional Commits

プロジェクトは [Conventional Commits](https://www.conventionalcommits.org/) 規約に従います。

### フォーマット

```
<type>(<scope>): <subject>

<body>

<footer>
```

### タイプ

| タイプ | 説明 | 例 |
|--------|------|-----|
| `feat` | 新機能 | `feat: add support for custom annotations` |
| `fix` | バグ修正 | `fix: resolve health check timeout` |
| `docs` | ドキュメント | `docs: update setup guide` |
| `style` | フォーマット | `style: fix yaml indentation` |
| `refactor` | リファクタリング | `refactor: simplify values structure` |
| `test` | テスト | `test: add helm template validation` |
| `chore` | ビルド・CI | `chore: update dependencies` |
| `ci` | CI 設定 | `ci: update workflow triggers` |

### スコープ (オプション)

```bash
# チャート関連
git commit -m "feat(chart): add support for external secrets"

# ドキュメント関連
git commit -m "docs(setup): add mise installation steps"

# CI 関連
git commit -m "ci(helm-test): add retry logic"
```

### 例

#### 良い例

```bash
# シンプルな機能追加
git commit -m "feat: add monitoring dashboard support"

# スコープ付き
git commit -m "feat(chart): add custom ingress annotations"

# 詳細な説明付き
git commit -m "feat: add monitoring dashboard support

Add Prometheus and Grafana integration:
- Add prometheus-operator as optional dependency
- Add default dashboards for backend and frontend
- Update documentation with monitoring setup

Closes #123"

# Breaking change
git commit -m "feat!: change default ingress class to nginx

BREAKING CHANGE: The default ingress class has been changed from 'traefik' to 'nginx'.
Users need to update their values.yaml accordingly."
```

#### 悪い例

```bash
# ❌ タイプなし
git commit -m "update chart"

# ❌ 説明が不明確
git commit -m "fix: fix bug"

# ❌ 複数の変更を含む
git commit -m "feat: add monitoring and fix bugs and update docs"
```

## プルリクエストプロセス

### 1. プルリクエストの作成

```bash
# 1. 作業ブランチを作成
git checkout -b feature/my-feature

# 2. 変更を実施
vim charts/ccplant/values.yaml

# 3. テストを実行
cd charts/ccplant
helm lint .
helm template ccplant . > /tmp/test.yaml
docker compose up -d
# テスト実施
docker compose down

# 4. コミット
git add .
git commit -m "feat: add my feature"

# 5. プッシュ
git push origin feature/my-feature

# 6. GitHub UI でプルリクエストを作成
```

### 2. PR テンプレート

プルリクエスト作成時は以下の情報を含めてください:

```markdown
## 概要
この PR の目的と変更内容を簡潔に説明してください。

## 変更内容
- [ ] 機能追加
- [ ] バグ修正
- [ ] ドキュメント更新
- [ ] テスト追加
- [ ] リファクタリング

## 変更の詳細
### 変更したファイル
- `charts/ccplant/values.yaml`: モニタリング設定を追加
- `docs/operations/monitoring.md`: モニタリングガイドを追加

### テスト方法
```bash
# テストコマンド
helm template ccplant . -f test-values.yaml
docker compose up -d
curl http://localhost:9090  # Prometheus
```

## チェックリスト
- [ ] コードは動作確認済み
- [ ] テストを追加/更新した
- [ ] ドキュメントを更新した
- [ ] コミットメッセージは規約に準拠している
- [ ] CI テストがすべて通過している

## 関連イシュー
Closes #123
Related to #456

## スクリーンショット (該当する場合)
(スクリーンショットを添付)
```

### 3. レビューへの対応

```bash
# レビューコメントに従って修正
vim charts/ccplant/values.yaml

# 修正をコミット
git add .
git commit -m "fix: address review comments"

# プッシュ (PR が自動更新される)
git push origin feature/my-feature
```

### 4. マージ前の最終確認

```bash
# 最新の main をマージ
git checkout main
git pull upstream main
git checkout feature/my-feature
git merge main

# コンフリクトを解決 (必要な場合)
# ...

# 最終テスト
docker compose up -d
# テスト実施
docker compose down

# プッシュ
git push origin feature/my-feature
```

## コードレビューガイドライン

### レビュアーの責務

#### 1. 機能性の確認

```bash
# PR のブランチをチェックアウト
gh pr checkout 123

# 動作確認
cd charts/ccplant
helm dependency update
helm template ccplant . > /tmp/output.yaml
docker compose up -d
# 機能テスト
docker compose down
```

#### 2. コードの品質確認

- [ ] コーディング規約に準拠しているか
- [ ] 適切なエラーハンドリングがあるか
- [ ] ドキュメントは十分か
- [ ] テストは適切か

#### 3. セキュリティの確認

- [ ] シークレットが平文でコミットされていないか
- [ ] 適切な権限設定か
- [ ] 入力検証は十分か

### レビューコメントの書き方

```markdown
# ✅ Good: 建設的で具体的
このヘルスチェックのタイムアウトは 5 秒では短すぎるかもしれません。
起動に時間がかかる環境を考慮して、10 秒に延長することを提案します。

```yaml
healthcheck:
  timeout: 10s  # 5s から変更
```

# ✅ Good: 提案と理由
`values.yaml` でデフォルト値を設定することを推奨します。
これにより、ユーザーが明示的に設定しなくても動作します。

# ❌ Bad: 批判的で不明確
これは良くない。修正してください。

# ❌ Bad: 理由なし
ここを変更してください。
```

### PR の承認基準

以下の条件を満たす場合に PR を承認します:

- [ ] すべての CI テストが通過
- [ ] コーディング規約に準拠
- [ ] 適切なドキュメントがある
- [ ] 2 名以上のレビュアーによる承認 (重要な変更の場合)
- [ ] Breaking changes は明確にドキュメント化されている

## イシュー報告

### バグ報告

```markdown
## バグの説明
Helm でデプロイした際に、backend の Pod が起動しません。

## 再現手順
1. `helm install ccplant ./charts/ccplant` を実行
2. `kubectl get pods` で確認
3. Pod が `CrashLoopBackOff` 状態になる

## 期待される動作
Pod が正常に起動し、`Running` 状態になる。

## 実際の動作
Pod が `CrashLoopBackOff` 状態になる。

## 環境
- ccplant バージョン: v0.1.0
- Kubernetes バージョン: v1.28.0
- Helm バージョン: v3.14.0
- OS: Ubuntu 22.04

## ログ
```bash
kubectl logs ccplant-backend-xxx
# エラーログを貼り付け
```

## 追加情報
values.yaml で以下の設定を使用:
```yaml
global:
  hostname: ccplant.local
```
```

### 機能リクエスト

```markdown
## 機能の説明
Ingress に custom annotations を設定できるようにしてほしい。

## モチベーション
現在、Ingress の annotations は固定されており、カスタマイズできません。
AWS ALB Ingress Controller を使用する際に、ALB 固有の annotations を設定したいです。

## 提案する実装
values.yaml に `ingress.annotations` を追加:

```yaml
ingress:
  enabled: true
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
```

## 代替案
ConfigMap で設定を管理する方法も検討しましたが、
values.yaml での設定の方が Helm の標準的な方法です。

## 追加コンテキスト
他の多くの Helm チャート (nginx-ingress, cert-manager など) でも
同様のパターンが採用されています。
```

## コミュニティガイドライン

### 行動規範

- **尊重**: すべてのコントリビューターを尊重してください
- **建設的**: フィードバックは建設的で具体的に
- **オープン**: 異なる意見や視点を歓迎します
- **協力**: 協力的な態度で問題解決に取り組みます

### コミュニケーション

- **GitHub Issues**: バグ報告、機能リクエスト
- **Pull Requests**: コードレビュー、議論
- **GitHub Discussions**: 一般的な質問、アイデア共有

### サポート

質問やサポートが必要な場合:

1. [ドキュメント](../README.md) を確認
2. [既存の Issues](https://github.com/takutakahashi/ccplant/issues) を検索
3. 新しい Issue を作成

## 謝辞

すべてのコントリビューターに感謝します！

コントリビューションは以下の方法で認識されます:

- [Contributors](https://github.com/takutakahashi/ccplant/graphs/contributors) ページ
- リリースノート
- プロジェクトドキュメント

## 参考リンク

- [開発環境セットアップ](./setup.md)
- [テストガイド](./testing.md)
- [CI/CD ガイド](./ci-cd.md)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow)
