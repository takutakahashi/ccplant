# Kubernetes デプロイガイド

Kubernetes クラスターに ccplant をデプロイするための完全ガイドです。本番環境での運用を想定した詳細な手順を説明します。

## 目次

- [概要](#概要)
- [前提条件](#前提条件)
- [デプロイ準備](#デプロイ準備)
- [Namespace の作成](#namespace-の作成)
- [Secret の作成](#secret-の作成)
- [kubectl によるデプロイ](#kubectl-によるデプロイ)
- [デプロイの検証](#デプロイの検証)
- [Ingress の設定](#ingress-の設定)
- [TLS/HTTPS の設定](#tlshttps-の設定)
- [スケーリング](#スケーリング)
- [ローリングアップデート](#ローリングアップデート)
- [モニタリング](#モニタリング)
- [トラブルシューティング](#トラブルシューティング)

## 概要

Kubernetes を使用した ccplant のデプロイは、以下の特徴があります:

- **高可用性**: 複数レプリカによる冗長化
- **スケーラビリティ**: 負荷に応じた自動スケーリング
- **ローリングアップデート**: ダウンタイムなしの更新
- **セルフヒーリング**: 障害発生時の自動復旧
- **リソース管理**: CPU とメモリの効率的な利用

本ガイドでは kubectl コマンドを使用した基本的なデプロイ方法を説明します。Helm を使用したデプロイについては [Helm Chart ガイド](./helm-chart.md)を参照してください。

## 前提条件

### クラスター要件

- **Kubernetes**: v1.19 以上
- **kubectl**: クラスターのバージョンに対応したもの
- **クラスターリソース**:
  - 最低 2GB の空きメモリ
  - 最低 2 CPU コア
  - 10GB 以上のストレージ

### 必要なコンポーネント

以下のコンポーネントがクラスターにインストールされている必要があります:

1. **Ingress Controller** (推奨: nginx-ingress)
2. **cert-manager** (TLS/HTTPS を使用する場合)
3. **StorageClass** (永続ボリュームを使用する場合)

### kubectl のインストールと設定

```bash
# kubectl のバージョン確認
kubectl version --client

# クラスターへの接続確認
kubectl cluster-info

# ノードの確認
kubectl get nodes

# コンテキストの確認
kubectl config current-context
```

### 必要な情報の準備

デプロイ前に以下の情報を準備してください:

- GitHub OAuth App の Client ID と Client Secret
- GitHub App の App ID と Private Key
- 使用するドメイン名 (例: cc.example.com)

## デプロイ準備

### 1. 作業ディレクトリの作成

```bash
# 作業ディレクトリを作成
mkdir -p ~/ccplant-k8s
cd ~/ccplant-k8s

# マニフェストファイル用のディレクトリ
mkdir -p manifests/secrets manifests/deployments manifests/services manifests/ingress
```

### 2. Ingress Controller のインストール

nginx-ingress をインストールします:

```bash
# Helm を使用する場合
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace

# インストール確認
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### 3. cert-manager のインストール

TLS 証明書の自動管理のために cert-manager をインストールします:

```bash
# cert-manager のインストール
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# インストール確認
kubectl get pods -n cert-manager

# ClusterIssuer の作成 (Let's Encrypt)
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com  # 自分のメールアドレスに変更
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

## Namespace の作成

ccplant 用の専用 Namespace を作成します:

```bash
# Namespace の作成
kubectl create namespace ccplant

# または、マニフェストから作成
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: ccplant
  labels:
    name: ccplant
    environment: production
EOF

# 確認
kubectl get namespace ccplant
kubectl describe namespace ccplant
```

### デフォルト Namespace の設定

頻繁に ccplant Namespace を使用する場合、デフォルトに設定すると便利です:

```bash
# デフォルト Namespace を ccplant に設定
kubectl config set-context --current --namespace=ccplant

# 確認
kubectl config view --minify | grep namespace:
```

## Secret の作成

### 1. GitHub App の Private Key

GitHub App の秘密鍵ファイルから Secret を作成します:

```bash
# 秘密鍵ファイルから Secret を作成
kubectl create secret generic github-app \
  --from-file=private-key=/path/to/your/github-app-private-key.pem \
  --namespace=ccplant

# 確認
kubectl get secret github-app -n ccplant
kubectl describe secret github-app -n ccplant
```

### 2. GitHub OAuth Credentials

GitHub OAuth の認証情報を Secret として作成します:

```bash
# OAuth credentials の Secret を作成
kubectl create secret generic github-oauth \
  --from-literal=client-id=YOUR_GITHUB_OAUTH_CLIENT_ID \
  --from-literal=client-secret=YOUR_GITHUB_OAUTH_CLIENT_SECRET \
  --namespace=ccplant

# 確認
kubectl get secret github-oauth -n ccplant
```

### 3. Cookie 暗号化 Secret

UI のクッキー暗号化用のランダムな文字列を生成して Secret を作成します:

```bash
# ランダムな32文字の文字列を生成
ENCRYPTION_SECRET=$(openssl rand -base64 32)

# Secret を作成
kubectl create secret generic agentapi-ui-encryption \
  --from-literal=cookie-encryption-secret=$ENCRYPTION_SECRET \
  --namespace=ccplant

# 確認
kubectl get secret agentapi-ui-encryption -n ccplant
```

### Secret の YAML マニフェスト

Secret を YAML ファイルで管理する場合 (本番環境では推奨されません):

```yaml
# manifests/secrets/github-oauth.yaml
apiVersion: v1
kind: Secret
metadata:
  name: github-oauth
  namespace: ccplant
type: Opaque
stringData:
  client-id: "YOUR_GITHUB_OAUTH_CLIENT_ID"
  client-secret: "YOUR_GITHUB_OAUTH_CLIENT_SECRET"
---
# manifests/secrets/agentapi-ui-encryption.yaml
apiVersion: v1
kind: Secret
metadata:
  name: agentapi-ui-encryption
  namespace: ccplant
type: Opaque
stringData:
  cookie-encryption-secret: "YOUR_RANDOM_32_CHAR_STRING"
```

**警告**: Secret を YAML ファイルで管理する場合は、必ず `.gitignore` に追加し、バージョン管理システムにコミットしないでください。

### Secret の確認

```bash
# すべての Secret を表示
kubectl get secrets -n ccplant

# Secret の詳細を確認
kubectl describe secret github-app -n ccplant
kubectl describe secret github-oauth -n ccplant
kubectl describe secret agentapi-ui-encryption -n ccplant

# Secret の値を確認 (base64 デコード)
kubectl get secret github-oauth -n ccplant -o jsonpath='{.data.client-id}' | base64 -d
```

## kubectl によるデプロイ

### 1. Backend Deployment

Backend (agentapi-proxy) の Deployment を作成します:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ccplant-backend
  namespace: ccplant
  labels:
    app: ccplant
    component: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ccplant
      component: backend
  template:
    metadata:
      labels:
        app: ccplant
        component: backend
    spec:
      containers:
      - name: agentapi-proxy
        image: ghcr.io/takutakahashi/agentapi-proxy:v1.191.0
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        env:
        - name: GITHUB_OAUTH_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: github-oauth
              key: client-id
        - name: GITHUB_OAUTH_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: github-oauth
              key: client-secret
        - name: GITHUB_APP_ID
          value: "YOUR_GITHUB_APP_ID"
        - name: GITHUB_APP_PRIVATE_KEY
          valueFrom:
            secretKeyRef:
              name: github-app
              key: private-key
        - name: AUTH_ENABLED
          value: "true"
        - name: AUTH_GITHUB_ENABLED
          value: "true"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
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
EOF
```

### 2. Backend Service

Backend へのアクセスを提供する Service を作成します:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: ccplant-backend
  namespace: ccplant
  labels:
    app: ccplant
    component: backend
spec:
  type: ClusterIP
  ports:
  - port: 8080
    targetPort: 8080
    protocol: TCP
    name: http
  selector:
    app: ccplant
    component: backend
EOF
```

### 3. Frontend Deployment

Frontend (agentapi-ui) の Deployment を作成します:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ccplant-frontend
  namespace: ccplant
  labels:
    app: ccplant
    component: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ccplant
      component: frontend
  template:
    metadata:
      labels:
        app: ccplant
        component: frontend
    spec:
      containers:
      - name: agentapi-ui
        image: ghcr.io/takutakahashi/agentapi-ui:v1.97.0
        ports:
        - containerPort: 3000
          name: http
          protocol: TCP
        env:
        - name: NODE_ENV
          value: "production"
        - name: API_URL
          value: "http://ccplant-backend:8080"
        - name: NEXT_PUBLIC_API_URL
          value: "https://cc-api.example.com"
        - name: AUTH_MODE
          value: "oauth_only"
        - name: COOKIE_ENCRYPTION_SECRET
          valueFrom:
            secretKeyRef:
              name: agentapi-ui-encryption
              key: cookie-encryption-secret
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
        - name: LOGIN_TITLE
          value: "ccplant"
        - name: LOGIN_DESCRIPTION
          value: "Welcome to ccplant"
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 256Mi
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
EOF
```

### 4. Frontend Service

Frontend へのアクセスを提供する Service を作成します:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: ccplant-frontend
  namespace: ccplant
  labels:
    app: ccplant
    component: frontend
spec:
  type: ClusterIP
  ports:
  - port: 3000
    targetPort: 3000
    protocol: TCP
    name: http
  selector:
    app: ccplant
    component: frontend
EOF
```

## デプロイの検証

### 1. Pod の状態確認

```bash
# Pod の一覧を表示
kubectl get pods -n ccplant

# 期待される出力:
# NAME                               READY   STATUS    RESTARTS   AGE
# ccplant-backend-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
# ccplant-backend-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
# ccplant-frontend-xxxxxxxxxx-xxxxx  1/1     Running   0          2m
# ccplant-frontend-xxxxxxxxxx-xxxxx  1/1     Running   0          2m

# 詳細な状態を確認
kubectl get pods -n ccplant -o wide

# リアルタイムで監視
kubectl get pods -n ccplant --watch
```

### 2. Pod の詳細確認

```bash
# 特定の Pod の詳細
kubectl describe pod <pod-name> -n ccplant

# すべての backend Pod の詳細
kubectl describe pod -l component=backend -n ccplant

# すべての frontend Pod の詳細
kubectl describe pod -l component=frontend -n ccplant
```

### 3. ログの確認

```bash
# Backend のログ
kubectl logs -f deployment/ccplant-backend -n ccplant

# Frontend のログ
kubectl logs -f deployment/ccplant-frontend -n ccplant

# 特定の Pod のログ
kubectl logs -f <pod-name> -n ccplant

# 過去のログを含めて確認
kubectl logs <pod-name> -n ccplant --previous

# すべての Pod のログ
kubectl logs -l app=ccplant -n ccplant --all-containers=true
```

### 4. Service の確認

```bash
# Service の一覧
kubectl get svc -n ccplant

# Service の詳細
kubectl describe svc ccplant-backend -n ccplant
kubectl describe svc ccplant-frontend -n ccplant

# Endpoint の確認
kubectl get endpoints -n ccplant
```

### 5. 動作確認

Port-forward を使用してローカルからアクセス:

```bash
# Backend にアクセス
kubectl port-forward svc/ccplant-backend 8080:8080 -n ccplant
# 別のターミナルで
curl http://localhost:8080/health

# Frontend にアクセス
kubectl port-forward svc/ccplant-frontend 3000:3000 -n ccplant
# ブラウザで http://localhost:3000 にアクセス
```

## Ingress の設定

### 1. Ingress リソースの作成

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ccplant-ingress
  namespace: ccplant
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  rules:
  - host: cc.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ccplant-frontend
            port:
              number: 3000
  - host: cc-api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ccplant-backend
            port:
              number: 8080
EOF
```

### 2. Ingress の確認

```bash
# Ingress の一覧
kubectl get ingress -n ccplant

# Ingress の詳細
kubectl describe ingress ccplant-ingress -n ccplant

# Ingress の IP アドレス確認
kubectl get ingress ccplant-ingress -n ccplant -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### 3. DNS の設定

Ingress の IP アドレスを DNS に設定します:

```bash
# Ingress の IP を取得
INGRESS_IP=$(kubectl get ingress ccplant-ingress -n ccplant -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "以下の DNS レコードを設定してください:"
echo "cc.example.com      A    $INGRESS_IP"
echo "cc-api.example.com  A    $INGRESS_IP"
```

## TLS/HTTPS の設定

### 1. TLS 有効化した Ingress

cert-manager を使用して自動的に TLS 証明書を取得します:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ccplant-ingress
  namespace: ccplant
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - cc.example.com
    secretName: ccplant-frontend-tls
  - hosts:
    - cc-api.example.com
    secretName: ccplant-backend-tls
  rules:
  - host: cc.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ccplant-frontend
            port:
              number: 3000
  - host: cc-api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ccplant-backend
            port:
              number: 8080
EOF
```

### 2. TLS 証明書の確認

```bash
# Certificate の状態確認
kubectl get certificate -n ccplant

# Certificate の詳細
kubectl describe certificate ccplant-frontend-tls -n ccplant
kubectl describe certificate ccplant-backend-tls -n ccplant

# TLS Secret の確認
kubectl get secret ccplant-frontend-tls -n ccplant
kubectl get secret ccplant-backend-tls -n ccplant
```

### 3. 証明書発行の監視

```bash
# CertificateRequest の確認
kubectl get certificaterequest -n ccplant

# cert-manager のログ確認
kubectl logs -f -n cert-manager -l app=cert-manager

# Order と Challenge の確認
kubectl get order -n ccplant
kubectl get challenge -n ccplant
```

## スケーリング

### 1. 手動スケーリング

```bash
# Backend を 3 レプリカにスケール
kubectl scale deployment ccplant-backend --replicas=3 -n ccplant

# Frontend を 3 レプリカにスケール
kubectl scale deployment ccplant-frontend --replicas=3 -n ccplant

# スケーリング確認
kubectl get deployment -n ccplant
kubectl get pods -n ccplant
```

### 2. Horizontal Pod Autoscaler (HPA)

CPU 使用率に基づいて自動スケーリング:

```bash
# Backend の HPA 作成
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ccplant-backend-hpa
  namespace: ccplant
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ccplant-backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
EOF

# Frontend の HPA 作成
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ccplant-frontend-hpa
  namespace: ccplant
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ccplant-frontend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
EOF

# HPA の確認
kubectl get hpa -n ccplant

# HPA の詳細
kubectl describe hpa ccplant-backend-hpa -n ccplant
kubectl describe hpa ccplant-frontend-hpa -n ccplant
```

## ローリングアップデート

### 1. イメージの更新

```bash
# Backend のイメージを更新
kubectl set image deployment/ccplant-backend \
  agentapi-proxy=ghcr.io/takutakahashi/agentapi-proxy:v1.192.0 \
  -n ccplant

# Frontend のイメージを更新
kubectl set image deployment/ccplant-frontend \
  agentapi-ui=ghcr.io/takutakahashi/agentapi-ui:v1.98.0 \
  -n ccplant
```

### 2. ローリングアップデートの監視

```bash
# ロールアウト状態の確認
kubectl rollout status deployment/ccplant-backend -n ccplant
kubectl rollout status deployment/ccplant-frontend -n ccplant

# ロールアウト履歴
kubectl rollout history deployment/ccplant-backend -n ccplant
kubectl rollout history deployment/ccplant-frontend -n ccplant

# リアルタイムで Pod の変化を監視
kubectl get pods -n ccplant --watch
```

### 3. ロールバック

問題が発生した場合、前のバージョンにロールバック:

```bash
# Backend をロールバック
kubectl rollout undo deployment/ccplant-backend -n ccplant

# Frontend をロールバック
kubectl rollout undo deployment/ccplant-frontend -n ccplant

# 特定のリビジョンにロールバック
kubectl rollout undo deployment/ccplant-backend --to-revision=2 -n ccplant

# ロールアウトの一時停止と再開
kubectl rollout pause deployment/ccplant-backend -n ccplant
kubectl rollout resume deployment/ccplant-backend -n ccplant
```

## モニタリング

### 1. リソース使用状況

```bash
# Pod のリソース使用状況
kubectl top pods -n ccplant

# Node のリソース使用状況
kubectl top nodes

# 詳細なメトリクス
kubectl describe node <node-name>
```

### 2. イベントの確認

```bash
# すべてのイベント
kubectl get events -n ccplant

# 時系列でソート
kubectl get events -n ccplant --sort-by='.lastTimestamp'

# 警告イベントのみ
kubectl get events -n ccplant --field-selector type=Warning
```

### 3. リソースの状態確認

```bash
# すべてのリソースを表示
kubectl get all -n ccplant

# 特定のリソースの詳細
kubectl get deployment,service,ingress -n ccplant -o wide

# YAML 形式で表示
kubectl get deployment ccplant-backend -n ccplant -o yaml
```

## トラブルシューティング

### Pod が起動しない

```bash
# Pod の状態を確認
kubectl get pods -n ccplant

# Pod の詳細を確認
kubectl describe pod <pod-name> -n ccplant

# ログを確認
kubectl logs <pod-name> -n ccplant

# 前のコンテナのログを確認 (CrashLoopBackOff の場合)
kubectl logs <pod-name> -n ccplant --previous
```

### ImagePullBackOff エラー

```bash
# Pod の詳細を確認してエラーメッセージを確認
kubectl describe pod <pod-name> -n ccplant

# イメージが存在するか確認
docker pull ghcr.io/takutakahashi/agentapi-proxy:v1.191.0

# ImagePullSecrets を作成 (プライベートレジストリの場合)
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_TOKEN \
  -n ccplant
```

### Service に接続できない

```bash
# Service の確認
kubectl get svc -n ccplant
kubectl describe svc ccplant-backend -n ccplant

# Endpoint の確認
kubectl get endpoints ccplant-backend -n ccplant

# Pod から Service にアクセスできるか確認
kubectl run test-pod --image=curlimages/curl -it --rm -n ccplant -- \
  curl http://ccplant-backend:8080/health
```

### Ingress が機能しない

```bash
# Ingress の詳細を確認
kubectl describe ingress ccplant-ingress -n ccplant

# Ingress Controller のログを確認
kubectl logs -f -n ingress-nginx -l app.kubernetes.io/component=controller

# DNS 解決を確認
nslookup cc.example.com
nslookup cc-api.example.com

# Ingress Controller の Service を確認
kubectl get svc -n ingress-nginx
```

### TLS 証明書が発行されない

```bash
# Certificate の状態確認
kubectl describe certificate ccplant-frontend-tls -n ccplant

# CertificateRequest を確認
kubectl describe certificaterequest -n ccplant

# cert-manager のログ確認
kubectl logs -f -n cert-manager -l app=cert-manager

# Challenge を確認
kubectl get challenge -n ccplant
kubectl describe challenge -n ccplant
```

### リソース不足

```bash
# Node のリソース使用状況
kubectl top nodes
kubectl describe node <node-name>

# Pod のリソース使用状況
kubectl top pods -n ccplant

# リソース制限を調整
kubectl edit deployment ccplant-backend -n ccplant
# resources.requests と resources.limits を変更
```

### デバッグ用 Pod の実行

```bash
# デバッグ用の Pod を起動
kubectl run debug-pod --image=alpine -it --rm -n ccplant -- sh

# コンテナ内で
apk add curl
curl http://ccplant-backend:8080/health
curl http://ccplant-frontend:3000/

# 既存の Pod でコマンドを実行
kubectl exec -it <pod-name> -n ccplant -- sh
```

## 次のステップ

- [Helm Chart ガイド](./helm-chart.md) - Helm を使用した簡単なデプロイ
- [設定ガイド](./configuration.md) - 詳細な設定とカスタマイズ
- [トラブルシューティング](./troubleshooting.md) - より詳細な問題解決
- [運用ガイド](../operations/monitoring.md) - モニタリングとメンテナンス
- [セキュリティガイド](../operations/security.md) - セキュリティのベストプラクティス
