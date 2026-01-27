# クイックスタートガイド

ccplant を最短でセットアップして稼働させるためのガイドです。本番環境への詳細なデプロイについては、各デプロイ方法の詳細ドキュメントを参照してください。

## 目次

- [前提条件](#前提条件)
- [Docker Compose でのクイックスタート](#docker-compose-でのクイックスタート)
- [Helm でのクイックスタート](#helm-でのクイックスタート)
- [次のステップ](#次のステップ)

## 前提条件

### Docker Compose の場合

- Docker Engine 20.10 以上
- Docker Compose v2.0 以上
- 2GB 以上の空きメモリ

### Helm の場合

- Kubernetes クラスター v1.19 以上
- Helm v3.14.0 以上
- kubectl コマンドラインツール
- Ingress Controller (nginx-ingress 推奨)
- cert-manager (TLS/HTTPS を使用する場合)

## Docker Compose でのクイックスタート

Docker Compose を使用すると、ローカル環境で迅速に ccplant を起動できます。開発環境やテスト環境に最適です。

### 1. リポジトリのクローン

```bash
git clone https://github.com/takutakahashi/ccplant.git
cd ccplant
```

### 2. サービスの起動

```bash
# バックグラウンドで起動
docker compose up -d

# ログを確認しながら起動
docker compose up
```

### 3. アクセス確認

ブラウザで以下の URL にアクセスします:

- **フロントエンド**: http://localhost:3000
- **バックエンド API**: http://localhost:8080

### 4. 動作確認

```bash
# コンテナの状態確認
docker compose ps

# ログの確認
docker compose logs -f

# ヘルスチェック
curl http://localhost:8080/health
curl http://localhost:3000/
```

### 5. 停止と削除

```bash
# サービスの停止
docker compose stop

# サービスの停止と削除
docker compose down

# ボリュームも含めて完全削除
docker compose down -v
```

### トラブルシューティング

**ポートが既に使用されている場合**

`docker-compose.yaml` のポートマッピングを変更します:

```yaml
services:
  backend:
    ports:
      - "18080:8080"  # 8080 → 18080 に変更
  frontend:
    ports:
      - "13000:3000"  # 3000 → 13000 に変更
```

**コンテナが起動しない場合**

```bash
# イメージの再取得
docker compose pull

# キャッシュをクリアして再ビルド
docker compose build --no-cache

# 古いコンテナを削除して再起動
docker compose down -v
docker compose up -d
```

## Helm でのクイックスタート

Kubernetes 環境で Helm を使用して ccplant をデプロイします。本番環境での使用に適しています。

### 1. 必須 Secret の作成

#### GitHub App の Secret

GitHub App の秘密鍵を使用して Secret を作成します:

```bash
# GitHub App の秘密鍵ファイルから Secret を作成
kubectl create secret generic github-app \
  --from-file=private-key=/path/to/your/github-app-private-key.pem \
  -n ccplant
```

#### 暗号化 Secret の作成

UI のクッキー暗号化用のランダムな文字列を生成して Secret を作成します:

```bash
# ランダムな32文字の文字列を生成
ENCRYPTION_SECRET=$(openssl rand -base64 32)

# Secret を作成
kubectl create secret generic agentapi-ui-encryption \
  --from-literal=cookie-encryption-secret=$ENCRYPTION_SECRET \
  -n ccplant
```

### 2. Namespace の作成

```bash
kubectl create namespace ccplant
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

**注意**: `YOUR_*` の部分は実際の値に置き換えてください。

### 4. values.yaml を使用したインストール

推奨される方法は、values.yaml ファイルを作成して使用することです:

```bash
# values.yaml を作成
cat > values.yaml <<EOF
global:
  hostname: cc.example.com
  apiHostname: cc-api.example.com

  github:
    oauth:
      clientId: YOUR_GITHUB_OAUTH_CLIENT_ID
      clientSecret: YOUR_GITHUB_OAUTH_CLIENT_SECRET

  ingress:
    className: nginx
    tls:
      enabled: true

agentapi-proxy:
  github:
    app:
      id: YOUR_GITHUB_APP_ID
      privateKey:
        secretName: github-app
        key: private-key

agentapi-ui:
  cookieEncryptionSecret:
    enabled: true
    secretName: agentapi-ui-encryption
    secretKey: cookie-encryption-secret
EOF

# Helm でインストール
helm install ccplant oci://ghcr.io/takutakahashi/charts/ccplant \
  --version v0.4.0 \
  --namespace ccplant \
  --values values.yaml
```

### 5. デプロイの確認

```bash
# Pod の状態確認
kubectl get pods -n ccplant

# すべてのリソースの確認
kubectl get all -n ccplant

# Ingress の確認
kubectl get ingress -n ccplant
```

すべての Pod が `Running` 状態になるまで待ちます (通常 1-2 分):

```bash
# Pod の起動を監視
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=ccplant \
  -n ccplant \
  --timeout=300s
```

### 6. アクセス確認

ブラウザで設定したホスト名にアクセスします:

- **フロントエンド**: https://cc.example.com
- **バックエンド API**: https://cc-api.example.com

### 7. ログの確認

```bash
# バックエンドのログ
kubectl logs -f deployment/ccplant-agentapi-proxy -n ccplant

# フロントエンドのログ
kubectl logs -f deployment/ccplant-agentapi-ui -n ccplant

# すべてのログを tail
kubectl logs -f -l app.kubernetes.io/instance=ccplant -n ccplant
```

### トラブルシューティング

**Pod が起動しない場合**

```bash
# Pod の詳細を確認
kubectl describe pod -l app.kubernetes.io/instance=ccplant -n ccplant

# イベントを確認
kubectl get events -n ccplant --sort-by='.lastTimestamp'
```

**Ingress が動作しない場合**

```bash
# Ingress の詳細を確認
kubectl describe ingress -n ccplant

# Ingress Controller のログを確認
kubectl logs -f -n ingress-nginx -l app.kubernetes.io/component=controller
```

**Secret が見つからない場合**

```bash
# Secret の存在確認
kubectl get secrets -n ccplant

# Secret の内容確認
kubectl describe secret github-app -n ccplant
kubectl describe secret agentapi-ui-encryption -n ccplant
```

### アンインストール

```bash
# Helm リリースの削除
helm uninstall ccplant -n ccplant

# Namespace の削除 (Secret も含めて完全削除)
kubectl delete namespace ccplant
```

## 次のステップ

クイックスタートで基本的な動作を確認したら、以下のドキュメントで詳細な設定を行ってください:

### Docker Compose を使用している場合

- [Docker Compose デプロイガイド](./docker-compose.md) - 詳細な設定とカスタマイズ
- [設定ガイド](./configuration.md) - 環境変数と設定のベストプラクティス

### Helm を使用している場合

- [Kubernetes デプロイガイド](./kubernetes.md) - Kubernetes への詳細なデプロイ手順
- [Helm Chart ガイド](./helm-chart.md) - Helm チャートの詳細設定とカスタマイズ
- [設定ガイド](./configuration.md) - values.yaml の詳細設定とベストプラクティス

### 共通

- [トラブルシューティング](./troubleshooting.md) - よくある問題と解決方法
- [運用ガイド](../operations/monitoring.md) - モニタリングとメンテナンス
- [セキュリティガイド](../operations/security.md) - セキュリティのベストプラクティス

## よくある質問

### Q: GitHub OAuth の設定はどこで行いますか?

A: GitHub の Developer Settings から OAuth App を作成します:

1. GitHub にログイン
2. Settings → Developer settings → OAuth Apps
3. "New OAuth App" をクリック
4. Application name: `ccplant`
5. Homepage URL: `https://cc.example.com`
6. Authorization callback URL: `https://cc.example.com/api/auth/callback/github`

詳細は[設定ガイド](./configuration.md#github-oauth-設定)を参照してください。

### Q: GitHub App の設定はどこで行いますか?

A: GitHub の Developer Settings または Organization Settings から GitHub App を作成します:

1. GitHub にログイン
2. Settings → Developer settings → GitHub Apps
3. "New GitHub App" をクリック
4. 必要な権限とイベントを設定

詳細は[GitHub 統合ガイド](../backend/github-integration.md)を参照してください。

### Q: TLS/HTTPS を設定するにはどうすればいいですか?

A: Kubernetes では cert-manager と Let's Encrypt を使用して自動的に TLS 証明書を取得できます。詳細は[設定ガイド](./configuration.md#tlshttps-設定)を参照してください。

### Q: リソース要件はどのくらいですか?

A: 最小構成:
- CPU: 1 コア (0.5 コア backend + 0.2 コア frontend + 0.3 コア overhead)
- メモリ: 1GB (512MB backend + 256MB frontend + 256MB overhead)

本番環境の推奨構成については[設定ガイド](./configuration.md#リソース設定)を参照してください。

### Q: データの永続化は必要ですか?

A: ccplant はステートレスなアプリケーションですが、セッション Pod が永続ボリュームを使用する場合があります。詳細は[Kubernetes セッション管理](../backend/kubernetes-sessions.md)を参照してください。
