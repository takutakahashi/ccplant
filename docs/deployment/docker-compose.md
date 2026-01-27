# Docker Compose デプロイガイド

Docker Compose を使用して ccplant をローカル環境またはシンプルなサーバー環境にデプロイする完全ガイドです。

## 目次

- [概要](#概要)
- [前提条件](#前提条件)
- [基本的なデプロイ](#基本的なデプロイ)
- [docker-compose.yaml の構造](#docker-composeyaml-の構造)
- [サービス設定](#サービス設定)
- [リソース制限](#リソース制限)
- [ネットワーク設定](#ネットワーク設定)
- [環境変数の設定](#環境変数の設定)
- [ボリュームとデータ永続化](#ボリュームとデータ永続化)
- [ヘルスチェック](#ヘルスチェック)
- [ログ管理](#ログ管理)
- [本番環境での使用](#本番環境での使用)
- [トラブルシューティング](#トラブルシューティング)

## 概要

Docker Compose を使用した ccplant のデプロイは、以下のような場合に適しています:

- **開発環境**: ローカルでの開発とテスト
- **小規模デプロイ**: 単一サーバーでの小規模運用
- **プロトタイプ**: 概念実証や評価環境
- **CI/CD**: 統合テスト環境

本番環境での大規模なデプロイには [Kubernetes デプロイ](./kubernetes.md)を推奨します。

## 前提条件

### システム要件

- **OS**: Linux、macOS、Windows (WSL2)
- **Docker Engine**: 20.10 以上
- **Docker Compose**: v2.0 以上
- **メモリ**: 最低 2GB、推奨 4GB 以上
- **CPU**: 最低 2 コア、推奨 4 コア以上
- **ディスク**: 最低 10GB の空き容量

### インストール確認

```bash
# Docker のバージョン確認
docker --version
# 出力例: Docker version 24.0.7, build afdd53b

# Docker Compose のバージョン確認
docker compose version
# 出力例: Docker Compose version v2.23.0

# Docker が正常に動作しているか確認
docker run hello-world
```

## 基本的なデプロイ

### 1. リポジトリのクローン

```bash
# リポジトリをクローン
git clone https://github.com/takutakahashi/ccplant.git
cd ccplant
```

### 2. サービスの起動

```bash
# バックグラウンドで起動
docker compose up -d

# フォアグラウンドで起動 (ログを表示)
docker compose up

# 特定のサービスのみ起動
docker compose up -d backend
```

### 3. 起動確認

```bash
# コンテナの状態を確認
docker compose ps

# 期待される出力:
# NAME                  IMAGE                                         STATUS
# ccplant-backend       ghcr.io/takutakahashi/agentapi-proxy:latest   Up
# ccplant-frontend      ghcr.io/takutakahashi/agentapi-ui:latest      Up
```

### 4. アクセス確認

```bash
# バックエンドのヘルスチェック
curl http://localhost:8080/health

# フロントエンドのアクセス確認
curl http://localhost:3000/

# ブラウザでアクセス
# フロントエンド: http://localhost:3000
# バックエンド API: http://localhost:8080
```

## docker-compose.yaml の構造

ccplant の `docker-compose.yaml` は以下の構造になっています:

```yaml
version: '3.8'

services:
  # バックエンドサービス (agentapi-proxy)
  backend:
    image: ghcr.io/takutakahashi/agentapi-proxy:latest
    container_name: ccplant-backend
    restart: unless-stopped
    ports:
      - "8080:8080"
    networks:
      - ccplant-network
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.1'
          memory: 128M
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  # フロントエンドサービス (agentapi-ui)
  frontend:
    image: ghcr.io/takutakahashi/agentapi-ui:latest
    container_name: ccplant-frontend
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - API_URL=http://backend:8080
    depends_on:
      - backend
    networks:
      - ccplant-network
    deploy:
      resources:
        limits:
          cpus: '0.2'
          memory: 256M
        reservations:
          cpus: '0.05'
          memory: 64M
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

networks:
  ccplant-network:
    driver: bridge

volumes:
  # 必要に応じて永続化ボリュームを追加
```

## サービス設定

### Backend (agentapi-proxy)

バックエンド API サーバーの設定です。

```yaml
backend:
  image: ghcr.io/takutakahashi/agentapi-proxy:latest
  container_name: ccplant-backend
  restart: unless-stopped
  ports:
    - "8080:8080"
  environment:
    # GitHub 設定
    - GITHUB_OAUTH_CLIENT_ID=${GITHUB_OAUTH_CLIENT_ID}
    - GITHUB_OAUTH_CLIENT_SECRET=${GITHUB_OAUTH_CLIENT_SECRET}
    - GITHUB_APP_ID=${GITHUB_APP_ID}
    - GITHUB_APP_PRIVATE_KEY=${GITHUB_APP_PRIVATE_KEY}

    # 認証設定
    - AUTH_ENABLED=true
    - AUTH_GITHUB_ENABLED=true

    # データベース設定 (必要に応じて)
    - DB_HOST=postgres
    - DB_PORT=5432
    - DB_NAME=ccplant
    - DB_USER=ccplant
    - DB_PASSWORD=${DB_PASSWORD}
  volumes:
    # GitHub App 秘密鍵のマウント (ファイルから読み込む場合)
    - ./secrets/github-app-private-key.pem:/secrets/github-app-private-key.pem:ro
  networks:
    - ccplant-network
```

### Frontend (agentapi-ui)

フロントエンド Web UI の設定です。

```yaml
frontend:
  image: ghcr.io/takutakahashi/agentapi-ui:latest
  container_name: ccplant-frontend
  restart: unless-stopped
  ports:
    - "3000:3000"
  environment:
    # Node.js 環境
    - NODE_ENV=production

    # バックエンド API の URL
    - API_URL=http://backend:8080
    - NEXT_PUBLIC_API_URL=http://localhost:8080

    # 認証設定
    - AUTH_MODE=oauth_only

    # クッキー暗号化
    - COOKIE_ENCRYPTION_SECRET=${COOKIE_ENCRYPTION_SECRET}

    # GitHub OAuth
    - GITHUB_CLIENT_ID=${GITHUB_OAUTH_CLIENT_ID}
    - GITHUB_CLIENT_SECRET=${GITHUB_OAUTH_CLIENT_SECRET}

    # UI カスタマイズ
    - LOGIN_TITLE=ccplant
    - LOGIN_DESCRIPTION=Welcome to ccplant
  depends_on:
    backend:
      condition: service_healthy
  networks:
    - ccplant-network
```

## リソース制限

リソース制限を適切に設定することで、システムの安定性を向上させます。

### CPU 制限

```yaml
deploy:
  resources:
    limits:
      cpus: '0.5'        # 最大 0.5 コア使用可能
    reservations:
      cpus: '0.1'        # 最低 0.1 コア保証
```

### メモリ制限

```yaml
deploy:
  resources:
    limits:
      memory: 512M       # 最大 512MB 使用可能
    reservations:
      memory: 128M       # 最低 128MB 保証
```

### 推奨リソース設定

#### 開発環境

```yaml
backend:
  deploy:
    resources:
      limits:
        cpus: '0.5'
        memory: 512M
      reservations:
        cpus: '0.1'
        memory: 128M

frontend:
  deploy:
    resources:
      limits:
        cpus: '0.2'
        memory: 256M
      reservations:
        cpus: '0.05'
        memory: 64M
```

#### 本番環境

```yaml
backend:
  deploy:
    resources:
      limits:
        cpus: '2.0'
        memory: 2G
      reservations:
        cpus: '0.5'
        memory: 512M

frontend:
  deploy:
    resources:
      limits:
        cpus: '1.0'
        memory: 1G
      reservations:
        cpus: '0.25'
        memory: 256M
```

## ネットワーク設定

### 基本的なネットワーク

```yaml
networks:
  ccplant-network:
    driver: bridge
```

### カスタムサブネット

```yaml
networks:
  ccplant-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16
          gateway: 172.28.0.1
```

### 外部ネットワークの使用

既存のネットワークを使用する場合:

```yaml
networks:
  ccplant-network:
    external: true
    name: existing-network
```

### ポート変更

デフォルトポートが使用中の場合:

```yaml
services:
  backend:
    ports:
      - "18080:8080"  # ホスト側を 18080 に変更

  frontend:
    ports:
      - "13000:3000"  # ホスト側を 13000 に変更
    environment:
      - API_URL=http://backend:8080         # コンテナ間通信は変更不要
      - NEXT_PUBLIC_API_URL=http://localhost:18080  # ブラウザからのアクセスは変更
```

## 環境変数の設定

### .env ファイルの使用

`.env` ファイルを作成して環境変数を管理します:

```bash
# .env ファイルの作成
cat > .env <<EOF
# GitHub OAuth 設定
GITHUB_OAUTH_CLIENT_ID=your_oauth_client_id
GITHUB_OAUTH_CLIENT_SECRET=your_oauth_client_secret

# GitHub App 設定
GITHUB_APP_ID=123456
GITHUB_APP_PRIVATE_KEY_PATH=./secrets/github-app-private-key.pem

# セキュリティ設定
COOKIE_ENCRYPTION_SECRET=$(openssl rand -base64 32)

# データベース設定 (オプション)
DB_PASSWORD=$(openssl rand -base64 16)

# ログレベル
LOG_LEVEL=info
EOF
```

### docker-compose.yaml での使用

```yaml
services:
  backend:
    env_file:
      - .env
    environment:
      - GITHUB_OAUTH_CLIENT_ID=${GITHUB_OAUTH_CLIENT_ID}
      - GITHUB_OAUTH_CLIENT_SECRET=${GITHUB_OAUTH_CLIENT_SECRET}
```

### セキュリティ上の注意

```bash
# .env ファイルを .gitignore に追加
echo ".env" >> .gitignore

# .env ファイルのパーミッションを制限
chmod 600 .env
```

## ボリュームとデータ永続化

### Named Volume の作成

```yaml
volumes:
  backend-data:
  postgres-data:

services:
  backend:
    volumes:
      - backend-data:/app/data

  postgres:
    image: postgres:15
    volumes:
      - postgres-data:/var/lib/postgresql/data
```

### Bind Mount の使用

ホストのディレクトリをマウント:

```yaml
services:
  backend:
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
      - ./secrets:/secrets:ro  # 読み取り専用
```

### バックアップ

```bash
# Named Volume のバックアップ
docker run --rm \
  -v ccplant_backend-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/backend-data-backup.tar.gz -C /data .

# リストア
docker run --rm \
  -v ccplant_backend-data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/backend-data-backup.tar.gz -C /data
```

## ヘルスチェック

### Backend のヘルスチェック

```yaml
backend:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
    interval: 30s      # 30秒ごとにチェック
    timeout: 10s       # 10秒でタイムアウト
    retries: 3         # 3回失敗で unhealthy
    start_period: 30s  # 起動後30秒は失敗を無視
```

### Frontend のヘルスチェック

```yaml
frontend:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:3000/"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 30s
```

### ヘルスチェック状態の確認

```bash
# ヘルスチェック状態の確認
docker compose ps

# 詳細な健全性情報
docker inspect ccplant-backend --format='{{.State.Health.Status}}'
docker inspect ccplant-frontend --format='{{.State.Health.Status}}'
```

## ログ管理

### ログの確認

```bash
# すべてのサービスのログ
docker compose logs

# 特定のサービスのログ
docker compose logs backend
docker compose logs frontend

# リアルタイムでログを監視 (-f: follow)
docker compose logs -f

# 最新 100 行のログ
docker compose logs --tail=100

# タイムスタンプ付き
docker compose logs -t
```

### ログの保存

```bash
# ログをファイルに保存
docker compose logs > ccplant-logs.txt

# 日付付きで保存
docker compose logs > ccplant-logs-$(date +%Y%m%d-%H%M%S).txt
```

### ログローテーション設定

```yaml
services:
  backend:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"      # 最大ファイルサイズ
        max-file: "3"        # 保持するファイル数
        compress: "true"     # 古いログを圧縮
```

### Syslog への転送

```yaml
services:
  backend:
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://192.168.1.100:514"
        tag: "ccplant-backend"
```

## 本番環境での使用

### リバースプロキシの設定

#### Nginx の例

```nginx
# /etc/nginx/sites-available/ccplant
server {
    listen 80;
    server_name cc.example.com;

    # HTTPS へリダイレクト
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name cc.example.com;

    ssl_certificate /etc/letsencrypt/live/cc.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/cc.example.com/privkey.pem;

    # フロントエンドへのプロキシ
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # バックエンド API へのプロキシ
    location /api {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

#### Traefik の使用

```yaml
version: '3.8'

services:
  traefik:
    image: traefik:v2.10
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.myresolver.acme.tlschallenge=true"
      - "--certificatesresolvers.myresolver.acme.email=admin@example.com"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
    networks:
      - ccplant-network

  backend:
    image: ghcr.io/takutakahashi/agentapi-proxy:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.backend.rule=Host(`cc-api.example.com`)"
      - "traefik.http.routers.backend.entrypoints=websecure"
      - "traefik.http.routers.backend.tls.certresolver=myresolver"
      - "traefik.http.services.backend.loadbalancer.server.port=8080"
    networks:
      - ccplant-network

  frontend:
    image: ghcr.io/takutakahashi/agentapi-ui:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.frontend.rule=Host(`cc.example.com`)"
      - "traefik.http.routers.frontend.entrypoints=websecure"
      - "traefik.http.routers.frontend.tls.certresolver=myresolver"
      - "traefik.http.services.frontend.loadbalancer.server.port=3000"
    networks:
      - ccplant-network
```

### 自動再起動設定

```yaml
services:
  backend:
    restart: unless-stopped  # 手動停止以外は常に再起動
    # または
    restart: always          # 常に再起動
    # または
    restart: on-failure      # 失敗時のみ再起動
```

### セキュリティ強化

```yaml
services:
  backend:
    # 読み取り専用ルートファイルシステム
    read_only: true

    # 一時ファイル用の tmpfs
    tmpfs:
      - /tmp
      - /var/run

    # 特権の削除
    privileged: false

    # ユーザー指定
    user: "1000:1000"

    # Capability の制限
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
```

## トラブルシューティング

### コンテナが起動しない

```bash
# コンテナの状態を詳細に確認
docker compose ps -a

# ログを確認
docker compose logs backend
docker compose logs frontend

# 個別のコンテナを調査
docker inspect ccplant-backend
```

### イメージのプルエラー

```bash
# 認証が必要な場合はログイン
docker login ghcr.io

# イメージを手動でプル
docker pull ghcr.io/takutakahashi/agentapi-proxy:latest
docker pull ghcr.io/takutakahashi/agentapi-ui:latest

# キャッシュをクリアして再プル
docker compose pull --no-cache
```

### ポート競合

```bash
# ポートの使用状況を確認
sudo lsof -i :8080
sudo lsof -i :3000

# または
sudo netstat -tulpn | grep 8080
sudo netstat -tulpn | grep 3000

# ポート番号を変更
# docker-compose.yaml の ports セクションを編集
```

### ネットワーク接続エラー

```bash
# ネットワークの確認
docker network ls
docker network inspect ccplant_ccplant-network

# ネットワークの再作成
docker compose down
docker network prune
docker compose up -d
```

### リソース不足

```bash
# Docker のリソース使用状況
docker stats

# システムリソースの確認
free -h
df -h

# 未使用リソースのクリーンアップ
docker system prune -a
docker volume prune
```

### ヘルスチェック失敗

```bash
# ヘルスチェックコマンドを手動実行
docker exec ccplant-backend curl -f http://localhost:8080/health

# コンテナ内でデバッグ
docker exec -it ccplant-backend sh
# コンテナ内で
curl http://localhost:8080/health
netstat -tulpn
```

### 環境変数が反映されない

```bash
# 環境変数を確認
docker compose config

# コンテナ内の環境変数を確認
docker exec ccplant-backend env

# .env ファイルの再読み込み
docker compose down
docker compose up -d
```

### データが永続化されない

```bash
# ボリュームの確認
docker volume ls
docker volume inspect ccplant_backend-data

# ボリュームのマウント確認
docker inspect ccplant-backend --format='{{json .Mounts}}' | jq
```

### パフォーマンス問題

```bash
# リソース使用状況のモニタリング
docker stats --no-stream

# ログサイズの確認
docker system df

# リソース制限の調整
# docker-compose.yaml の deploy.resources を編集
```

## 次のステップ

- [設定ガイド](./configuration.md) - 詳細な設定とカスタマイズ
- [Kubernetes デプロイ](./kubernetes.md) - 本番環境でのスケーラブルなデプロイ
- [トラブルシューティング](./troubleshooting.md) - より詳細な問題解決
- [運用ガイド](../operations/monitoring.md) - モニタリングとメンテナンス
