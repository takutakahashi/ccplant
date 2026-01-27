# セキュリティベストプラクティス

ccplant プロジェクトのセキュリティ対策とベストプラクティスの完全ガイドです。

## 目次

- [セキュリティ概要](#セキュリティ概要)
- [認証 (Authentication)](#認証-authentication)
- [認可 (Authorization)](#認可-authorization)
- [TLS/HTTPS](#tlshttps)
- [シークレット管理](#シークレット管理)
- [コンテナセキュリティ](#コンテナセキュリティ)
- [ネットワークポリシー](#ネットワークポリシー)
- [脆弱性スキャン](#脆弱性スキャン)
- [セキュリティ監査](#セキュリティ監査)
- [インシデント対応](#インシデント対応)

## セキュリティ概要

### セキュリティの多層防御

```
┌─────────────────────────────────────────────┐
│  外部からのアクセス                          │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│  1. ネットワーク層                           │
│     - Ingress (TLS/HTTPS)                   │
│     - Network Policy                        │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│  2. 認証層                                   │
│     - GitHub OAuth 2.0                      │
│     - GitHub App                            │
│     - API Key                               │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│  3. 認可層                                   │
│     - RBAC (Role-Based Access Control)      │
│     - Kubernetes RBAC                       │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│  4. アプリケーション層                        │
│     - 入力検証                               │
│     - セキュアコーディング                    │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│  5. データ層                                 │
│     - 暗号化                                 │
│     - アクセス制御                           │
└─────────────────────────────────────────────┘
```

### セキュリティ原則

- **最小権限の原則**: 必要最小限の権限のみを付与
- **多層防御**: 複数のセキュリティ層を実装
- **ゼロトラスト**: すべてのアクセスを検証
- **暗号化**: 転送中・保存時のデータを暗号化
- **監査**: すべての重要な操作をログ記録

## 認証 (Authentication)

### GitHub OAuth 2.0

#### 設定

```yaml
# values.yaml
global:
  github:
    oauth:
      clientId: "Iv1.xxxxxxxxxxxxxxxx"
      clientSecret: ""  # Secret で管理

agentapi-proxy:
  config:
    auth:
      enabled: true
      github:
        enabled: true
```

#### Secret の作成

```bash
# GitHub OAuth Credentials
kubectl create secret generic github-oauth \
  --from-literal=client-id=YOUR_CLIENT_ID \
  --from-literal=client-secret=YOUR_CLIENT_SECRET \
  --namespace=ccplant

# 確認
kubectl get secret github-oauth -n ccplant -o yaml
```

#### セキュリティ推奨事項

- [ ] OAuth Client Secret を Secret で管理
- [ ] 最小限のスコープのみ要求 (`read:user`, `read:org`)
- [ ] Callback URL を厳密に設定
- [ ] CSRF トークンを使用
- [ ] トークンの有効期限を設定

### GitHub App

#### Secret の作成

```bash
# GitHub App Private Key
kubectl create secret generic github-app \
  --from-file=private-key=/path/to/github-app.pem \
  --namespace=ccplant

# パーミッションの確認
kubectl get secret github-app -n ccplant
```

#### セキュリティ推奨事項

- [ ] Private Key を Secret で管理
- [ ] 必要最小限の権限のみ設定
- [ ] JWT の有効期限を短く設定 (10分)
- [ ] Installation Token を定期的にローテーション
- [ ] Webhook Secret を使用

### API Key 認証

#### Secret の作成

```bash
# API Key の生成
API_KEY=$(openssl rand -hex 32)

# Secret に保存
kubectl create secret generic ccplant-api-keys \
  --from-literal=ci-key=$API_KEY \
  --from-literal=monitoring-key=$(openssl rand -hex 32) \
  --namespace=ccplant
```

#### 使用方法

```bash
# API Key でアクセス
curl -X POST https://ccplant.example.com/api/v1/sessions \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"name": "test-session"}'
```

#### セキュリティ推奨事項

- [ ] API Key を Secret で管理
- [ ] 用途ごとに異なる Key を発行
- [ ] Key を定期的にローテーション (3ヶ月ごと)
- [ ] IP ホワイトリストと併用
- [ ] レート制限を設定

## 認可 (Authorization)

### RBAC (Role-Based Access Control)

#### ロールの定義

```yaml
# auth-config.yaml
github:
  user_mapping:
    default_role: "user"
    default_permissions:
      - "session:create"
      - "session:list"
      - "session:delete"
      - "session:access"

    team_role_mapping:
      "my-org/engineering":
        role: "admin"
        permissions:
          - "session:create"
          - "session:list"
          - "session:delete"
          - "session:access"
          - "user:manage"
          - "config:manage"

      "my-org/devops":
        role: "operator"
        permissions:
          - "session:create"
          - "session:list"
          - "session:delete"
          - "session:access"
          - "session:manage_all"

      "my-org/contractors":
        role: "limited"
        permissions:
          - "session:create"
          - "session:list"
          - "session:access"
```

#### ConfigMap の作成

```bash
kubectl create configmap ccplant-auth-config \
  --from-file=auth-config.yaml \
  --namespace=ccplant
```

### Kubernetes RBAC

#### ServiceAccount の作成

```yaml
# Backend ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ccplant-backend
  namespace: ccplant

---
# Role: Pod とリソース管理
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ccplant-backend-role
  namespace: ccplant
rules:
  # Pod 管理
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch", "create", "delete"]

  # Pod ログ
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get"]

  # Service 管理
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list", "create", "delete"]

  # Secret 管理
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "create", "update", "delete"]

  # ConfigMap 管理
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "create", "update", "delete"]

---
# RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ccplant-backend-binding
  namespace: ccplant
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ccplant-backend-role
subjects:
- kind: ServiceAccount
  name: ccplant-backend
  namespace: ccplant
```

#### セッション Pod 用の最小権限 ServiceAccount

```yaml
# Session ServiceAccount (最小権限)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ccplant-session
  namespace: ccplant

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ccplant-session-role
  namespace: ccplant
rules:
  # 自身の Pod 情報のみ取得可能
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]

  # ConfigMap 読み取り
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list"]

  # Secret 書き込み (credentials-sync 用)
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["create", "update"]
```

## TLS/HTTPS

### cert-manager のインストール

```bash
# cert-manager をインストール
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# インストール確認
kubectl get pods -n cert-manager
```

### Let's Encrypt ClusterIssuer

```yaml
# ClusterIssuer (本番環境)
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

---
# ClusterIssuer (ステージング環境)
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
```

### Ingress での TLS 設定

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ccplant-ingress
  namespace: ccplant
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    # HSTS の設定
    nginx.ingress.kubernetes.io/hsts: "true"
    nginx.ingress.kubernetes.io/hsts-max-age: "31536000"
    nginx.ingress.kubernetes.io/hsts-include-subdomains: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - ccplant.example.com
    secretName: ccplant-frontend-tls
  - hosts:
    - api.ccplant.example.com
    secretName: ccplant-backend-tls
  rules:
  - host: ccplant.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ccplant-frontend
            port:
              number: 3000
  - host: api.ccplant.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ccplant-backend
            port:
              number: 8080
```

### TLS 証明書の確認

```bash
# Certificate の状態確認
kubectl get certificate -n ccplant

# Certificate の詳細
kubectl describe certificate ccplant-frontend-tls -n ccplant

# 証明書の有効期限確認
kubectl get secret ccplant-frontend-tls -n ccplant -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -noout -dates

# 証明書の自動更新確認
kubectl logs -n cert-manager -l app=cert-manager
```

## シークレット管理

### Secret の種類

```bash
# 1. GitHub OAuth
kubectl create secret generic github-oauth \
  --from-literal=client-id=xxx \
  --from-literal=client-secret=xxx \
  -n ccplant

# 2. GitHub App
kubectl create secret generic github-app \
  --from-file=private-key=github-app.pem \
  -n ccplant

# 3. Cookie 暗号化
kubectl create secret generic agentapi-ui-encryption \
  --from-literal=cookie-encryption-secret=$(openssl rand -base64 32) \
  -n ccplant

# 4. API Key
kubectl create secret generic ccplant-api-keys \
  --from-literal=ci-key=$(openssl rand -hex 32) \
  -n ccplant
```

### Secret のベストプラクティス

#### 1. Secret の暗号化

```yaml
# EncryptionConfiguration
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <BASE64_ENCODED_SECRET>
      - identity: {}
```

#### 2. External Secrets Operator の使用

```bash
# External Secrets Operator をインストール
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace
```

```yaml
# ExternalSecret の例
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: ccplant-github-oauth
  namespace: ccplant
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: github-oauth
    creationPolicy: Owner
  data:
  - secretKey: client-id
    remoteRef:
      key: ccplant/github-oauth
      property: client-id
  - secretKey: client-secret
    remoteRef:
      key: ccplant/github-oauth
      property: client-secret
```

#### 3. Sealed Secrets の使用

```bash
# Sealed Secrets Controller をインストール
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# kubeseal CLI をインストール
brew install kubeseal

# Secret を暗号化
kubectl create secret generic github-oauth \
  --from-literal=client-id=xxx \
  --from-literal=client-secret=xxx \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml

# 暗号化された Secret を適用
kubectl apply -f sealed-secret.yaml
```

### Secret ローテーション

```bash
# 1. 新しい Secret を作成
kubectl create secret generic github-oauth-new \
  --from-literal=client-id=NEW_ID \
  --from-literal=client-secret=NEW_SECRET \
  -n ccplant

# 2. Deployment を更新
kubectl set env deployment/ccplant-backend \
  --from=secret/github-oauth-new \
  -n ccplant

# 3. ロールアウト確認
kubectl rollout status deployment/ccplant-backend -n ccplant

# 4. 古い Secret を削除
kubectl delete secret github-oauth -n ccplant
kubectl get secret github-oauth-new -o yaml | \
  sed 's/github-oauth-new/github-oauth/' | \
  kubectl apply -f -
kubectl delete secret github-oauth-new -n ccplant
```

## コンテナセキュリティ

### セキュリティコンテキスト

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ccplant-backend
spec:
  template:
    spec:
      # Pod レベルのセキュリティコンテキスト
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        fsGroup: 999
        seccompProfile:
          type: RuntimeDefault

      containers:
      - name: agentapi-proxy
        image: ghcr.io/takutakahashi/agentapi-proxy:latest

        # コンテナレベルのセキュリティコンテキスト
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          runAsUser: 999
          readOnlyRootFilesystem: false
          capabilities:
            drop:
              - ALL

        # リソース制限
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

### イメージセキュリティ

#### 1. イメージの署名と検証

```bash
# Cosign でイメージに署名
cosign sign ghcr.io/takutakahashi/agentapi-proxy:v1.191.0

# 署名を検証
cosign verify ghcr.io/takutakahashi/agentapi-proxy:v1.191.0
```

#### 2. イメージスキャン

```bash
# Trivy でスキャン
trivy image ghcr.io/takutakahashi/agentapi-proxy:latest

# Grype でスキャン
grype ghcr.io/takutakahashi/agentapi-proxy:latest
```

#### 3. 許可されたレジストリの制限

```yaml
# PodSecurityPolicy (非推奨) の代わりに
# OPA Gatekeeper を使用
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sAllowedRepos
metadata:
  name: allowed-repos
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    namespaces:
      - ccplant
  parameters:
    repos:
      - "ghcr.io/takutakahashi/"
```

## ネットワークポリシー

### Default Deny Policy

```yaml
# すべてのトラフィックをデフォルトで拒否
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: ccplant
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### Backend ネットワークポリシー

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ccplant-backend-policy
  namespace: ccplant
spec:
  podSelector:
    matchLabels:
      app: ccplant
      component: backend
  policyTypes:
  - Ingress
  - Egress

  ingress:
  # Frontend からのアクセスを許可
  - from:
    - podSelector:
        matchLabels:
          app: ccplant
          component: frontend
    ports:
    - protocol: TCP
      port: 8080

  # Ingress からのアクセスを許可
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080

  # Prometheus からのメトリクス収集を許可
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 9464

  egress:
  # DNS
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53

  # GitHub API
  - to:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 443

  # Kubernetes API
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          component: apiserver
    ports:
    - protocol: TCP
      port: 443
```

### Frontend ネットワークポリシー

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ccplant-frontend-policy
  namespace: ccplant
spec:
  podSelector:
    matchLabels:
      app: ccplant
      component: frontend
  policyTypes:
  - Ingress
  - Egress

  ingress:
  # Ingress からのアクセスを許可
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 3000

  egress:
  # DNS
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53

  # Backend へのアクセス
  - to:
    - podSelector:
        matchLabels:
          app: ccplant
          component: backend
    ports:
    - protocol: TCP
      port: 8080
```

## 脆弱性スキャン

### Trivy によるスキャン

```bash
# イメージのスキャン
trivy image --severity HIGH,CRITICAL \
  ghcr.io/takutakahashi/agentapi-proxy:latest

# Kubernetes マニフェストのスキャン
trivy config charts/ccplant/

# クラスター内のスキャン
trivy k8s --report summary cluster
```

### 自動スキャンの設定

```yaml
# GitHub Actions でのスキャン
name: Security Scan

on:
  schedule:
    - cron: '0 0 * * *'  # 毎日実行
  workflow_dispatch:

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Trivy
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'config'
          scan-ref: 'charts/ccplant/'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload results to GitHub Security
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'
```

## セキュリティ監査

### 監査ログの有効化

```yaml
# Kubernetes 監査ポリシー
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Secret へのアクセスをログ
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["secrets"]

  # Pod の作成・削除をログ
  - level: Request
    verbs: ["create", "delete"]
    resources:
      - group: ""
        resources: ["pods"]

  # 認証失敗をログ
  - level: Metadata
    omitStages:
      - RequestReceived
```

### アクセスログの監視

```bash
# Backend のアクセスログ
kubectl logs -f -n ccplant -l component=backend | \
  jq 'select(.level == "info" and .event == "http_request")'

# 認証失敗のログ
kubectl logs -f -n ccplant -l component=backend | \
  jq 'select(.event == "authentication_failed")'

# 権限エラーのログ
kubectl logs -f -n ccplant -l component=backend | \
  jq 'select(.event == "authorization_failed")'
```

## インシデント対応

### インシデント対応プロセス

```
1. 検知
   - アラート通知
   - 異常ログの発見

2. 初動対応
   - 影響範囲の特定
   - 緊急対策の実施

3. 調査
   - ログの分析
   - タイムラインの作成

4. 対策
   - 脆弱性の修正
   - セキュリティ強化

5. 事後対応
   - ポストモーテムの作成
   - 再発防止策の実施
```

### 緊急時のコマンド

```bash
# 1. 影響を受けたコンポーネントの隔離
kubectl scale deployment ccplant-backend --replicas=0 -n ccplant

# 2. ネットワークポリシーで通信を遮断
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: emergency-deny-all
  namespace: ccplant
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# 3. ログの収集
kubectl logs -n ccplant --all-containers=true --timestamps > incident-logs.txt

# 4. イベントの収集
kubectl get events -n ccplant --sort-by='.lastTimestamp' > incident-events.txt

# 5. Pod の詳細情報を収集
kubectl get pods -n ccplant -o yaml > incident-pods.yaml
```

## 参考リンク

- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [cert-manager Documentation](https://cert-manager.io/docs/)
