# 設定ガイド

ccplant のデプロイに関する設定のベストプラクティスと詳細な設定項目について説明します。

## 目次

- [概要](#概要)
- [グローバル設定](#グローバル設定)
- [GitHub OAuth 設定](#github-oauth-設定)
- [GitHub App 設定](#github-app-設定)
- [Ingress と TLS の設定](#ingress-と-tls-の設定)
- [リソース設定](#リソース設定)
- [認証と認可の設定](#認証と認可の設定)
- [セッション管理の設定](#セッション管理の設定)
- [高可用性の設定](#高可用性の設定)
- [環境別設定](#環境別設定)
- [本番環境準備チェックリスト](#本番環境準備チェックリスト)

## 概要

ccplant の設定は、デプロイ方法によって異なる方法で管理されます:

- **Docker Compose**: 環境変数と `.env` ファイル
- **Kubernetes (kubectl)**: ConfigMap と Secret
- **Helm**: `values.yaml` ファイル

このガイドでは、主に Helm を使用した設定について説明しますが、概念は他のデプロイ方法にも適用できます。

### 設定の優先順位

Helm を使用する場合、以下の優先順位で設定が適用されます:

1. `--set` コマンドラインオプション (最優先)
2. `-f` または `--values` で指定した values ファイル
3. サブチャートのデフォルト値
4. 親チャートのデフォルト値

## グローバル設定

グローバル設定は、すべてのサブチャートに適用される共通の設定です。

### hostname と apiHostname

フロントエンドとバックエンドのドメイン名を設定します。

```yaml
global:
  hostname: cc.example.com        # フロントエンド UI のドメイン
  apiHostname: cc-api.example.com # バックエンド API のドメイン
```

**ベストプラクティス**:
- 本番環境では、実際の FQDN を使用
- 開発環境では、`localhost` や内部ドメインも使用可能
- サブドメインを使用してフロントエンドと API を分離することを推奨

**例**:
```yaml
# 本番環境
global:
  hostname: ccplant.company.com
  apiHostname: api.ccplant.company.com

# 開発環境
global:
  hostname: ccplant-dev.local
  apiHostname: api.ccplant-dev.local

# ステージング環境
global:
  hostname: ccplant-staging.company.com
  apiHostname: api.ccplant-staging.company.com
```

### GitHub Enterprise の設定

GitHub Enterprise Server を使用する場合の設定です。

```yaml
global:
  github:
    enterprise:
      enabled: true
      baseUrl: "https://github.company.com"
```

**設定項目**:
- `enabled`: GitHub Enterprise を使用する場合は `true`
- `baseUrl`: GitHub Enterprise Server の URL (デフォルト: `https://github.com`)

## GitHub OAuth 設定

GitHub OAuth を使用したユーザー認証の設定です。

### OAuth App の作成

1. GitHub にログインして、Settings → Developer settings → OAuth Apps に移動
2. "New OAuth App" をクリック
3. 以下の情報を入力:
   - **Application name**: `ccplant`
   - **Homepage URL**: `https://cc.example.com`
   - **Authorization callback URL**: `https://cc.example.com/api/auth/callback/github`
4. Client ID と Client Secret をメモ

### values.yaml での設定

```yaml
global:
  github:
    oauth:
      clientId: "your_oauth_client_id"
      clientSecret: "your_oauth_client_secret"
```

**セキュリティのベストプラクティス**:

Secret を使用して OAuth 認証情報を管理することを推奨します:

```bash
# Secret の作成
kubectl create secret generic github-oauth \
  --from-literal=client-id=YOUR_CLIENT_ID \
  --from-literal=client-secret=YOUR_CLIENT_SECRET \
  -n ccplant
```

```yaml
# values.yaml で Secret を参照
agentapi-ui:
  env:
  - name: GITHUB_CLIENT_ID
    valueFrom:
      secretKeyRef:
        name: github-oauth
        key: client-id
  - name: GITHUB_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: github-oauth
        key: client-secret
```

### 環境別の OAuth App

環境ごとに異なる OAuth App を使用することを推奨します:

```yaml
# values-dev.yaml
global:
  github:
    oauth:
      clientId: "dev_oauth_client_id"
      clientSecret: "dev_oauth_client_secret"

# values-staging.yaml
global:
  github:
    oauth:
      clientId: "staging_oauth_client_id"
      clientSecret: "staging_oauth_client_secret"

# values-prod.yaml
global:
  github:
    oauth:
      clientId: "prod_oauth_client_id"
      clientSecret: "prod_oauth_client_secret"
```

## GitHub App 設定

GitHub App を使用して、リポジトリへのアクセスやイベントの受信を行います。

### GitHub App の作成

1. GitHub にログインして、Settings → Developer settings → GitHub Apps に移動
2. "New GitHub App" をクリック
3. 以下の情報を入力:
   - **GitHub App name**: `ccplant`
   - **Homepage URL**: `https://cc.example.com`
   - **Webhook URL**: `https://cc-api.example.com/webhooks/github`
   - **Webhook secret**: ランダムな文字列を生成 (`openssl rand -base64 32`)
4. 必要な権限を設定:
   - **Repository permissions**:
     - Contents: Read & Write
     - Issues: Read & Write
     - Pull requests: Read & Write
     - Metadata: Read-only
   - **Organization permissions**:
     - Members: Read-only
5. "Create GitHub App" をクリック
6. App ID と Private Key をダウンロード

### values.yaml での設定

```yaml
agentapi-proxy:
  github:
    app:
      id: "123456"  # GitHub App ID
      privateKey:
        secretName: github-app
        secretKey: private-key
```

### Private Key の Secret 作成

```bash
# Private Key ファイルから Secret を作成
kubectl create secret generic github-app \
  --from-file=private-key=/path/to/github-app-private-key.pem \
  -n ccplant

# 確認
kubectl get secret github-app -n ccplant
kubectl describe secret github-app -n ccplant
```

### Webhook Secret の設定

Webhook の検証に使用する Secret:

```bash
# Webhook Secret を生成
WEBHOOK_SECRET=$(openssl rand -base64 32)

# Secret を作成
kubectl create secret generic github-webhook \
  --from-literal=webhook-secret=$WEBHOOK_SECRET \
  -n ccplant
```

```yaml
agentapi-proxy:
  github:
    webhook:
      secretName: github-webhook
      secretKey: webhook-secret
```

## Ingress と TLS の設定

### 基本的な Ingress 設定

```yaml
global:
  ingress:
    className: nginx
    tls:
      enabled: true
```

### Ingress アノテーションのカスタマイズ

```yaml
agentapi-ui:
  ingress:
    enabled: true
    annotations:
      # TLS/HTTPS 設定
      cert-manager.io/cluster-issuer: letsencrypt-prod
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"

      # セキュリティヘッダー
      nginx.ingress.kubernetes.io/configuration-snippet: |
        more_set_headers "X-Frame-Options: DENY";
        more_set_headers "X-Content-Type-Options: nosniff";
        more_set_headers "X-XSS-Protection: 1; mode=block";
        more_set_headers "Referrer-Policy: strict-origin-when-cross-origin";

agentapi-proxy:
  ingress:
    enabled: true
    annotations:
      # TLS/HTTPS 設定
      cert-manager.io/cluster-issuer: letsencrypt-prod
      nginx.ingress.kubernetes.io/ssl-redirect: "true"

      # レート制限
      nginx.ingress.kubernetes.io/rate-limit: "100"
      nginx.ingress.kubernetes.io/limit-rps: "10"

      # タイムアウト設定
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/proxy-send-timeout: "600"

      # ボディサイズ制限
      nginx.ingress.kubernetes.io/proxy-body-size: "50m"
```

### TLS 証明書の設定

#### Let's Encrypt を使用した自動証明書取得

```bash
# ClusterIssuer の作成
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

```yaml
# Ingress で証明書を自動取得
global:
  ingress:
    className: nginx
    tls:
      enabled: true
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
```

#### 既存の証明書を使用

```bash
# TLS Secret を作成
kubectl create secret tls ccplant-tls \
  --cert=/path/to/tls.crt \
  --key=/path/to/tls.key \
  -n ccplant
```

```yaml
agentapi-ui:
  ingress:
    enabled: true
    tls:
    - hosts:
      - cc.example.com
      secretName: ccplant-tls

agentapi-proxy:
  ingress:
    enabled: true
    tls:
    - hosts:
      - cc-api.example.com
      secretName: ccplant-api-tls
```

### ステージング環境での Let's Encrypt

本番環境にデプロイする前に、ステージング環境で証明書取得をテスト:

```bash
# ステージング用 ClusterIssuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

```yaml
# values-staging.yaml
global:
  ingress:
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-staging
```

## リソース設定

### 基本的なリソース設定

CPU とメモリの要求と制限を設定します:

```yaml
agentapi-proxy:
  resources:
    requests:
      cpu: 100m      # 100 ミリコア (0.1 コア)
      memory: 128Mi  # 128 MiB
    limits:
      cpu: 500m      # 500 ミリコア (0.5 コア)
      memory: 512Mi  # 512 MiB

agentapi-ui:
  resources:
    requests:
      cpu: 50m       # 50 ミリコア (0.05 コア)
      memory: 64Mi   # 64 MiB
    limits:
      cpu: 200m      # 200 ミリコア (0.2 コア)
      memory: 256Mi  # 256 MiB
```

### 環境別のリソース設定

#### 開発環境

```yaml
# values-dev.yaml
agentapi-proxy:
  replicaCount: 1
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 256Mi

agentapi-ui:
  replicaCount: 1
  resources:
    requests:
      cpu: 25m
      memory: 32Mi
    limits:
      cpu: 100m
      memory: 128Mi
```

#### ステージング環境

```yaml
# values-staging.yaml
agentapi-proxy:
  replicaCount: 2
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

agentapi-ui:
  replicaCount: 2
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 256Mi
```

#### 本番環境

```yaml
# values-prod.yaml
agentapi-proxy:
  replicaCount: 3
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi

agentapi-ui:
  replicaCount: 3
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

### Horizontal Pod Autoscaler (HPA)

負荷に応じて自動的にスケールする設定:

```yaml
agentapi-proxy:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80

agentapi-ui:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80
```

### Pod Disruption Budget (PDB)

メンテナンス時の最小稼働 Pod 数を保証:

```yaml
agentapi-proxy:
  podDisruptionBudget:
    enabled: true
    minAvailable: 1     # 最低 1 台は常に稼働
    # または
    # maxUnavailable: 1  # 最大 1 台まで停止可能

agentapi-ui:
  podDisruptionBudget:
    enabled: true
    minAvailable: 1
```

## 認証と認可の設定

### 認証モードの設定

```yaml
agentapi-ui:
  config:
    authMode: oauth_only  # oauth_only, token_only, または both
```

**認証モード**:
- `oauth_only`: GitHub OAuth のみを使用
- `token_only`: API トークンのみを使用
- `both`: 両方の認証方法を許可

### RBAC (Role-Based Access Control) の設定

ユーザーとチームに基づいたアクセス制御:

```yaml
agentapi-proxy:
  authConfig:
    github:
      user_mapping:
        # デフォルトロール
        default_role: user

        # デフォルト権限
        default_permissions:
          - session:create
          - session:list
          - session:delete
          - session:access

        # チームベースのロールマッピング
        team_role_mapping:
          # 管理者チーム
          "myorg/admins":
            role: admin
            permissions:
              - "*"  # すべての権限

          # 開発チーム
          "myorg/developers":
            role: developer
            permissions:
              - session:create
              - session:list
              - session:delete
              - session:access
              - webhook:create
              - webhook:delete

          # 閲覧のみのチーム
          "myorg/viewers":
            role: viewer
            permissions:
              - session:list
```

### Cookie 暗号化の設定

セッション情報を暗号化するための Secret:

```bash
# ランダムな暗号化キーを生成
ENCRYPTION_SECRET=$(openssl rand -base64 32)

# Secret を作成
kubectl create secret generic agentapi-ui-encryption \
  --from-literal=cookie-encryption-secret=$ENCRYPTION_SECRET \
  -n ccplant
```

```yaml
agentapi-ui:
  cookieEncryptionSecret:
    enabled: true
    secretName: agentapi-ui-encryption
    secretKey: cookie-encryption-secret
```

## セッション管理の設定

### Kubernetes セッション Pod の設定

```yaml
agentapi-proxy:
  kubernetesSession:
    enabled: true

    # イメージ設定
    image:
      repository: ghcr.io/takutakahashi/claude-code
      tag: latest
      pullPolicy: IfNotPresent

    # リソース制限
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 1000m
        memory: 2Gi

    # Node Selector
    nodeSelector:
      workload: sessions

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
      size: 10Gi
      accessModes:
      - ReadWriteOnce
```

### セッションタイムアウトの設定

```yaml
agentapi-proxy:
  config:
    session:
      timeout: 3600           # セッションタイムアウト (秒)
      idleTimeout: 1800       # アイドルタイムアウト (秒)
      maxSessions: 100        # ユーザーごとの最大セッション数
```

### セッション Pod のセキュリティ設定

```yaml
agentapi-proxy:
  kubernetesSession:
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      fsGroup: 1000
      seccompProfile:
        type: RuntimeDefault
      capabilities:
        drop:
        - ALL
```

## 高可用性の設定

### 複数レプリカの構成

```yaml
agentapi-proxy:
  replicaCount: 3

  # Pod Anti-Affinity で異なるノードに配置
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app.kubernetes.io/name
              operator: In
              values:
              - agentapi-proxy
          topologyKey: kubernetes.io/hostname

agentapi-ui:
  replicaCount: 3

  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app.kubernetes.io/name
              operator: In
              values:
              - agentapi-ui
          topologyKey: kubernetes.io/hostname
```

### ヘルスチェックの設定

```yaml
agentapi-proxy:
  livenessProbe:
    httpGet:
      path: /health
      port: 8080
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3

  readinessProbe:
    httpGet:
      path: /health
      port: 8080
    initialDelaySeconds: 10
    periodSeconds: 5
    timeoutSeconds: 3
    failureThreshold: 3

agentapi-ui:
  livenessProbe:
    httpGet:
      path: /
      port: 3000
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3

  readinessProbe:
    httpGet:
      path: /
      port: 3000
    initialDelaySeconds: 10
    periodSeconds: 5
    timeoutSeconds: 3
    failureThreshold: 3
```

### ローリングアップデート戦略

```yaml
agentapi-proxy:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1      # 最大1台まで停止可能
      maxSurge: 1            # 最大1台まで超過可能

agentapi-ui:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
```

## 環境別設定

### 開発環境 (values-dev.yaml)

```yaml
global:
  hostname: ccplant-dev.local
  apiHostname: api.ccplant-dev.local
  github:
    oauth:
      clientId: "dev_client_id"
      clientSecret: "dev_client_secret"
  ingress:
    className: nginx
    tls:
      enabled: false  # 開発環境では TLS なし

agentapi-proxy:
  replicaCount: 1
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 256Mi
  config:
    logLevel: debug  # デバッグログを有効化

agentapi-ui:
  replicaCount: 1
  resources:
    requests:
      cpu: 25m
      memory: 32Mi
    limits:
      cpu: 100m
      memory: 128Mi
```

### ステージング環境 (values-staging.yaml)

```yaml
global:
  hostname: ccplant-staging.company.com
  apiHostname: api.ccplant-staging.company.com
  github:
    oauth:
      clientId: "staging_client_id"
      clientSecret: "staging_client_secret"
  ingress:
    className: nginx
    tls:
      enabled: true
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-staging

agentapi-proxy:
  replicaCount: 2
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

agentapi-ui:
  replicaCount: 2
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 256Mi
```

### 本番環境 (values-prod.yaml)

```yaml
global:
  hostname: ccplant.company.com
  apiHostname: api.ccplant.company.com
  github:
    oauth:
      clientId: "prod_client_id"
      clientSecret: "prod_client_secret"
  ingress:
    className: nginx
    tls:
      enabled: true
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod

agentapi-proxy:
  replicaCount: 3
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
  podDisruptionBudget:
    enabled: true
    minAvailable: 2

agentapi-ui:
  replicaCount: 3
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
  podDisruptionBudget:
    enabled: true
    minAvailable: 2
```

## 本番環境準備チェックリスト

デプロイ前に以下の項目を確認してください:

### セキュリティ

- [ ] すべての Secret が適切に作成されている
- [ ] GitHub OAuth と GitHub App の認証情報が環境変数ではなく Secret に保存されている
- [ ] TLS/HTTPS が有効化されている
- [ ] Ingress にセキュリティヘッダーが設定されている
- [ ] Cookie 暗号化が有効化されている
- [ ] RBAC が適切に設定されている

### 高可用性

- [ ] レプリカ数が 3 以上に設定されている
- [ ] Pod Anti-Affinity が設定されている
- [ ] Pod Disruption Budget が設定されている
- [ ] HPA が設定されている
- [ ] ヘルスチェックが適切に設定されている

### リソース

- [ ] CPU とメモリの requests と limits が設定されている
- [ ] リソース制限が実際の負荷に適している
- [ ] クラスターに十分なリソースが存在する
- [ ] StorageClass が適切に設定されている (永続ボリュームを使用する場合)

### ネットワーク

- [ ] Ingress Controller がインストールされている
- [ ] DNS レコードが正しく設定されている
- [ ] TLS 証明書が取得されている
- [ ] cert-manager がインストールされている (Let's Encrypt を使用する場合)

### モニタリング

- [ ] ログが適切に収集されている
- [ ] メトリクスが収集されている (Prometheus など)
- [ ] アラートが設定されている
- [ ] ダッシュボードが作成されている (Grafana など)

### バックアップ

- [ ] 重要な Secret のバックアップが作成されている
- [ ] 永続ボリュームのバックアップ戦略が決定されている
- [ ] リストア手順がドキュメント化されている

### ドキュメント

- [ ] デプロイ手順がドキュメント化されている
- [ ] トラブルシューティング手順が用意されている
- [ ] 緊急連絡先が明確になっている
- [ ] ロールバック手順が確認されている

## 次のステップ

- [トラブルシューティング](./troubleshooting.md) - よくある問題と解決方法
- [運用ガイド](../operations/monitoring.md) - モニタリングとメンテナンス
- [セキュリティガイド](../operations/security.md) - セキュリティのベストプラクティス
- [バックエンド設定](../backend/configuration.md) - バックエンドの詳細設定
- [フロントエンド設定](../frontend/configuration.md) - フロントエンドの詳細設定
