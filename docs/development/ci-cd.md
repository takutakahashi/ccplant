# CI/CD パイプライン

ccplant プロジェクトの CI/CD パイプラインの詳細なドキュメントです。

## 目次

- [概要](#概要)
- [ワークフロー一覧](#ワークフロー一覧)
- [Helm Template Validation](#helm-template-validation)
- [Integration Test (Docker Compose)](#integration-test-docker-compose)
- [Integration Test (Helm/k3s)](#integration-test-helmk3s)
- [Release Process](#release-process)
- [バージョニング戦略](#バージョニング戦略)
- [トラブルシューティング](#トラブルシューティング)

## 概要

ccplant プロジェクトは GitHub Actions を使用して、自動化されたテストとリリースプロセスを実装しています。

### CI/CD パイプラインの目的

- **品質保証**: すべての変更が自動テストを通過することを保証
- **高速フィードバック**: プルリクエスト時に即座に問題を検出
- **自動リリース**: タグ作成時に自動的にチャートをパッケージングして公開
- **トレーサビリティ**: すべての変更とテスト結果を記録

### パイプラインの流れ

```
┌─────────────────┐
│  Code Push/PR   │
└────────┬────────┘
         │
         ├──────────────────────────┬──────────────────────────┬─────────────────────┐
         ▼                          ▼                          ▼                     ▼
┌──────────────────┐   ┌──────────────────────┐   ┌─────────────────────┐   ┌──────────────┐
│ Helm Template    │   │ Integration Test     │   │ Integration Test    │   │ Other Checks │
│ Validation       │   │ (Docker Compose)     │   │ (Helm/k3s)          │   │              │
│ ~1 min           │   │ ~5 min               │   │ ~10 min             │   │              │
└──────────────────┘   └──────────────────────┘   └─────────────────────┘   └──────────────┘
         │                          │                          │                     │
         └──────────────────────────┴──────────────────────────┴─────────────────────┘
                                    │
                                    ▼
                           ┌─────────────────┐
                           │  All Tests Pass │
                           └────────┬────────┘
                                    │
                                    ▼
                           ┌─────────────────┐
                           │  Ready to Merge │
                           └─────────────────┘

┌─────────────────┐
│  Tag Push (v*)  │
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│  Release Workflow       │
│  1. Extract version     │
│  2. Update dependencies │
│  3. Package chart       │
│  4. Push to OCI registry│
│  5. Create GitHub release│
└─────────────────────────┘
```

## ワークフロー一覧

| ワークフロー | ファイル | トリガー | 実行時間 | 目的 |
|------------|---------|---------|---------|------|
| Helm Template Validation | `helm-template-validation.yml` | PR/Push (charts/**) | ~1分 | Helm テンプレートの検証 |
| Integration Test | `integration-test.yml` | PR/Push | ~5分 | Docker Compose での統合テスト |
| Integration Test (Helm) | `integration-test-helm.yml` | PR/Push | ~10分 | k3s での Kubernetes 統合テスト |
| Release | `release.yml` | Tag (v*) | ~5分 | チャートのリリース |

## Helm Template Validation

### 概要

Helm チャートのテンプレートが正しく生成されることを検証します。

### ワークフローファイル

`.github/workflows/helm-template-validation.yml`

### トリガー条件

```yaml
on:
  pull_request:
    branches: [ main ]
    paths:
      - 'charts/ccplant/**'
      - 'testdata/expected.yaml'
      - '.github/workflows/helm-template-validation.yml'
  push:
    branches: [ main ]
    paths:
      - 'charts/ccplant/**'
      - 'testdata/expected.yaml'
      - '.github/workflows/helm-template-validation.yml'
  workflow_dispatch:  # 手動実行も可能
```

### 実行ステップ

```yaml
1. チェックアウト
   - actions/checkout@v4
   - fetch-depth: 0 (全履歴を取得)

2. Helm のセットアップ
   - azure/setup-helm@v4
   - version: v3.14.0

3. GitHub Container Registry へのログイン
   - helm registry login ghcr.io

4. Helm 依存関係の更新
   - helm dependency update

5. Helm テンプレートの生成
   - helm template ccplant . --namespace default > /tmp/actual.yaml

6. 期待値との比較
   - diff -u testdata/expected.yaml /tmp/actual.yaml

7. アーティファクトのアップロード (失敗時)
   - actual.yaml (実際の出力)
   - diff.txt (差分)
```

### ローカルでの再現

```bash
cd charts/ccplant

# 依存関係を更新
helm dependency update

# テンプレートを生成
helm template ccplant . --namespace default > /tmp/actual.yaml

# 期待値と比較
diff -u testdata/expected.yaml /tmp/actual.yaml
```

### 失敗時の対応

```bash
# 1. 差分を確認
diff -u testdata/expected.yaml /tmp/actual.yaml

# 2a. 意図的な変更の場合: 期待値を更新
cd charts/ccplant
helm template ccplant . --namespace default > ../../testdata/expected.yaml
git add testdata/expected.yaml
git commit -m "test: update expected Helm template output"
git push

# 2b. バグの場合: Helm チャートを修正
vim charts/ccplant/values.yaml
# または
vim charts/ccplant/templates/...
```

## Integration Test (Docker Compose)

### 概要

Docker Compose を使用して、backend と frontend の基本的な統合動作を検証します。

### ワークフローファイル

`.github/workflows/integration-test.yml`

### トリガー条件

```yaml
on:
  pull_request:
    branches: [ main ]
  push:
    branches: [ main ]
  workflow_dispatch:
```

### 実行ステップ

```yaml
1. 環境準備
   - actions/checkout@v4
   - Node.js 20 のセットアップ
   - Bun のインストール

2. Docker Compose でサービス起動
   - docker compose up -d
   - ヘルスチェック待機 (最大 120 秒)

3. サービスの動作確認
   - Backend: curl http://localhost:8080/health
   - Frontend: curl http://localhost:3000

4. Playwright のセットアップ
   - npm install -g @playwright/test
   - npx playwright install --with-deps chromium

5. E2E テストの実行
   - playwright.config.ts の生成
   - e2e/basic.spec.ts の生成
   - npx playwright test

6. レポートのアップロード
   - playwright-report/ (常にアップロード)

7. ログ収集 (失敗時)
   - docker compose logs
   - docker ps -a

8. クリーンアップ
   - docker compose down -v
```

### テストケース

```typescript
// e2e/basic.spec.ts
1. homepage loads successfully
   - ページタイトルが "AgentAPI" を含むことを確認

2. can access chat interface
   - チャットインターフェースが表示されることを確認

3. backend API is accessible
   - Backend API (/health, /, /api/health) にアクセスできることを確認
```

### ローカルでの再現

```bash
# サービス起動
docker compose up -d

# ヘルスチェック
curl http://localhost:8080/health
curl http://localhost:3000

# Playwright インストール (初回のみ)
npm install -g @playwright/test
npx playwright install --with-deps chromium

# テスト実行
npx playwright test

# クリーンアップ
docker compose down -v
```

## Integration Test (Helm/k3s)

### 概要

k3s を使用した実際の Kubernetes 環境でのデプロイと動作を検証します。

### ワークフローファイル

`.github/workflows/integration-test-helm.yml`

### トリガー条件

```yaml
on:
  pull_request:
    branches: [ main ]
  push:
    branches: [ main ]
  workflow_dispatch:
```

### 実行ステップ

```yaml
1. 環境準備
   - actions/checkout@v4 (submodules: recursive)
   - Node.js 20 のセットアップ
   - Bun のインストール

2. k3s のインストール
   - curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
   - kubectl wait --for=condition=ready node --all --timeout=300s

3. Helm のインストール
   - curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

4. Helm 依存関係の更新
   - helm registry login ghcr.io
   - helm dependency update

5. Helm でデプロイ
   - test-values.yaml の生成 (NodePort 設定)
   - helm install ccplant-test ./charts/ccplant -f test-values.yaml --wait --timeout 10m

6. デプロイ確認
   - kubectl get pods
   - kubectl get services

7. サービスの動作確認
   - Backend: curl http://localhost:30080/health
   - Frontend: curl http://localhost:30081

8. E2E テストの実行
   - Playwright のセットアップ
   - NodePort (30081) 経由でテスト

9. ログ収集 (失敗時)
   - kubectl get pods -o wide
   - kubectl logs --all-containers=true
   - kubectl get events

10. クリーンアップ
    - helm uninstall ccplant-test
```

### test-values.yaml の内容

```yaml
backend:
  image:
    repository: ghcr.io/takutakahashi/agentapi-proxy
    tag: latest
    pullPolicy: Always
  service:
    type: NodePort
    port: 8080
    nodePort: 30080
  ingress:
    enabled: false
  autoscaling:
    enabled: false
  replicaCount: 1

frontend:
  image:
    repository: ghcr.io/takutakahashi/agentapi-ui
    tag: latest
    pullPolicy: Always
  service:
    type: NodePort
    port: 3000
    nodePort: 30081
  ingress:
    enabled: false
  autoscaling:
    enabled: false
  replicaCount: 1
  env:
    - name: NODE_ENV
      value: "production"
    - name: API_URL
      value: "http://localhost:30080"
    - name: NEXT_PUBLIC_AGENTAPI_PROXY_URL
      value: "http://localhost:30080"
```

### ローカルでの再現

```bash
# k3s をインストール (Linux のみ)
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Helm 依存関係を更新
cd charts/ccplant
helm dependency update

# test-values.yaml を作成 (上記の内容)
vim test-values.yaml

# デプロイ
helm install ccplant-test . -f test-values.yaml --wait --timeout 10m

# 確認
kubectl get pods
curl http://localhost:30080/health
curl http://localhost:30081

# クリーンアップ
helm uninstall ccplant-test
```

## Release Process

### 概要

Git タグ作成時に自動的にチャートをパッケージングし、OCI レジストリにプッシュして GitHub リリースを作成します。

### ワークフローファイル

`.github/workflows/release.yml`

### トリガー条件

```yaml
on:
  push:
    tags:
      - 'v*'  # v で始まるタグ (例: v0.1.0, v1.0.0)
```

### 実行ステップ

```yaml
1. バージョン抽出
   - タグから v を除いた数字を抽出
   - 例: v0.1.0 → 0.1.0

2. 依存コンポーネントの最新バージョン取得
   - agentapi-proxy の最新リリースタグを取得
   - agentapi-ui の最新リリースタグを取得
   - GitHub API 使用: gh api repos/owner/repo/releases/latest

3. Chart.yaml の更新
   - version: 抽出したバージョンに更新
   - appVersion: 抽出したバージョンに更新
   - dependencies: 最新バージョンに更新
     - agentapi-proxy: v{version}
     - agentapi-ui: {version} (v なし)

4. Helm のセットアップ
   - azure/setup-helm@v4
   - version: 3.18.3

5. 依存関係の更新
   - helm registry login ghcr.io
   - helm dependency update

6. チャートの検証
   - helm lint charts/ccplant/

7. チャートのパッケージング
   - helm package charts/ccplant/
   - 出力: ccplant-{version}.tgz

8. OCI レジストリへのプッシュ
   - helm push ccplant-{version}.tgz oci://ghcr.io/{owner}/charts

9. リリースノートの生成
   - インストールコマンド
   - アップグレードコマンド
   - バージョン情報
   - コンポーネントバージョン

10. GitHub リリースの作成
    - softprops/action-gh-release@v2
    - リリースノート添付
    - ccplant-{version}.tgz 添付

11. アーティファクトのアップロード
    - ccplant-{version}.tgz
    - release-notes.md
    - 保持期間: 30 日
```

### リリースの実行方法

```bash
# 1. すべての変更がコミット済みであることを確認
git status

# 2. タグを作成
git tag -a v0.2.0 -m "Release v0.2.0"

# 3. タグをプッシュ
git push origin v0.2.0

# 4. GitHub Actions でリリースワークフローが自動実行される
# 5. GitHub Releases ページで確認
```

### リリースノートの例

```markdown
# ccplant Release v0.2.0

## Installation

```bash
helm install ccplant oci://ghcr.io/takutakahashi/charts/ccplant --version 0.2.0
```

## Upgrade

```bash
helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant --version 0.2.0
```

## Chart Information

- **Chart Version**: 0.2.0
- **App Version**: 0.2.0
- **Registry**: ghcr.io/takutakahashi/charts/ccplant
- **Backend Version**: 1.191.0
- **Frontend Version**: 1.97.0

## Components

This chart deploys the complete ccplant stack including:
- agentapi-proxy (backend)
- agentapi-ui (frontend)

## Changes

See the [changelog](CHANGELOG.md) for detailed changes in this release.
```

## バージョニング戦略

### セマンティックバージョニング

ccplant は [Semantic Versioning 2.0.0](https://semver.org/) に従います。

```
MAJOR.MINOR.PATCH

例: v1.2.3
  1 = Major version (破壊的変更)
  2 = Minor version (後方互換性のある機能追加)
  3 = Patch version (後方互換性のあるバグ修正)
```

### バージョンアップの基準

#### MAJOR (破壊的変更)

```yaml
# 例: values.yaml の構造変更
# v1.x.x
backend:
  image: ghcr.io/...

# v2.x.x (BREAKING CHANGE)
agentapi-proxy:
  image: ghcr.io/...
```

#### MINOR (機能追加)

```yaml
# 例: 新しい設定オプションの追加
# v0.2.0
monitoring:
  enabled: true
  prometheus:
    enabled: true
```

#### PATCH (バグ修正)

```yaml
# 例: デフォルト値の修正
# v0.1.1
resources:
  limits:
    memory: 512Mi  # 256Mi から修正
```

### 依存コンポーネントのバージョン管理

```yaml
# Chart.yaml
dependencies:
  - name: agentapi-proxy
    version: "v1.191.0"  # v プレフィックス付き
    repository: "oci://ghcr.io/takutakahashi/charts"
  - name: agentapi-ui
    version: "v1.97.0"    # v プレフィックス付き
    repository: "oci://ghcr.io/takutakahashi/charts"
```

リリース時に自動的に最新バージョンに更新されます。

## トラブルシューティング

### ワークフローが失敗した場合

#### 1. ログの確認

```bash
# GitHub CLI を使用
gh run list --workflow=helm-template-validation.yml
gh run view <run-id> --log

# または GitHub UI で確認
# https://github.com/takutakahashi/ccplant/actions
```

#### 2. ローカルで再現

```bash
# 失敗したワークフローと同じコマンドを実行
# 例: Helm Template Validation
cd charts/ccplant
helm dependency update
helm template ccplant . --namespace default > /tmp/actual.yaml
diff -u testdata/expected.yaml /tmp/actual.yaml
```

#### 3. アーティファクトの確認

```bash
# GitHub UI でアーティファクトをダウンロード
# または GitHub CLI で
gh run download <run-id>
```

### よくある問題

#### Helm 依存関係の更新失敗

```
Error: failed to download "oci://ghcr.io/takutakahashi/charts/agentapi-proxy"
```

**対処法**:

```bash
# GitHub Container Registry へのログイン確認
echo $GITHUB_TOKEN | helm registry login ghcr.io --username $GITHUB_ACTOR --password-stdin

# 手動で依存関係を更新
cd charts/ccplant
helm dependency update
```

#### Docker Compose ヘルスチェックタイムアウト

```
Error: Timeout waiting for services to be healthy
```

**対処法**:

```bash
# サービスのログを確認
docker compose logs backend
docker compose logs frontend

# イメージを再取得
docker compose pull
docker compose up -d --force-recreate
```

#### k3s デプロイ失敗

```
Error: timed out waiting for the condition
```

**対処法**:

```bash
# Pod の状態確認
kubectl get pods -o wide
kubectl describe pod <pod-name>

# イベント確認
kubectl get events --sort-by='.lastTimestamp'

# リソース確認
kubectl top nodes
```

#### リリースワークフロー失敗

```
Error: failed to push chart to OCI registry
```

**対処法**:

```bash
# GITHUB_TOKEN のパーミッション確認
# Settings > Actions > General > Workflow permissions
# "Read and write permissions" が必要

# 手動でプッシュを試行
helm package charts/ccplant/
echo $GITHUB_TOKEN | helm registry login ghcr.io --username $GITHUB_ACTOR --password-stdin
helm push ccplant-0.2.0.tgz oci://ghcr.io/takutakahashi/charts
```

### 手動でワークフローを実行

```bash
# workflow_dispatch が有効なワークフローを手動実行
gh workflow run helm-template-validation.yml

# 特定のブランチで実行
gh workflow run helm-template-validation.yml --ref feature/my-branch

# 実行状況を確認
gh run list --workflow=helm-template-validation.yml
gh run watch
```

## CI/CD のベストプラクティス

### 1. 高速なフィードバック

```yaml
# 並列実行を活用
jobs:
  helm-validation:
    runs-on: ubuntu-latest
    # ...

  docker-compose-test:
    runs-on: ubuntu-latest
    # ...

  helm-k3s-test:
    runs-on: ubuntu-latest
    # ...
```

### 2. 適切なタイムアウト設定

```yaml
jobs:
  integration-test:
    runs-on: ubuntu-latest
    timeout-minutes: 30  # 長すぎないタイムアウト
```

### 3. 詳細なログとアーティファクト

```yaml
- name: Upload logs on failure
  if: failure()
  uses: actions/upload-artifact@v4
  with:
    name: test-logs
    path: logs/
    retention-days: 7
```

### 4. キャッシュの活用

```yaml
- name: Cache Helm dependencies
  uses: actions/cache@v4
  with:
    path: charts/ccplant/charts/
    key: ${{ runner.os }}-helm-${{ hashFiles('charts/ccplant/Chart.lock') }}
```

## 次のステップ

- [テストガイド](./testing.md) - ローカルでのテスト実行
- [コントリビューションガイド](./contributing.md) - PR の作成方法
- [リリースノート](../../CHANGELOG.md) - 変更履歴

## 参考リンク

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Helm Chart Releaser Action](https://github.com/helm/chart-releaser-action)
- [OCI Registry for Helm](https://helm.sh/docs/topics/registries/)
- [Semantic Versioning](https://semver.org/)
