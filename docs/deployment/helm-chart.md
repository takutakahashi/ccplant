# Helm Chart デプロイガイド

Helm を使用して ccplant を Kubernetes クラスターにデプロイする詳細ガイドです。Helm チャートの設定、カスタマイズ、運用管理について説明します。

## 目次

- [概要](#概要)
- [前提条件](#前提条件)
- [Helm のインストール](#helm-のインストール)
- [基本的なインストール](#基本的なインストール)
- [OCI レジストリからのインストール](#oci-レジストリからのインストール)
- [values.yaml の設定](#valuesyaml-の設定)
- [依存関係の管理](#依存関係の管理)
- [アップグレード手順](#アップグレード手順)
- [ロールバック手順](#ロールバック手順)
- [アンインストール](#アンインストール)
- [カスタマイズ](#カスタマイズ)
- [トラブルシューティング](#トラブルシューティング)

## 概要

ccplant の Helm チャートは、以下の特徴を持ちます:

- **シンプルなデプロイ**: 1 コマンドで完全なスタックをデプロイ
- **依存関係の管理**: agentapi-proxy と agentapi-ui を自動的にインストール
- **設定の一元管理**: values.yaml で全ての設定を管理
- **アップグレードとロールバック**: 簡単なバージョン管理
- **本番環境対応**: 高可用性とセキュリティの設定をサポート

### Helm チャート情報

- **チャート名**: ccplant
- **現在のバージョン**: v0.4.0
- **レジストリ**: oci://ghcr.io/takutakahashi/charts/ccplant
- **リポジトリ**: https://github.com/takutakahashi/ccplant

### 依存関係

ccplant チャートは以下のサブチャートに依存しています:

| 依存チャート | バージョン | レジストリ | 説明 |
|------------|----------|----------|------|
| agentapi-proxy | v1.191.0 | oci://ghcr.io/takutakahashi/charts | バックエンド API サーバー |
| agentapi-ui | v1.97.0 | oci://ghcr.io/takutakahashi/charts | フロントエンド Web UI |

## 前提条件

### システム要件

- **Kubernetes**: v1.19 以上
- **Helm**: v3.14.0 以上
- **kubectl**: Kubernetes クラスターに接続可能な状態

### クラスターコンポーネント

以下のコンポーネントがクラスターにインストールされている必要があります:

1. **Ingress Controller** (nginx-ingress 推奨)
2. **cert-manager** (TLS を使用する場合)
3. **適切な StorageClass** (永続ボリュームを使用する場合)

### 必要な情報

- GitHub OAuth App の Client ID と Client Secret
- GitHub App の App ID と Private Key
- 使用するドメイン名

## Helm のインストール

### Helm v3 のインストール

```bash
# Linux の場合
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# macOS の場合
brew install helm

# インストール確認
helm version
```

### Helm の基本設定

```bash
# 補完機能の有効化 (Bash)
helm completion bash > /etc/bash_completion.d/helm

# 補完機能の有効化 (Zsh)
helm completion zsh > "${fpath[1]}/_helm"

# Helm プラグインのインストール (オプション)
helm plugin install https://github.com/databus23/helm-diff
```

## 基本的なインストール

### 1. Namespace の作成

```bash
# ccplant 用の Namespace を作成
kubectl create namespace ccplant
```

### 2. Secret の作成

#### GitHub App の Secret

```bash
# GitHub App の秘密鍵から Secret を作成
kubectl create secret generic github-app \
  --from-file=private-key=/path/to/your/github-app-private-key.pem \
  --namespace=ccplant
```

#### Cookie 暗号化 Secret

```bash
# ランダムな文字列を生成
ENCRYPTION_SECRET=$(openssl rand -base64 32)

# Secret を作成
kubectl create secret generic agentapi-ui-encryption \
  --from-literal=cookie-encryption-secret=$ENCRYPTION_SECRET \
  --namespace=ccplant
```

### 3. 最小構成でのインストール

```bash
helm install ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version v0.4.0 \
  --namespace ccplant \
  --set global.hostname=cc.example.com \
  --set global.apiHostname=cc-api.example.com \
  --set global.github.oauth.clientId=YOUR_GITHUB_OAUTH_CLIENT_ID \
  --set global.github.oauth.clientSecret=YOUR_GITHUB_OAUTH_CLIENT_SECRET \
  --set agentapi-proxy.github.app.id=YOUR_GITHUB_APP_ID
```

### 4. インストールの確認

```bash
# リリースの確認
helm list -n ccplant

# Pod の確認
kubectl get pods -n ccplant

# すべてのリソースを確認
kubectl get all -n ccplant

# リリースの詳細
helm status ccplant -n ccplant
```

## OCI レジストリからのインストール

ccplant の Helm チャートは GitHub Container Registry (GHCR) の OCI レジストリで公開されています。

### OCI レジストリの利点

- **セキュリティ**: コンテナイメージと同じレジストリで管理
- **バージョン管理**: タグベースのバージョン管理
- **認証**: GitHub の認証機構を利用
- **スピード**: 高速なダウンロード

### 公開チャートのインストール

```bash
# 最新バージョンをインストール
helm install ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --namespace ccplant \
  --create-namespace \
  --values values.yaml

# 特定のバージョンをインストール
helm install ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version v0.4.0 \
  --namespace ccplant \
  --values values.yaml
```

### プライベートレジストリの認証

プライベートな OCI レジストリを使用する場合:

```bash
# GitHub の Personal Access Token でログイン
echo $GITHUB_TOKEN | helm registry login ghcr.io \
  --username YOUR_GITHUB_USERNAME \
  --password-stdin

# インストール
helm install ccplant oci://ghcr.io/YOUR_ORG/charts/ccplant \
  --version v0.4.0 \
  --namespace ccplant \
  --values values.yaml
```

### チャートのバージョン確認

```bash
# 利用可能なバージョンを確認 (Helm 3.8+)
helm show chart oci://ghcr.io/takutakahashi/charts/ccplant --version v0.4.0

# チャートの内容を確認
helm show all oci://ghcr.io/takutakahashi/charts/ccplant --version v0.4.0

# デフォルトの values.yaml を確認
helm show values oci://ghcr.io/takutakahashi/charts/ccplant --version v0.4.0
```

## values.yaml の設定

### 基本的な values.yaml

```yaml
# values.yaml
# =============================================================================
# グローバル設定
# =============================================================================
global:
  # ホスト名設定
  hostname: cc.example.com        # フロントエンドのドメイン
  apiHostname: cc-api.example.com # バックエンド API のドメイン

  # GitHub OAuth 設定
  github:
    enterprise:
      enabled: false                # GitHub Enterprise を使用する場合は true
      baseUrl: ""                   # GitHub Enterprise の URL
    oauth:
      clientId: "your_oauth_client_id"
      clientSecret: "your_oauth_client_secret"

  # Ingress 設定
  ingress:
    className: nginx                # Ingress Controller のクラス名
    tls:
      enabled: true                 # TLS/HTTPS を有効化

# =============================================================================
# agentapi-ui (Frontend) 設定
# =============================================================================
agentapi-ui:
  # レプリカ数
  replicaCount: 2

  # UI 設定
  config:
    authMode: oauth_only
    loginTitle: ccplant
    loginDescription: Welcome to ccplant
    loginSubDescription: AI Agent Plant

  # Cookie 暗号化設定
  cookieEncryptionSecret:
    enabled: true
    secretName: agentapi-ui-encryption
    secretKey: cookie-encryption-secret

  # Ingress 設定
  ingress:
    enabled: true
    annotations: {}

  # リソース設定
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 256Mi

# =============================================================================
# agentapi-proxy (Backend API) 設定
# =============================================================================
agentapi-proxy:
  # レプリカ数
  replicaCount: 2

  # GitHub App 設定
  github:
    app:
      id: "123456"                  # GitHub App ID
      privateKey:
        secretName: github-app
        key: private-key

  # 認証設定
  authConfig:
    github:
      user_mapping:
        default_role: user
        default_permissions:
          - session:create
          - session:list
          - session:delete
          - session:access
        team_role_mapping: {}       # チームベースのロールマッピング

  # 認証有効化
  config:
    auth:
      enabled: true
      github:
        enabled: true

  # Ingress 設定
  ingress:
    enabled: true
    annotations: {}

  # Kubernetes セッション設定
  kubernetesSession:
    enabled: true
    nodeSelector: {}
    tolerations: []
    pvc:
      enabled: false                # 永続ボリュームを使用する場合は true

  # リソース設定
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

  # Node Selector
  nodeSelector: {}

  # Tolerations
  tolerations: []
```

### 本番環境用の values.yaml

```yaml
# values-production.yaml
global:
  hostname: cc.example.com
  apiHostname: cc-api.example.com

  github:
    oauth:
      clientId: "prod_oauth_client_id"
      clientSecret: "prod_oauth_client_secret"

  ingress:
    className: nginx
    tls:
      enabled: true

agentapi-ui:
  replicaCount: 3  # 高可用性のため 3 レプリカ

  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

  # HPA 設定
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80

  # Pod Disruption Budget
  podDisruptionBudget:
    enabled: true
    minAvailable: 2

agentapi-proxy:
  replicaCount: 3  # 高可用性のため 3 レプリカ

  github:
    app:
      id: "123456"
      privateKey:
        secretName: github-app
        key: private-key

  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi

  # HPA 設定
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80

  # Pod Disruption Budget
  podDisruptionBudget:
    enabled: true
    minAvailable: 2

  # Kubernetes セッション設定
  kubernetesSession:
    enabled: true
    nodeSelector:
      workload: sessions
    pvc:
      enabled: true
      storageClass: fast-ssd
      size: 10Gi
```

### インストール時の values.yaml の使用

```bash
# values.yaml を使用してインストール
helm install ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version v0.4.0 \
  --namespace ccplant \
  --values values.yaml

# 複数の values ファイルを使用
helm install ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version v0.4.0 \
  --namespace ccplant \
  --values values.yaml \
  --values values-production.yaml

# values ファイルとコマンドラインオプションを組み合わせ
helm install ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version v0.4.0 \
  --namespace ccplant \
  --values values.yaml \
  --set agentapi-proxy.replicaCount=5
```

## 依存関係の管理

### 依存関係の確認

```bash
# チャートの依存関係を表示
helm show chart oci://ghcr.io/takutakahashi/charts/ccplant --version v0.4.0

# 出力例:
# dependencies:
#   - name: agentapi-proxy
#     version: "v1.191.0"
#     repository: "oci://ghcr.io/takutakahashi/charts"
#   - name: agentapi-ui
#     version: "v1.97.0"
#     repository: "oci://ghcr.io/takutakahashi/charts"
```

### 依存関係のバージョン指定

Chart.yaml で依存関係のバージョンを管理:

```yaml
# Chart.yaml
apiVersion: v2
name: ccplant
version: 0.4.0

dependencies:
  - name: agentapi-proxy
    version: "v1.191.0"
    repository: "oci://ghcr.io/takutakahashi/charts"
  - name: agentapi-ui
    version: "v1.97.0"
    repository: "oci://ghcr.io/takutakahashi/charts"
```

### サブチャートの設定上書き

values.yaml でサブチャートの設定を上書き:

```yaml
# agentapi-proxy の設定を上書き
agentapi-proxy:
  replicaCount: 3
  resources:
    limits:
      memory: 1Gi

# agentapi-ui の設定を上書き
agentapi-ui:
  replicaCount: 2
  config:
    loginTitle: "My Custom Title"
```

## アップグレード手順

### 1. 現在のバージョン確認

```bash
# インストール済みのリリースを確認
helm list -n ccplant

# リリースの詳細を確認
helm status ccplant -n ccplant

# 現在の設定値を確認
helm get values ccplant -n ccplant
```

### 2. 新しいバージョンへのアップグレード

```bash
# 最新バージョンにアップグレード
helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --namespace ccplant \
  --values values.yaml

# 特定のバージョンにアップグレード
helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version v0.5.0 \
  --namespace ccplant \
  --values values.yaml

# 既存の値を再利用
helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version v0.5.0 \
  --namespace ccplant \
  --reuse-values
```

### 3. アップグレードのオプション

```bash
# ドライランでアップグレードを確認
helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version v0.5.0 \
  --namespace ccplant \
  --values values.yaml \
  --dry-run --debug

# 変更内容を確認 (helm-diff プラグイン)
helm diff upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version v0.5.0 \
  --namespace ccplant \
  --values values.yaml

# アップグレードをインタラクティブに実行
helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version v0.5.0 \
  --namespace ccplant \
  --values values.yaml \
  --wait \
  --timeout 10m

# アップグレード失敗時に自動ロールバック
helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version v0.5.0 \
  --namespace ccplant \
  --values values.yaml \
  --atomic \
  --timeout 10m
```

### 4. アップグレードの監視

```bash
# アップグレード状態の確認
helm status ccplant -n ccplant

# リリース履歴の確認
helm history ccplant -n ccplant

# Pod の状態を監視
kubectl get pods -n ccplant --watch

# ローリングアップデートの状態
kubectl rollout status deployment/ccplant-agentapi-proxy -n ccplant
kubectl rollout status deployment/ccplant-agentapi-ui -n ccplant
```

### 5. 依存関係のアップグレード

サブチャートのバージョンもアップグレード:

```bash
# 依存関係を含めてアップグレード
helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version v0.5.0 \
  --namespace ccplant \
  --values values.yaml

# 特定のサブチャートの設定を上書き
helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version v0.5.0 \
  --namespace ccplant \
  --values values.yaml \
  --set agentapi-proxy.image.tag=v1.192.0 \
  --set agentapi-ui.image.tag=v1.98.0
```

## ロールバック手順

### 1. ロールバック可能なリビジョンの確認

```bash
# リリース履歴の確認
helm history ccplant -n ccplant

# 出力例:
# REVISION  UPDATED                   STATUS      CHART           APP VERSION  DESCRIPTION
# 1         Mon Jan 27 10:00:00 2025  superseded  ccplant-0.3.0   1.0.0       Install complete
# 2         Mon Jan 27 11:00:00 2025  superseded  ccplant-0.4.0   1.0.0       Upgrade complete
# 3         Mon Jan 27 12:00:00 2025  deployed    ccplant-0.5.0   1.0.0       Upgrade complete
```

### 2. 直前のバージョンにロールバック

```bash
# 1 つ前のリビジョンにロールバック
helm rollback ccplant -n ccplant

# ロールバックの確認を待つ
helm rollback ccplant -n ccplant --wait

# タイムアウトを設定
helm rollback ccplant -n ccplant --wait --timeout 10m
```

### 3. 特定のリビジョンにロールバック

```bash
# 特定のリビジョン (例: revision 2) にロールバック
helm rollback ccplant 2 -n ccplant

# ロールバックをドライランで確認
helm rollback ccplant 2 -n ccplant --dry-run

# 強制ロールバック
helm rollback ccplant 2 -n ccplant --force
```

### 4. ロールバックの確認

```bash
# ロールバック後のステータス確認
helm status ccplant -n ccplant

# Pod の状態確認
kubectl get pods -n ccplant

# ロールバックが成功したか確認
helm history ccplant -n ccplant
```

## アンインストール

### 1. リリースのアンインストール

```bash
# リリースを削除
helm uninstall ccplant -n ccplant

# 削除の確認
helm list -n ccplant
kubectl get all -n ccplant
```

### 2. リソースの完全削除

```bash
# Namespace も含めて完全削除
kubectl delete namespace ccplant

# または、個別に削除
kubectl delete secret github-app -n ccplant
kubectl delete secret github-oauth -n ccplant
kubectl delete secret agentapi-ui-encryption -n ccplant
kubectl delete pvc --all -n ccplant
```

### 3. リリース履歴の保持

アンインストール後もリリース履歴を保持する場合:

```bash
# 履歴を保持してアンインストール
helm uninstall ccplant -n ccplant --keep-history

# 履歴の確認
helm history ccplant -n ccplant

# 完全削除
helm delete ccplant -n ccplant --purge
```

## カスタマイズ

### Ingress のカスタマイズ

```yaml
global:
  ingress:
    className: nginx
    tls:
      enabled: true
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
      nginx.ingress.kubernetes.io/proxy-body-size: "50m"
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/proxy-send-timeout: "600"

agentapi-proxy:
  ingress:
    enabled: true
    annotations:
      nginx.ingress.kubernetes.io/rate-limit: "100"

agentapi-ui:
  ingress:
    enabled: true
    annotations:
      nginx.ingress.kubernetes.io/configuration-snippet: |
        more_set_headers "X-Frame-Options: DENY";
        more_set_headers "X-Content-Type-Options: nosniff";
```

### リソースのカスタマイズ

```yaml
agentapi-proxy:
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi

agentapi-ui:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

### 高可用性の設定

```yaml
agentapi-proxy:
  replicaCount: 3

  # Pod Anti-Affinity
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values:
              - agentapi-proxy
          topologyKey: kubernetes.io/hostname

  # Pod Disruption Budget
  podDisruptionBudget:
    enabled: true
    minAvailable: 2

agentapi-ui:
  replicaCount: 3

  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values:
              - agentapi-ui
          topologyKey: kubernetes.io/hostname

  podDisruptionBudget:
    enabled: true
    minAvailable: 2
```

### セッション Pod のカスタマイズ

```yaml
agentapi-proxy:
  kubernetesSession:
    enabled: true

    # Node Selector
    nodeSelector:
      workload: sessions
      disktype: ssd

    # Tolerations
    tolerations:
    - key: "workload"
      operator: "Equal"
      value: "sessions"
      effect: "NoSchedule"

    # 永続ボリューム
    pvc:
      enabled: true
      storageClass: fast-ssd
      size: 20Gi
      accessModes:
      - ReadWriteOnce
```

## トラブルシューティング

### インストールに失敗する

```bash
# デバッグモードで詳細を確認
helm install ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version v0.4.0 \
  --namespace ccplant \
  --values values.yaml \
  --debug

# テンプレートの検証
helm template ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version v0.4.0 \
  --namespace ccplant \
  --values values.yaml

# ドライランで確認
helm install ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version v0.4.0 \
  --namespace ccplant \
  --values values.yaml \
  --dry-run --debug
```

### リリースが見つからない

```bash
# すべての Namespace のリリースを確認
helm list --all-namespaces

# 削除されたリリースを含めて確認
helm list -n ccplant --all

# 特定のリリースの状態確認
helm status ccplant -n ccplant
```

### アップグレードが失敗する

```bash
# 現在の状態を確認
helm status ccplant -n ccplant

# 失敗したリリースをロールバック
helm rollback ccplant -n ccplant

# または、強制的に前のバージョンで上書き
helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version v0.4.0 \
  --namespace ccplant \
  --values values.yaml \
  --force
```

### 依存関係の問題

```bash
# 依存関係を確認
helm show chart oci://ghcr.io/takutakahashi/charts/ccplant --version v0.4.0

# サブチャートの設定を確認
helm show values oci://ghcr.io/takutakahashi/charts/ccplant --version v0.4.0

# 依存関係を含めてテンプレートを生成
helm template ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version v0.4.0 \
  --namespace ccplant \
  --values values.yaml \
  --include-crds
```

### values.yaml の検証

```bash
# values.yaml の構文チェック
helm lint -f values.yaml

# テンプレートのレンダリング確認
helm template ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version v0.4.0 \
  --values values.yaml

# 実際に適用される値を確認
helm get values ccplant -n ccplant --all
```

### OCI レジストリの問題

```bash
# レジストリへの接続確認
helm show chart oci://ghcr.io/takutakahashi/charts/ccplant --version v0.4.0

# 認証が必要な場合
echo $GITHUB_TOKEN | helm registry login ghcr.io \
  --username YOUR_USERNAME \
  --password-stdin

# キャッシュをクリア
rm -rf ~/.cache/helm/registry
```

## 次のステップ

- [設定ガイド](./configuration.md) - 詳細な設定とベストプラクティス
- [Kubernetes デプロイ](./kubernetes.md) - kubectl を使用したデプロイ
- [トラブルシューティング](./troubleshooting.md) - より詳細な問題解決
- [運用ガイド](../operations/monitoring.md) - モニタリングとメンテナンス
- [セキュリティガイド](../operations/security.md) - セキュリティのベストプラクティス
