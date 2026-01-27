# テスト戦略と実行

ccplant プロジェクトの包括的なテスト戦略と実行方法を説明します。

## 目次

- [テスト戦略の概要](#テスト戦略の概要)
- [Helm テンプレート検証](#helm-テンプレート検証)
- [Docker Compose 統合テスト](#docker-compose-統合テスト)
- [Kubernetes 統合テスト](#kubernetes-統合テスト)
- [E2E テスト (Playwright)](#e2e-テスト-playwright)
- [テストカバレッジ](#テストカバレッジ)
- [CI/CD でのテスト](#cicd-でのテスト)
- [トラブルシューティング](#トラブルシューティング)

## テスト戦略の概要

ccplant プロジェクトは、以下の多層的なテスト戦略を採用しています:

### テストレベル

```
┌─────────────────────────────────────────┐
│  E2E テスト (Playwright)                │
│  ブラウザでの実際のユーザー操作          │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  統合テスト (Docker Compose / k3s)      │
│  実際のコンテナ環境での動作検証          │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  Helm テンプレート検証                   │
│  生成される Kubernetes マニフェストの検証│
└─────────────────────────────────────────┘
```

### テストの種類と目的

| テストの種類 | 目的 | 実行環境 | 実行時間 |
|------------|------|---------|---------|
| Helm テンプレート検証 | Helm チャートの構文と出力の正当性 | CI/PR | ~1分 |
| Docker Compose 統合テスト | コンテナレベルでの基本的な動作確認 | CI/PR | ~5分 |
| Kubernetes 統合テスト | k3s での実際の Kubernetes 環境テスト | CI/PR | ~10分 |
| E2E テスト | ブラウザでの実際のユーザーフロー検証 | CI/PR | ~5分 |

## Helm テンプレート検証

### 概要

Helm チャートから生成される Kubernetes マニフェストが期待通りであることを検証します。

### ローカルでの実行

```bash
# プロジェクトルートに移動
cd /path/to/ccplant

# Helm 依存関係を更新
cd charts/ccplant
helm dependency update

# テンプレートを生成
helm template ccplant . --namespace default > /tmp/actual.yaml

# 期待値と比較
diff -u testdata/expected.yaml /tmp/actual.yaml

# 差分がなければテスト成功
echo $?  # 0 なら成功
```

### 期待値の更新

Helm チャートを変更した場合、期待値も更新する必要があります:

```bash
# 新しい期待値を生成
cd charts/ccplant
helm template ccplant . --namespace default > ../../testdata/expected.yaml

# 変更を確認
git diff testdata/expected.yaml

# 変更が意図通りであればコミット
git add testdata/expected.yaml
git commit -m "test: update expected Helm template output"
```

### CI での実行

`.github/workflows/helm-template-validation.yml` で自動実行されます:

```yaml
# トリガー条件
- charts/ccplant/** が変更された場合
- testdata/expected.yaml が変更された場合
- Pull Request または main ブランチへの push
```

### テスト失敗時の対応

```bash
# CI が失敗した場合、アーティファクトをダウンロード
# GitHub Actions の Artifacts セクションから:
# - helm-template-actual (実際の出力)
# - helm-template-diff (差分)

# ローカルで差分を確認
diff -u testdata/expected.yaml /tmp/actual.yaml

# 期待値を更新するか、Helm チャートを修正
```

## Docker Compose 統合テスト

### 概要

Docker Compose を使用して、backend と frontend の基本的な統合動作を検証します。

### ローカルでの実行

```bash
# プロジェクトルートに移動
cd /path/to/ccplant

# サービスを起動
docker compose up -d

# サービスがヘルシーになるまで待機
timeout 120 bash -c 'until docker compose ps | grep "Up (healthy)"; do sleep 5; done'

# Backend のヘルスチェック
curl -f http://localhost:8080/health || curl -f http://localhost:8080/

# Frontend のアクセス確認
curl -f http://localhost:3000

# テスト成功
echo "✅ Docker Compose integration test passed"

# クリーンアップ
docker compose down -v
```

### 詳細なテスト手順

#### 1. サービスの起動確認

```bash
# サービスの状態を確認
docker compose ps

# 期待される出力:
# NAME                IMAGE                                       STATUS
# ccplant-backend     ghcr.io/takutakahashi/agentapi-proxy:latest Up (healthy)
# ccplant-frontend    ghcr.io/takutakahashi/agentapi-ui:latest    Up (healthy)
```

#### 2. ヘルスチェックの確認

```bash
# Backend ヘルスチェック
curl -v http://localhost:8080/health

# 期待されるレスポンス: 200 OK
# {"status":"healthy"}

# Frontend ヘルスチェック
curl -v http://localhost:3000

# 期待されるレスポンス: 200 OK (HTML ページ)
```

#### 3. ログの確認

```bash
# Backend ログ
docker compose logs backend

# Frontend ログ
docker compose logs frontend

# エラーがないことを確認
docker compose logs | grep -i error
```

### CI での実行

`.github/workflows/integration-test.yml` で自動実行されます:

```yaml
# 実行内容
1. Docker Compose でサービス起動
2. ヘルスチェック待機
3. 基本的な E2E テスト実行 (Playwright)
4. ログ収集
5. クリーンアップ
```

## Kubernetes 統合テスト

### 概要

k3s を使用した実際の Kubernetes 環境でのデプロイと動作を検証します。

### ローカルでの実行

#### 前提条件

```bash
# k3s をインストール
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

# kubeconfig を設定
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# クラスター確認
kubectl get nodes
```

#### テスト手順

```bash
# 1. Helm 依存関係を更新
cd charts/ccplant
helm dependency update

# 2. テスト用 values ファイルを作成
cat > test-values.yaml <<EOF
global:
  hostname: ccplant.local
  apiHostname: api.ccplant.local

agentapi-proxy:
  service:
    type: NodePort
    nodePort: 30080
  ingress:
    enabled: false
  autoscaling:
    enabled: false
  replicaCount: 1

agentapi-ui:
  service:
    type: NodePort
    nodePort: 30081
  ingress:
    enabled: false
  autoscaling:
    enabled: false
  replicaCount: 1
  env:
    - name: NEXT_PUBLIC_AGENTAPI_PROXY_URL
      value: "http://localhost:30080"
EOF

# 3. Helm でインストール
helm install ccplant-test . -f test-values.yaml --wait --timeout 10m

# 4. デプロイ確認
kubectl get pods
kubectl get services

# 5. ヘルスチェック
timeout 60 bash -c 'until curl -f http://localhost:30080/health; do sleep 2; done'
timeout 60 bash -c 'until curl -f http://localhost:30081; do sleep 2; done'

# 6. クリーンアップ
helm uninstall ccplant-test
```

### トラブルシューティングコマンド

```bash
# Pod の詳細確認
kubectl describe pod -l app.kubernetes.io/instance=ccplant-test

# Pod ログの確認
kubectl logs -l app.kubernetes.io/instance=ccplant-test --all-containers=true

# イベントの確認
kubectl get events --sort-by='.lastTimestamp'

# Service の確認
kubectl get svc
kubectl describe svc ccplant-test-agentapi-proxy
kubectl describe svc ccplant-test-agentapi-ui
```

### CI での実行

`.github/workflows/integration-test-helm.yml` で自動実行されます:

```yaml
# 実行内容
1. k3s のセットアップ
2. Helm 依存関係の更新
3. NodePort を使用したデプロイ
4. ヘルスチェック待機
5. E2E テスト実行 (Playwright)
6. ログ収集
7. クリーンアップ
```

## E2E テスト (Playwright)

### 概要

Playwright を使用したブラウザベースのエンドツーエンドテストです。

### ローカルでの実行

#### 前提条件

```bash
# Node.js と npm がインストールされていること
node --version
npm --version

# Playwright のインストール
npm install -g @playwright/test
npx playwright install --with-deps chromium
```

#### Docker Compose 環境でのテスト

```bash
# 1. サービスを起動
docker compose up -d

# 2. サービスが起動するまで待機
timeout 60 bash -c 'until curl -f http://localhost:8080/health; do sleep 2; done'
timeout 60 bash -c 'until curl -f http://localhost:3000; do sleep 2; done'

# 3. Playwright 設定ファイルを作成
cat > playwright.config.ts <<'EOF'
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
EOF

# 4. テストファイルを作成
mkdir -p e2e
cat > e2e/basic.spec.ts <<'EOF'
import { test, expect } from '@playwright/test';

test('homepage loads successfully', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle(/AgentAPI/);
});

test('can access chat interface', async ({ page }) => {
  await page.goto('/');
  await page.waitForLoadState('networkidle');

  const chatInterface = page.locator('[data-testid="chat-interface"], .chat-interface, main');
  await expect(chatInterface).toBeVisible({ timeout: 10000 });
});

test('backend API is accessible', async ({ page }) => {
  let response = await page.request.get('http://localhost:8080/health');
  if (!response.ok()) {
    response = await page.request.get('http://localhost:8080/');
  }
  expect(response.ok()).toBeTruthy();
});
EOF

# 5. テストを実行
npx playwright test

# 6. レポートを表示
npx playwright show-report
```

#### Kubernetes 環境でのテスト

```bash
# NodePort 経由でアクセスするテスト
cat > playwright.config.ts <<'EOF'
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  use: {
    baseURL: 'http://localhost:30081',  # Frontend NodePort
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
EOF

# テストを実行
npx playwright test
```

### テストケースの追加

```typescript
// e2e/advanced.spec.ts
import { test, expect } from '@playwright/test';

test.describe('ccplant E2E Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('navigation works correctly', async ({ page }) => {
    // ナビゲーションリンクをクリック
    await page.click('a[href="/sessions"]');
    await expect(page).toHaveURL(/.*sessions/);
  });

  test('session creation flow', async ({ page }) => {
    // セッション作成ボタンをクリック
    await page.click('button:has-text("New Session")');

    // セッション名を入力
    await page.fill('input[name="session-name"]', 'test-session');

    // 作成ボタンをクリック
    await page.click('button:has-text("Create")');

    // 成功メッセージを確認
    await expect(page.locator('.success-message')).toBeVisible();
  });

  test('error handling', async ({ page }) => {
    // 無効な操作を試行
    await page.click('button:has-text("Delete")');

    // エラーメッセージが表示されることを確認
    await expect(page.locator('.error-message')).toBeVisible();
  });
});
```

### Playwright のベストプラクティス

```typescript
// 1. 適切な待機を使用
await page.waitForLoadState('networkidle');
await page.waitForSelector('.element', { state: 'visible' });

// 2. タイムアウトを適切に設定
await expect(element).toBeVisible({ timeout: 10000 });

// 3. エラーハンドリング
try {
  await page.click('.button');
} catch (error) {
  console.error('Button click failed:', error);
  throw error;
}

// 4. スクリーンショットの活用
await page.screenshot({ path: 'screenshot.png' });
```

## テストカバレッジ

### 現在のカバレッジ

| コンポーネント | テストの種類 | カバレッジ |
|--------------|-------------|-----------|
| Helm チャート | テンプレート検証 | 100% |
| Docker Compose | 統合テスト | 基本フロー |
| Kubernetes | 統合テスト | 基本フロー |
| Frontend | E2E テスト | 主要フロー |
| Backend API | E2E テスト | ヘルスチェック |

### カバレッジの確認

```bash
# テスト実行状況の確認
echo "Helm テンプレート検証"
cd charts/ccplant && helm template ccplant . > /tmp/test.yaml && echo "✅ Pass" || echo "❌ Fail"

echo "Docker Compose 統合テスト"
docker compose up -d && curl -f http://localhost:8080/health && curl -f http://localhost:3000 && echo "✅ Pass" || echo "❌ Fail"
docker compose down -v

echo "Playwright E2E テスト"
npx playwright test && echo "✅ Pass" || echo "❌ Fail"
```

## CI/CD でのテスト

### GitHub Actions ワークフロー

プロジェクトには 3 つの主要なテストワークフローがあります:

#### 1. Helm Template Validation

```yaml
# .github/workflows/helm-template-validation.yml
トリガー: PR / main へのプッシュ (charts/ccplant/** の変更時)
実行内容:
  - Helm 依存関係の更新
  - テンプレート生成
  - 期待値との比較
実行時間: ~1分
```

#### 2. Integration Test (Docker Compose)

```yaml
# .github/workflows/integration-test.yml
トリガー: PR / main へのプッシュ
実行内容:
  - Docker Compose でサービス起動
  - ヘルスチェック
  - Playwright E2E テスト
  - ログ収集
実行時間: ~5分
```

#### 3. Integration Test (Helm/k3s)

```yaml
# .github/workflows/integration-test-helm.yml
トリガー: PR / main へのプッシュ
実行内容:
  - k3s のセットアップ
  - Helm デプロイ
  - ヘルスチェック
  - Playwright E2E テスト
  - ログ収集
実行時間: ~10分
```

### CI でのテスト実行確認

```bash
# GitHub CLI を使用して CI 状態を確認
gh pr checks

# ワークフロー実行状況を確認
gh run list --workflow=helm-template-validation.yml
gh run list --workflow=integration-test.yml
gh run list --workflow=integration-test-helm.yml

# 特定のワークフロー実行のログを表示
gh run view <run-id> --log
```

## トラブルシューティング

### Helm テンプレート検証の失敗

```bash
# 問題: 期待値との差分が発生
# 対処: 差分を確認して、意図的な変更かバグかを判断

# 差分を詳細に確認
diff -u testdata/expected.yaml /tmp/actual.yaml | less

# 意図的な変更の場合は期待値を更新
cd charts/ccplant
helm template ccplant . --namespace default > ../../testdata/expected.yaml
git add testdata/expected.yaml
git commit -m "test: update expected Helm template output"
```

### Docker Compose テストの失敗

```bash
# 問題: サービスが起動しない
# 対処: ログを確認

docker compose logs backend
docker compose logs frontend

# ポート競合の確認
sudo lsof -i :8080
sudo lsof -i :3000

# イメージの再取得
docker compose pull
docker compose up -d --force-recreate
```

### Kubernetes テストの失敗

```bash
# 問題: Pod が起動しない
# 対処: Pod の詳細を確認

kubectl describe pod -l app.kubernetes.io/instance=ccplant-test
kubectl logs -l app.kubernetes.io/instance=ccplant-test

# イメージの問題
kubectl get pods -o jsonpath='{.items[*].status.containerStatuses[*].state}'

# リソース不足
kubectl top nodes
kubectl describe node
```

### Playwright テストの失敗

```bash
# 問題: テストがタイムアウト
# 対処: サービスの起動を確認

# Backend の確認
curl -v http://localhost:8080/health

# Frontend の確認
curl -v http://localhost:3000

# ブラウザをデバッグモードで起動
npx playwright test --debug

# スクリーンショットを撮影
npx playwright test --screenshot=on

# トレースを記録
npx playwright test --trace=on
```

### CI テストの失敗

```bash
# GitHub Actions のログを確認
gh run view <run-id> --log

# 特定のステップのログを確認
gh run view <run-id> --log | grep "Run Playwright tests"

# アーティファクトをダウンロード
gh run download <run-id>

# ローカルで同じ条件を再現
# (CI と同じコマンドをローカルで実行)
```

## ベストプラクティス

### 1. テストの独立性

```bash
# 各テストは独立して実行可能であること
# テスト前にクリーンアップ
docker compose down -v
helm uninstall ccplant-test || true

# テスト実行
# ...

# テスト後にクリーンアップ
docker compose down -v
helm uninstall ccplant-test || true
```

### 2. 適切な待機

```bash
# ポーリングによる待機
timeout 120 bash -c 'until curl -f http://localhost:8080/health; do sleep 2; done'

# Kubernetes リソースの待機
kubectl wait --for=condition=ready pod -l app=ccplant --timeout=300s
```

### 3. 詳細なログ出力

```bash
# テスト失敗時にログを収集
if ! curl -f http://localhost:8080/health; then
  echo "=== Backend Logs ==="
  docker compose logs backend
  exit 1
fi
```

### 4. リトライロジック

```typescript
// Playwright でのリトライ
export default defineConfig({
  retries: process.env.CI ? 2 : 0,
});
```

## 次のステップ

- [コントリビューションガイド](./contributing.md) - プルリクエストの作成
- [CI/CD ガイド](./ci-cd.md) - CI/CD パイプラインの詳細
- [開発環境セットアップ](./setup.md) - 環境構築

## 参考リンク

- [Playwright Documentation](https://playwright.dev/)
- [Helm Testing](https://helm.sh/docs/topics/chart_tests/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [k3s Documentation](https://docs.k3s.io/)
