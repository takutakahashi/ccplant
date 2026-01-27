# ローカル開発環境セットアップ

ccplant プロジェクトのローカル開発環境をセットアップするための完全ガイドです。

## 目次

- [前提条件](#前提条件)
- [必要なツールのインストール](#必要なツールのインストール)
- [リポジトリのクローン](#リポジトリのクローン)
- [開発環境の構成](#開発環境の構成)
- [Docker Compose での起動](#docker-compose-での起動)
- [Helm チャート開発](#helm-チャート開発)
- [トラブルシューティング](#トラブルシューティング)

## 前提条件

### システム要件

- **OS**: Linux、macOS、または Windows (WSL2)
- **CPU**: 2 コア以上
- **メモリ**: 4GB 以上 (8GB 推奨)
- **ストレージ**: 10GB 以上の空き容量

### 必要なスキルセット

- 基本的な Git 操作の知識
- Docker と Docker Compose の基本的な理解
- Kubernetes と Helm の基本的な知識
- YAML ファイルの編集経験

## 必要なツールのインストール

### 1. mise のインストール

mise はプロジェクトごとのツールバージョン管理ツールです。Helm などの開発ツールの管理に使用します。

```bash
# Linux / macOS
curl https://mise.run | sh

# mise を PATH に追加
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc  # bash の場合
echo 'eval "$(~/.local/bin/mise activate zsh)"' >> ~/.zshrc   # zsh の場合

# シェルを再起動
source ~/.bashrc  # または source ~/.zshrc

# インストール確認
mise --version
```

### 2. Docker のインストール

```bash
# Ubuntu / Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# macOS
# Docker Desktop for Mac をインストール
# https://docs.docker.com/desktop/install/mac-install/

# インストール確認
docker --version
docker compose version
```

### 3. Helm のインストール (mise 経由)

```bash
# プロジェクトディレクトリで mise を使用
cd /path/to/ccplant
mise install

# インストール確認
mise which helm
helm version
```

または、手動でインストール:

```bash
# Linux / macOS
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# インストール確認
helm version
```

### 4. kubectl のインストール (オプション)

Kubernetes クラスターでテストする場合に必要です。

```bash
# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# macOS
brew install kubectl

# インストール確認
kubectl version --client
```

### 5. k3s のインストール (オプション)

ローカル Kubernetes クラスターでテストする場合に使用します。

```bash
# Linux のみ
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

# クラスター確認
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
```

## リポジトリのクローン

### 1. GitHub からクローン

```bash
# HTTPS でクローン
git clone https://github.com/takutakahashi/ccplant.git
cd ccplant

# または SSH でクローン
git clone git@github.com:takutakahashi/ccplant.git
cd ccplant
```

### 2. ブランチ構成の確認

```bash
# リモートブランチの確認
git branch -r

# ローカルブランチの作成
git checkout -b feature/my-feature

# 最新の main ブランチに同期
git fetch origin
git merge origin/main
```

## 開発環境の構成

### 1. プロジェクト構造の理解

```
ccplant/
├── .github/
│   └── workflows/        # CI/CD ワークフロー
├── charts/
│   └── ccplant/         # Helm チャート
│       ├── Chart.yaml   # チャートメタデータ
│       ├── values.yaml  # デフォルト設定値
│       └── charts/      # 依存チャート (agentapi-proxy, agentapi-ui)
├── docs/                # ドキュメント
├── scripts/             # ユーティリティスクリプト
├── testdata/            # テストデータ
├── docker-compose.yaml  # Docker Compose 設定
└── mise.toml           # mise ツール設定
```

### 2. mise ツールのセットアップ

```bash
# プロジェクトディレクトリに移動
cd ccplant

# mise.toml に記載されたツールをインストール
mise install

# インストールされたツールの確認
mise list

# 出力例:
# helm    3.18.3  ~/.local/share/mise/installs/helm/3.18.3
```

### 3. Helm 依存関係の更新

```bash
# Helm チャートディレクトリに移動
cd charts/ccplant

# GitHub Container Registry にログイン
echo $GITHUB_TOKEN | helm registry login ghcr.io --username YOUR_USERNAME --password-stdin

# 依存チャートを更新
helm dependency update

# 依存関係の確認
ls -la charts/
# agentapi-proxy-v1.191.0.tgz
# agentapi-ui-v1.97.0.tgz
```

## Docker Compose での起動

Docker Compose を使用した最も簡単な開発環境の起動方法です。

### 1. 基本的な起動

```bash
# プロジェクトルートディレクトリで実行
cd /path/to/ccplant

# サービスをバックグラウンドで起動
docker compose up -d

# ログを確認
docker compose logs -f

# サービスの状態確認
docker compose ps
```

### 2. サービスの動作確認

```bash
# Backend のヘルスチェック
curl http://localhost:8080/health

# Frontend のアクセス確認
curl http://localhost:3000/

# ブラウザでアクセス
open http://localhost:3000
```

### 3. 開発中のリビルドと再起動

```bash
# サービスを停止せずに再起動
docker compose restart backend
docker compose restart frontend

# サービスを停止
docker compose down

# イメージを再ビルドして起動
docker compose up -d --build

# すべて削除して再起動 (ボリュームも削除)
docker compose down -v
docker compose up -d
```

### 4. ログの確認

```bash
# すべてのサービスのログ
docker compose logs -f

# Backend のみ
docker compose logs -f backend

# Frontend のみ
docker compose logs -f frontend

# 最新 100 行を表示
docker compose logs --tail=100 backend
```

### 5. コンテナ内でのデバッグ

```bash
# Backend コンテナに入る
docker compose exec backend sh

# Frontend コンテナに入る
docker compose exec frontend sh

# コンテナ内で
ps aux
env
curl http://localhost:8080/health
```

## Helm チャート開発

### 1. Helm テンプレートの生成

```bash
cd charts/ccplant

# テンプレートをレンダリング
helm template ccplant . --namespace default > output.yaml

# 特定の値ファイルを使用
helm template ccplant . -f custom-values.yaml > output.yaml

# 出力を確認
cat output.yaml
```

### 2. テンプレートの検証

```bash
# Helm チャートの構文チェック
helm lint .

# 依存関係の確認
helm dependency list

# チャートのパッケージング (テスト用)
helm package .
```

### 3. ローカル Kubernetes でのテスト

k3s を使用した場合:

```bash
# k3s の設定
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# 依存関係を更新
cd charts/ccplant
helm dependency update

# インストール
helm install ccplant-dev . \
  --namespace ccplant-dev \
  --create-namespace \
  --set global.hostname=ccplant.local \
  --set global.apiHostname=api.ccplant.local

# デプロイ状態の確認
kubectl get pods -n ccplant-dev
kubectl get svc -n ccplant-dev

# ログ確認
kubectl logs -f -n ccplant-dev -l app.kubernetes.io/name=agentapi-proxy

# アンインストール
helm uninstall ccplant-dev -n ccplant-dev
```

### 4. values.yaml のカスタマイズ

開発用の values ファイルを作成:

```bash
# values-dev.yaml を作成
cat > values-dev.yaml <<EOF
global:
  hostname: ccplant.local
  apiHostname: api.ccplant.local

  github:
    oauth:
      clientId: "dev-client-id"
      clientSecret: "dev-client-secret"

agentapi-ui:
  config:
    authMode: oauth_only
    loginTitle: "ccplant Dev"
    loginDescription: "Development Environment"

agentapi-proxy:
  config:
    auth:
      enabled: false  # 開発時は認証無効化
EOF

# カスタム values でインストール
helm install ccplant-dev . -f values-dev.yaml
```

### 5. Helm チャートのテスト

```bash
# ドライラン (実際にはインストールしない)
helm install ccplant-test . --dry-run --debug

# テンプレート出力を期待値と比較
helm template ccplant . > /tmp/actual.yaml
diff -u testdata/expected.yaml /tmp/actual.yaml

# チャートのパッケージング
helm package .

# パッケージの検証
helm install ccplant-test ./ccplant-0.1.0.tgz --dry-run
```

## 開発ワークフロー

### 1. 機能開発の基本フロー

```bash
# 1. 最新の main ブランチから作業ブランチを作成
git checkout main
git pull origin main
git checkout -b feature/my-new-feature

# 2. Helm チャートを編集
vim charts/ccplant/values.yaml

# 3. テンプレートを検証
cd charts/ccplant
helm lint .
helm template ccplant . > /tmp/output.yaml

# 4. Docker Compose でテスト
cd ../..
docker compose down
docker compose up -d

# 5. 期待値を更新 (必要な場合)
cd charts/ccplant
helm template ccplant . --namespace default > ../../testdata/expected.yaml

# 6. コミット
git add .
git commit -m "feat: add new feature"

# 7. プッシュ
git push origin feature/my-new-feature
```

### 2. ブランチ戦略

- **main**: 本番リリース用の安定ブランチ
- **feature/**: 新機能開発
- **fix/**: バグ修正
- **docs/**: ドキュメント更新
- **test/**: テスト追加・改善

### 3. コミットメッセージ規約

```bash
# 機能追加
git commit -m "feat: add support for custom ingress annotations"

# バグ修正
git commit -m "fix: resolve health check timeout issue"

# ドキュメント
git commit -m "docs: update setup guide"

# テスト
git commit -m "test: add integration tests for helm chart"

# リファクタリング
git commit -m "refactor: simplify values structure"

# CI/CD
git commit -m "ci: update helm-template-validation workflow"
```

## トラブルシューティング

### Docker Compose の問題

#### サービスが起動しない

```bash
# ログを確認
docker compose logs backend
docker compose logs frontend

# コンテナの状態確認
docker compose ps -a

# イメージを再取得
docker compose pull
docker compose up -d

# ネットワークをリセット
docker compose down
docker network prune -f
docker compose up -d
```

#### ポートが既に使用されている

```bash
# ポート使用状況を確認
sudo lsof -i :8080
sudo lsof -i :3000

# プロセスを停止
sudo kill -9 <PID>

# または、docker-compose.yaml でポートを変更
ports:
  - "8081:8080"  # 8080 → 8081
```

### Helm の問題

#### 依存関係の更新が失敗する

```bash
# キャッシュをクリア
rm -rf charts/ccplant/charts/
rm -f charts/ccplant/Chart.lock

# GitHub Container Registry に再ログイン
echo $GITHUB_TOKEN | helm registry login ghcr.io --username YOUR_USERNAME --password-stdin

# 依存関係を再取得
helm dependency update

# デバッグモードで実行
helm dependency update --debug
```

#### テンプレートレンダリングが失敗する

```bash
# values.yaml の構文チェック
yamllint values.yaml

# デバッグモードでレンダリング
helm template ccplant . --debug

# 特定の values を指定して検証
helm template ccplant . --set global.hostname=test.local
```

### mise の問題

#### ツールがインストールされない

```bash
# mise の診断
mise doctor

# 手動でツールをインストール
mise install helm@latest

# PATH を確認
echo $PATH
mise which helm
```

### k3s の問題

#### クラスターに接続できない

```bash
# k3s のステータス確認
sudo systemctl status k3s

# kubeconfig のパーミッション確認
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

# kubeconfig を設定
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
```

## 次のステップ

- [テストガイド](./testing.md) - テストの実行方法
- [コントリビューションガイド](./contributing.md) - プルリクエストの作成方法
- [CI/CD ガイド](./ci-cd.md) - CI/CD パイプラインの理解

## 参考リンク

- [Docker Documentation](https://docs.docker.com/)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [mise Documentation](https://mise.jdx.dev/)
