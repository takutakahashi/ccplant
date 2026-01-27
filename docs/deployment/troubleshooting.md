# トラブルシューティングガイド

ccplant のデプロイと運用中に発生する一般的な問題とその解決方法をまとめたガイドです。

## 目次

- [概要](#概要)
- [デプロイ時の問題](#デプロイ時の問題)
- [Pod の問題](#pod-の問題)
- [イメージプルの問題](#イメージプルの問題)
- [認証の問題](#認証の問題)
- [Ingress の問題](#ingress-の問題)
- [TLS/証明書の問題](#tls証明書の問題)
- [セッション Pod の問題](#セッション-pod-の問題)
- [ネットワークの問題](#ネットワークの問題)
- [リソース不足の問題](#リソース不足の問題)
- [デバッグコマンド集](#デバッグコマンド集)

## 概要

トラブルシューティングの基本的なアプローチ:

1. **症状の確認**: エラーメッセージやログを確認
2. **原因の特定**: 問題の根本原因を調査
3. **解決策の適用**: 適切な対処法を実行
4. **検証**: 問題が解決したことを確認
5. **予防**: 同じ問題が再発しないように対策

### 基本的なデバッグコマンド

```bash
# すべてのリソースの状態確認
kubectl get all -n ccplant

# Pod の詳細確認
kubectl describe pod <pod-name> -n ccplant

# ログの確認
kubectl logs <pod-name> -n ccplant

# イベントの確認
kubectl get events -n ccplant --sort-by='.lastTimestamp'
```

## デプロイ時の問題

### Helm インストールが失敗する

**症状**:
```
Error: INSTALLATION FAILED: failed to create resource
```

**原因と解決策**:

1. **Namespace が存在しない**
   ```bash
   # Namespace を作成
   kubectl create namespace ccplant

   # または --create-namespace オプションを使用
   helm install ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
     --namespace ccplant \
     --create-namespace \
     --values values.yaml
   ```

2. **必要な Secret が存在しない**
   ```bash
   # Secret の存在確認
   kubectl get secrets -n ccplant

   # 不足している Secret を作成
   kubectl create secret generic github-app \
     --from-file=private-key=/path/to/github-app-private-key.pem \
     -n ccplant

   kubectl create secret generic agentapi-ui-encryption \
     --from-literal=cookie-encryption-secret=$(openssl rand -base64 32) \
     -n ccplant
   ```

3. **values.yaml の構文エラー**
   ```bash
   # values.yaml の検証
   helm lint -f values.yaml

   # テンプレートのレンダリング確認
   helm template ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
     --values values.yaml \
     --debug
   ```

4. **権限不足**
   ```bash
   # 現在のユーザーの権限確認
   kubectl auth can-i create deployment -n ccplant
   kubectl auth can-i create service -n ccplant

   # クラスター管理者に権限の付与を依頼
   ```

### Helm アップグレードが失敗する

**症状**:
```
Error: UPGRADE FAILED: another operation (install/upgrade/rollback) is in progress
```

**解決策**:

1. **進行中の操作を確認**
   ```bash
   # リリースの状態確認
   helm status ccplant -n ccplant

   # 必要に応じてロールバック
   helm rollback ccplant -n ccplant
   ```

2. **強制アップグレード** (注意: データ損失の可能性)
   ```bash
   helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
     --namespace ccplant \
     --values values.yaml \
     --force
   ```

## Pod の問題

### Pod が Pending 状態のまま

**症状**:
```bash
kubectl get pods -n ccplant
# NAME                               READY   STATUS    RESTARTS   AGE
# ccplant-backend-xxxxxxxxxx-xxxxx   0/1     Pending   0          5m
```

**原因と解決策**:

1. **リソース不足**
   ```bash
   # Node のリソース確認
   kubectl top nodes
   kubectl describe nodes

   # Pod のイベント確認
   kubectl describe pod <pod-name> -n ccplant
   # 出力: "Insufficient cpu" または "Insufficient memory"

   # 解決策: リソース要求を減らす
   helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
     --namespace ccplant \
     --values values.yaml \
     --set agentapi-proxy.resources.requests.cpu=50m \
     --set agentapi-proxy.resources.requests.memory=64Mi
   ```

2. **Node Selector が一致しない**
   ```bash
   # Pod の Node Selector 確認
   kubectl get pod <pod-name> -n ccplant -o yaml | grep -A5 nodeSelector

   # Node のラベル確認
   kubectl get nodes --show-labels

   # 解決策: Node にラベルを追加
   kubectl label nodes <node-name> workload=sessions

   # または Node Selector を削除
   helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
     --namespace ccplant \
     --values values.yaml \
     --set agentapi-proxy.kubernetesSession.nodeSelector=null
   ```

3. **PVC がバインドされない**
   ```bash
   # PVC の状態確認
   kubectl get pvc -n ccplant

   # StorageClass の確認
   kubectl get storageclass

   # 解決策: 適切な StorageClass を指定
   helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
     --namespace ccplant \
     --values values.yaml \
     --set agentapi-proxy.kubernetesSession.pvc.storageClass=standard
   ```

### Pod が CrashLoopBackOff 状態

**症状**:
```bash
kubectl get pods -n ccplant
# NAME                               READY   STATUS             RESTARTS   AGE
# ccplant-backend-xxxxxxxxxx-xxxxx   0/1     CrashLoopBackOff   5          5m
```

**原因と解決策**:

1. **アプリケーションエラー**
   ```bash
   # 現在のログ確認
   kubectl logs <pod-name> -n ccplant

   # 前回のコンテナのログ確認
   kubectl logs <pod-name> -n ccplant --previous

   # よくあるエラー:
   # - "GitHub App ID is required"
   # - "Failed to connect to database"
   # - "Invalid configuration"

   # 解決策: 設定を確認して修正
   kubectl get secret -n ccplant
   helm get values ccplant -n ccplant
   ```

2. **環境変数の不足**
   ```bash
   # Pod の環境変数確認
   kubectl exec <pod-name> -n ccplant -- env

   # 必要な環境変数を追加
   helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
     --namespace ccplant \
     --values values.yaml \
     --set agentapi-proxy.github.app.id=123456
   ```

3. **メモリ不足 (OOMKilled)**
   ```bash
   # Pod のイベント確認
   kubectl describe pod <pod-name> -n ccplant
   # 出力: "OOMKilled"

   # 解決策: メモリ制限を増やす
   helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
     --namespace ccplant \
     --values values.yaml \
     --set agentapi-proxy.resources.limits.memory=1Gi
   ```

### Pod が Running だが Ready にならない

**症状**:
```bash
kubectl get pods -n ccplant
# NAME                               READY   STATUS    RESTARTS   AGE
# ccplant-backend-xxxxxxxxxx-xxxxx   0/1     Running   0          5m
```

**原因と解決策**:

1. **Readiness Probe が失敗**
   ```bash
   # Pod のイベント確認
   kubectl describe pod <pod-name> -n ccplant
   # 出力: "Readiness probe failed"

   # Readiness Probe を手動で実行
   kubectl exec <pod-name> -n ccplant -- curl -f http://localhost:8080/health

   # 解決策: Readiness Probe の設定を調整
   helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
     --namespace ccplant \
     --values values.yaml \
     --set agentapi-proxy.readinessProbe.initialDelaySeconds=60
   ```

2. **アプリケーションの起動に時間がかかる**
   ```bash
   # ログで起動プロセスを確認
   kubectl logs -f <pod-name> -n ccplant

   # 解決策: initialDelaySeconds を増やす
   ```

## イメージプルの問題

### ImagePullBackOff エラー

**症状**:
```bash
kubectl get pods -n ccplant
# NAME                               READY   STATUS             RESTARTS   AGE
# ccplant-backend-xxxxxxxxxx-xxxxx   0/1     ImagePullBackOff   0          2m
```

**原因と解決策**:

1. **イメージが存在しない**
   ```bash
   # Pod のイベント確認
   kubectl describe pod <pod-name> -n ccplant
   # 出力: "Failed to pull image" "manifest unknown"

   # イメージのタグ確認
   kubectl get pod <pod-name> -n ccplant -o yaml | grep image:

   # 解決策: 正しいイメージタグを指定
   helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
     --version v0.4.0 \
     --namespace ccplant \
     --values values.yaml
   ```

2. **プライベートレジストリの認証エラー**
   ```bash
   # ImagePullSecret の存在確認
   kubectl get secret -n ccplant | grep docker

   # ImagePullSecret を作成
   kubectl create secret docker-registry ghcr-secret \
     --docker-server=ghcr.io \
     --docker-username=YOUR_USERNAME \
     --docker-password=YOUR_TOKEN \
     -n ccplant

   # Deployment に ImagePullSecret を追加
   kubectl patch deployment ccplant-backend -n ccplant \
     -p '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"ghcr-secret"}]}}}}'
   ```

3. **レート制限**
   ```bash
   # Pod のイベント確認
   kubectl describe pod <pod-name> -n ccplant
   # 出力: "rate limit exceeded"

   # 解決策: 認証してレート制限を回避
   # ImagePullSecret を作成 (上記参照)
   ```

4. **ネットワークの問題**
   ```bash
   # Node からレジストリへの接続確認
   kubectl run test --image=curlimages/curl -it --rm -- \
     curl -I https://ghcr.io/v2/

   # 解決策: プロキシ設定や firewall を確認
   ```

## 認証の問題

### GitHub OAuth ログインに失敗

**症状**:
- ブラウザで "Authorization failed" または "OAuth error" が表示される

**原因と解決策**:

1. **OAuth App の設定ミス**
   ```bash
   # 現在の設定を確認
   helm get values ccplant -n ccplant | grep oauth

   # GitHub OAuth App の設定を確認:
   # - Homepage URL: https://cc.example.com
   # - Callback URL: https://cc.example.com/api/auth/callback/github

   # 解決策: 正しい Client ID と Secret を設定
   helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
     --namespace ccplant \
     --values values.yaml \
     --set global.github.oauth.clientId=CORRECT_CLIENT_ID \
     --set global.github.oauth.clientSecret=CORRECT_CLIENT_SECRET
   ```

2. **Callback URL のミスマッチ**
   ```bash
   # Frontend のログを確認
   kubectl logs -f deployment/ccplant-agentapi-ui -n ccplant

   # GitHub OAuth App の Callback URL を確認
   # 正しい URL: https://<your-domain>/api/auth/callback/github

   # hostname が正しく設定されているか確認
   helm get values ccplant -n ccplant | grep hostname
   ```

3. **Cookie の問題**
   ```bash
   # Cookie 暗号化 Secret の確認
   kubectl get secret agentapi-ui-encryption -n ccplant

   # ブラウザの Cookie をクリア
   # Chrome: 設定 → プライバシーとセキュリティ → Cookie と他のサイトデータ
   ```

### GitHub App の認証エラー

**症状**:
- Backend ログに "GitHub App authentication failed" が表示される

**原因と解決策**:

1. **Private Key が正しくない**
   ```bash
   # Secret の内容確認
   kubectl get secret github-app -n ccplant -o yaml

   # Private Key が正しいか確認
   kubectl get secret github-app -n ccplant -o jsonpath='{.data.private-key}' | \
     base64 -d | head -n 1
   # 出力: "-----BEGIN RSA PRIVATE KEY-----" または "-----BEGIN PRIVATE KEY-----"

   # 解決策: 正しい Private Key で Secret を再作成
   kubectl delete secret github-app -n ccplant
   kubectl create secret generic github-app \
     --from-file=private-key=/path/to/correct-github-app-private-key.pem \
     -n ccplant

   # Pod を再起動
   kubectl rollout restart deployment/ccplant-agentapi-proxy -n ccplant
   ```

2. **App ID が間違っている**
   ```bash
   # 現在の App ID を確認
   helm get values ccplant -n ccplant | grep "app:" -A5

   # GitHub App の設定ページで正しい App ID を確認
   # https://github.com/settings/apps/<your-app>

   # 解決策: 正しい App ID を設定
   helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
     --namespace ccplant \
     --values values.yaml \
     --set agentapi-proxy.github.app.id=123456
   ```

## Ingress の問題

### Ingress 経由でアクセスできない

**症状**:
- ブラウザで "502 Bad Gateway" または "503 Service Unavailable" が表示される

**原因と解決策**:

1. **Ingress Controller が動作していない**
   ```bash
   # Ingress Controller の Pod 確認
   kubectl get pods -n ingress-nginx

   # Ingress Controller のログ確認
   kubectl logs -f -n ingress-nginx -l app.kubernetes.io/component=controller

   # 解決策: Ingress Controller をインストール
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace
   ```

2. **Ingress の設定ミス**
   ```bash
   # Ingress の詳細確認
   kubectl describe ingress -n ccplant

   # Backend Service の確認
   kubectl get svc -n ccplant

   # Endpoint の確認
   kubectl get endpoints -n ccplant

   # 解決策: Service 名やポートを修正
   ```

3. **DNS の設定ミス**
   ```bash
   # Ingress の IP アドレス確認
   kubectl get ingress -n ccplant -o wide

   # DNS の確認
   nslookup cc.example.com
   nslookup cc-api.example.com

   # 解決策: DNS レコードを正しい IP に設定
   ```

4. **Backend Pod が Ready でない**
   ```bash
   # Pod の状態確認
   kubectl get pods -n ccplant

   # Service の Endpoint 確認
   kubectl get endpoints ccplant-backend -n ccplant
   # Endpoint が空の場合、Pod が Ready でない

   # 解決策: Pod の問題を修正 (上記 "Pod の問題" 参照)
   ```

### Ingress で 404 Not Found が返される

**症状**:
- 特定のパスにアクセスすると 404 エラーが返される

**原因と解決策**:

1. **パスの設定ミス**
   ```bash
   # Ingress のパス設定確認
   kubectl get ingress -n ccplant -o yaml | grep -A10 paths

   # 解決策: pathType を Prefix に設定
   # Helm の場合は values.yaml で設定
   ```

2. **Backend アプリケーションの問題**
   ```bash
   # Backend に直接アクセスして確認
   kubectl port-forward svc/ccplant-backend 8080:8080 -n ccplant
   curl http://localhost:8080/api/health

   # Backend のログ確認
   kubectl logs -f deployment/ccplant-backend -n ccplant
   ```

## TLS/証明書の問題

### TLS 証明書が取得されない

**症状**:
- HTTPS でアクセスすると証明書エラーが表示される
- Certificate が Pending 状態のまま

**原因と解決策**:

1. **cert-manager が動作していない**
   ```bash
   # cert-manager の Pod 確認
   kubectl get pods -n cert-manager

   # cert-manager のログ確認
   kubectl logs -f -n cert-manager -l app=cert-manager

   # 解決策: cert-manager をインストール
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   ```

2. **ClusterIssuer が存在しない**
   ```bash
   # ClusterIssuer の確認
   kubectl get clusterissuer

   # ClusterIssuer を作成
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

3. **Certificate Request が失敗**
   ```bash
   # Certificate の状態確認
   kubectl describe certificate -n ccplant

   # CertificateRequest の確認
   kubectl get certificaterequest -n ccplant
   kubectl describe certificaterequest -n ccplant

   # Challenge の確認
   kubectl get challenge -n ccplant
   kubectl describe challenge -n ccplant

   # よくあるエラー:
   # - "Challenge failed: connection refused"
   #   → Ingress が正しく動作していない
   # - "Challenge failed: 404 Not Found"
   #   → HTTP-01 Challenge のルーティングが機能していない

   # 解決策: Challenge Pod にアクセスできるか確認
   kubectl get pods -n ccplant | grep cm-acme-http
   ```

4. **DNS の伝播待ち** (DNS-01 Challenge の場合)
   ```bash
   # DNS レコードの確認
   nslookup -type=TXT _acme-challenge.cc.example.com

   # 解決策: DNS の伝播を待つ (最大 24 時間)
   ```

5. **レート制限** (Let's Encrypt)
   ```bash
   # Certificate のイベント確認
   kubectl describe certificate -n ccplant
   # 出力: "rate limit exceeded"

   # 解決策: ステージング環境を使用
   kubectl annotate ingress ccplant-ingress -n ccplant \
     cert-manager.io/cluster-issuer=letsencrypt-staging
   ```

## セッション Pod の問題

### セッション Pod が作成されない

**症状**:
- UI でセッション作成を試みるが、Pod が作成されない

**原因と解決策**:

1. **Kubernetes セッション機能が無効**
   ```bash
   # 設定を確認
   helm get values ccplant -n ccplant | grep kubernetesSession -A10

   # 解決策: Kubernetes セッションを有効化
   helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
     --namespace ccplant \
     --values values.yaml \
     --set agentapi-proxy.kubernetesSession.enabled=true
   ```

2. **RBAC 権限不足**
   ```bash
   # Backend Pod の ServiceAccount 確認
   kubectl get pod <backend-pod-name> -n ccplant -o yaml | grep serviceAccount

   # ServiceAccount の権限確認
   kubectl auth can-i create pods --as=system:serviceaccount:ccplant:ccplant-agentapi-proxy -n ccplant

   # 解決策: 適切な RBAC を設定
   # Helm チャートには RBAC が含まれているはず
   ```

3. **リソース不足**
   ```bash
   # Node のリソース確認
   kubectl top nodes

   # Backend のログでエラー確認
   kubectl logs -f deployment/ccplant-agentapi-proxy -n ccplant | grep "session"

   # 解決策: セッション Pod のリソース要求を減らす
   helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
     --namespace ccplant \
     --values values.yaml \
     --set agentapi-proxy.kubernetesSession.resources.requests.cpu=50m \
     --set agentapi-proxy.kubernetesSession.resources.requests.memory=128Mi
   ```

### セッション Pod が起動するが接続できない

**症状**:
- セッション Pod は Running 状態だが、UI から接続できない

**原因と解決策**:

1. **ネットワークポリシーの制限**
   ```bash
   # NetworkPolicy の確認
   kubectl get networkpolicy -n ccplant

   # セッション Pod から Backend への接続確認
   kubectl exec <session-pod> -n ccplant -- \
     curl http://ccplant-backend:8080/health
   ```

2. **Pod 間通信の問題**
   ```bash
   # Service の確認
   kubectl get svc -n ccplant

   # DNS の確認
   kubectl run test --image=curlimages/curl -it --rm -n ccplant -- \
     nslookup ccplant-backend.ccplant.svc.cluster.local
   ```

## ネットワークの問題

### Pod 間通信ができない

**症状**:
- Frontend から Backend に接続できない
- Backend からセッション Pod に接続できない

**原因と解決策**:

1. **Service が存在しない**
   ```bash
   # Service の確認
   kubectl get svc -n ccplant

   # Service の詳細確認
   kubectl describe svc ccplant-backend -n ccplant

   # Endpoint の確認
   kubectl get endpoints ccplant-backend -n ccplant
   ```

2. **DNS 解決の問題**
   ```bash
   # Pod 内から DNS 解決をテスト
   kubectl run test --image=curlimages/curl -it --rm -n ccplant -- \
     nslookup ccplant-backend

   # CoreDNS の確認
   kubectl get pods -n kube-system | grep coredns
   kubectl logs -n kube-system -l k8s-app=kube-dns
   ```

3. **NetworkPolicy による制限**
   ```bash
   # NetworkPolicy の確認
   kubectl get networkpolicy -n ccplant
   kubectl describe networkpolicy -n ccplant

   # 解決策: 必要な通信を許可する NetworkPolicy を作成
   ```

### 外部からアクセスできない

**症状**:
- ブラウザから ccplant にアクセスできない

**原因と解決策**:

1. **LoadBalancer の IP が割り当てられていない**
   ```bash
   # Ingress Controller の Service 確認
   kubectl get svc -n ingress-nginx

   # EXTERNAL-IP が <pending> の場合
   # 解決策 1: LoadBalancer をサポートするクラスターを使用
   # 解決策 2: NodePort を使用
   # 解決策 3: Port-forward を使用 (開発環境のみ)
   kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
   ```

2. **Firewall によるブロック**
   ```bash
   # Node の IP アドレス確認
   kubectl get nodes -o wide

   # ポートが開いているか確認
   telnet <node-ip> 80
   telnet <node-ip> 443

   # 解決策: Firewall ルールを設定してポートを開放
   ```

## リソース不足の問題

### CPU リソース不足

**症状**:
- Pod が Pending 状態
- "Insufficient cpu" エラー

**原因と解決策**:

```bash
# Node のリソース使用状況確認
kubectl top nodes

# Pod のリソース要求確認
kubectl describe pod <pod-name> -n ccplant | grep -A5 Requests

# 解決策 1: リソース要求を減らす
helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --namespace ccplant \
  --values values.yaml \
  --set agentapi-proxy.resources.requests.cpu=50m \
  --set agentapi-ui.resources.requests.cpu=25m

# 解決策 2: クラスターに Node を追加

# 解決策 3: 不要な Pod を削除
kubectl delete pod <unused-pod> -n other-namespace
```

### メモリリソース不足

**症状**:
- Pod が Pending 状態
- Pod が OOMKilled で再起動を繰り返す

**原因と解決策**:

```bash
# Node のメモリ使用状況確認
kubectl top nodes

# Pod のメモリ使用状況確認
kubectl top pods -n ccplant

# OOMKilled の確認
kubectl describe pod <pod-name> -n ccplant | grep -i oom

# 解決策 1: メモリ制限を増やす
helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --namespace ccplant \
  --values values.yaml \
  --set agentapi-proxy.resources.limits.memory=1Gi

# 解決策 2: レプリカ数を減らす
helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --namespace ccplant \
  --values values.yaml \
  --set agentapi-proxy.replicaCount=1
```

### ストレージ不足

**症状**:
- PVC が Pending 状態
- "no volume provisioner" エラー

**原因と解決策**:

```bash
# StorageClass の確認
kubectl get storageclass

# PVC の状態確認
kubectl get pvc -n ccplant
kubectl describe pvc <pvc-name> -n ccplant

# 解決策 1: 適切な StorageClass を指定
helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --namespace ccplant \
  --values values.yaml \
  --set agentapi-proxy.kubernetesSession.pvc.storageClass=standard

# 解決策 2: PVC を無効化 (永続化が不要な場合)
helm upgrade ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --namespace ccplant \
  --values values.yaml \
  --set agentapi-proxy.kubernetesSession.pvc.enabled=false
```

## デバッグコマンド集

### 基本的な確認コマンド

```bash
# すべてのリソースの状態
kubectl get all -n ccplant

# Pod の詳細情報
kubectl describe pod <pod-name> -n ccplant

# ログの確認 (リアルタイム)
kubectl logs -f <pod-name> -n ccplant

# 前回のコンテナのログ (CrashLoopBackOff の場合)
kubectl logs <pod-name> -n ccplant --previous

# すべての Pod のログ
kubectl logs -f -l app=ccplant -n ccplant --all-containers=true

# イベントの確認
kubectl get events -n ccplant --sort-by='.lastTimestamp'

# リソース使用状況
kubectl top nodes
kubectl top pods -n ccplant
```

### Helm 関連コマンド

```bash
# リリースの確認
helm list -n ccplant

# リリースの詳細
helm status ccplant -n ccplant

# リリースの履歴
helm history ccplant -n ccplant

# 現在の設定値
helm get values ccplant -n ccplant

# すべての設定値 (デフォルトを含む)
helm get values ccplant -n ccplant --all

# テンプレートのレンダリング確認
helm template ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --values values.yaml \
  --debug
```

### ネットワークのデバッグ

```bash
# Pod 内でコマンド実行
kubectl exec -it <pod-name> -n ccplant -- sh

# 一時的なデバッグ Pod を起動
kubectl run debug --image=alpine -it --rm -n ccplant -- sh

# デバッグ Pod でネットワークテスト
kubectl run test --image=curlimages/curl -it --rm -n ccplant -- sh

# Pod から Service への接続テスト
kubectl exec <pod-name> -n ccplant -- \
  curl -v http://ccplant-backend:8080/health

# DNS 解決テスト
kubectl exec <pod-name> -n ccplant -- \
  nslookup ccplant-backend

# Port-forward でローカルからアクセス
kubectl port-forward svc/ccplant-backend 8080:8080 -n ccplant
```

### Secret とConfigMap の確認

```bash
# Secret の一覧
kubectl get secrets -n ccplant

# Secret の詳細 (値は表示されない)
kubectl describe secret github-app -n ccplant

# Secret の値を確認 (base64 デコード)
kubectl get secret github-app -n ccplant -o jsonpath='{.data.private-key}' | base64 -d

# ConfigMap の確認
kubectl get configmap -n ccplant
kubectl describe configmap <configmap-name> -n ccplant
```

### Ingress と Service のデバッグ

```bash
# Ingress の確認
kubectl get ingress -n ccplant
kubectl describe ingress ccplant-ingress -n ccplant

# Ingress Controller のログ
kubectl logs -f -n ingress-nginx -l app.kubernetes.io/component=controller

# Service の確認
kubectl get svc -n ccplant
kubectl describe svc ccplant-backend -n ccplant

# Endpoint の確認
kubectl get endpoints -n ccplant
kubectl describe endpoints ccplant-backend -n ccplant
```

### クリーンアップコマンド

```bash
# Pod を再起動
kubectl rollout restart deployment/ccplant-backend -n ccplant
kubectl rollout restart deployment/ccplant-frontend -n ccplant

# 失敗した Pod を削除
kubectl delete pod <pod-name> -n ccplant

# すべてのリソースを削除
helm uninstall ccplant -n ccplant
kubectl delete namespace ccplant

# イメージキャッシュをクリア (Node 上で実行)
docker system prune -a
```

## 次のステップ

問題が解決しない場合:

1. **詳細なログ収集**
   ```bash
   # すべてのログを収集
   kubectl logs deployment/ccplant-backend -n ccplant > backend.log
   kubectl logs deployment/ccplant-frontend -n ccplant > frontend.log
   kubectl get events -n ccplant > events.log
   helm get values ccplant -n ccplant > values.yaml
   ```

2. **GitHub Issues で報告**
   - リポジトリ: https://github.com/takutakahashi/ccplant/issues
   - 以下の情報を含める:
     - 環境情報 (Kubernetes バージョン、Helm バージョン)
     - エラーメッセージ
     - ログファイル
     - 実行したコマンドと結果

3. **関連ドキュメントを参照**
   - [Kubernetes デプロイガイド](./kubernetes.md)
   - [Helm Chart ガイド](./helm-chart.md)
   - [設定ガイド](./configuration.md)
   - [運用ガイド](../operations/monitoring.md)
