# バックアップとリカバリ

ccplant プロジェクトのデータ保護、バックアップ、災害復旧の完全ガイドです。

## 目次

- [概要](#概要)
- [バックアップ対象](#バックアップ対象)
- [バックアップ戦略](#バックアップ戦略)
- [Velero によるクラスターバックアップ](#velero-によるクラスターバックアップ)
- [Secret のバックアップ](#secret-のバックアップ)
- [PVC データのバックアップ](#pvc-データのバックアップ)
- [リストア手順](#リストア手順)
- [災害復旧計画](#災害復旧計画)
- [テストとドリル](#テストとドリル)

## 概要

### バックアップの重要性

ccplant では以下のデータを保護する必要があります:

```
┌─────────────────────────────────────────────┐
│  データ層                                    │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │  1. Kubernetes リソース              │   │
│  │     - Secret (認証情報)              │   │
│  │     - ConfigMap (設定)               │   │
│  │     - Deployment/Service             │   │
│  └──────────────────────────────────────┘   │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │  2. 永続データ (PVC)                 │   │
│  │     - セッションデータ               │   │
│  │     - ユーザーデータ                 │   │
│  └──────────────────────────────────────┘   │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │  3. 設定ファイル                      │   │
│  │     - Helm values.yaml               │   │
│  │     - 認証設定                        │   │
│  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

### バックアップの原則

- **3-2-1 ルール**: 3つのコピー、2つの異なる媒体、1つはオフサイト
- **自動化**: 手動に頼らない自動バックアップ
- **検証**: バックアップの整合性を定期的に確認
- **暗号化**: バックアップデータの暗号化
- **保持期間**: 適切なバックアップ保持ポリシー

## バックアップ対象

### 1. Kubernetes リソース

#### Secret

```bash
# Secret の一覧
kubectl get secrets -n ccplant

# 重要な Secret
- github-oauth          # GitHub OAuth 認証情報
- github-app            # GitHub App Private Key
- agentapi-ui-encryption # Cookie 暗号化キー
- ccplant-api-keys      # API キー
- ccplant-frontend-tls  # TLS 証明書
- ccplant-backend-tls   # TLS 証明書
```

#### ConfigMap

```bash
# ConfigMap の一覧
kubectl get configmaps -n ccplant

# 重要な ConfigMap
- ccplant-auth-config      # 認証・認可設定
- ccplant-app-config       # アプリケーション設定
```

#### その他のリソース

```bash
- Deployment
- Service
- Ingress
- ServiceAccount
- Role/RoleBinding
- NetworkPolicy
```

### 2. 永続データ (PVC)

```bash
# PVC の一覧
kubectl get pvc -n ccplant

# バックアップが必要な PVC
- session-data-pvc     # セッションデータ
- user-data-pvc        # ユーザーデータ
```

### 3. Helm Chart 設定

```
- charts/ccplant/values.yaml
- カスタム values ファイル
- Chart.yaml
```

## バックアップ戦略

### バックアップスケジュール

| バックアップ対象 | 頻度 | 保持期間 | 優先度 |
|----------------|------|---------|--------|
| Secret | 毎日 | 30日 | 高 |
| ConfigMap | 毎日 | 30日 | 高 |
| PVC データ | 毎日 | 7日 | 中 |
| クラスター全体 | 毎週 | 4週間 | 高 |
| Helm 設定 | Git で管理 | 無制限 | 高 |

### RPO (Recovery Point Objective)

```
- Secret/ConfigMap: 24時間
- PVC データ: 24時間
- クラスター設定: 1週間
```

### RTO (Recovery Time Objective)

```
- 緊急度高: 1時間以内
- 緊急度中: 4時間以内
- 緊急度低: 24時間以内
```

## Velero によるクラスターバックアップ

### Velero のインストール

```bash
# Velero CLI をインストール
brew install velero  # macOS
# または
wget https://github.com/vmware-tanzu/velero/releases/download/v1.12.0/velero-v1.12.0-linux-amd64.tar.gz
tar -xvf velero-v1.12.0-linux-amd64.tar.gz
sudo mv velero-v1.12.0-linux-amd64/velero /usr/local/bin/

# Velero をクラスターにインストール (AWS S3 の例)
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket ccplant-backups \
  --backup-location-config region=us-east-1 \
  --snapshot-location-config region=us-east-1 \
  --secret-file ./credentials-velero

# credentials-velero の内容
# [default]
# aws_access_key_id=YOUR_ACCESS_KEY
# aws_secret_access_key=YOUR_SECRET_KEY
```

### 手動バックアップ

```bash
# 特定の Namespace をバックアップ
velero backup create ccplant-backup \
  --include-namespaces ccplant \
  --wait

# すべてのリソースをバックアップ
velero backup create cluster-backup \
  --wait

# 特定のリソースタイプのみバックアップ
velero backup create secrets-backup \
  --include-namespaces ccplant \
  --include-resources secrets \
  --wait

# バックアップの確認
velero backup describe ccplant-backup
velero backup logs ccplant-backup
```

### 自動バックアップスケジュール

```bash
# 毎日バックアップ (午前2時)
velero schedule create ccplant-daily \
  --schedule="0 2 * * *" \
  --include-namespaces ccplant \
  --ttl 720h  # 30日間保持

# 毎週バックアップ (日曜午前3時)
velero schedule create ccplant-weekly \
  --schedule="0 3 * * 0" \
  --include-namespaces ccplant \
  --ttl 2160h  # 90日間保持

# スケジュールの確認
velero schedule get
```

### バックアップの検証

```bash
# バックアップ一覧
velero backup get

# バックアップの詳細
velero backup describe ccplant-backup --details

# バックアップのダウンロード (オフライン保存)
velero backup download ccplant-backup
```

## Secret のバックアップ

### 手動バックアップ

```bash
# すべての Secret をバックアップ
kubectl get secrets -n ccplant -o yaml > secrets-backup-$(date +%Y%m%d).yaml

# 特定の Secret をバックアップ
kubectl get secret github-oauth -n ccplant -o yaml > github-oauth-backup.yaml
kubectl get secret github-app -n ccplant -o yaml > github-app-backup.yaml
kubectl get secret agentapi-ui-encryption -n ccplant -o yaml > agentapi-ui-encryption-backup.yaml

# Base64 デコードして保存 (監査用)
mkdir -p secret-backups
kubectl get secret github-oauth -n ccplant -o json | \
  jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"' > secret-backups/github-oauth.txt
```

### 暗号化バックアップ

```bash
# GPG で暗号化
kubectl get secrets -n ccplant -o yaml | \
  gpg --encrypt --recipient admin@example.com > secrets-backup-encrypted.yaml.gpg

# 復号化
gpg --decrypt secrets-backup-encrypted.yaml.gpg > secrets-backup.yaml
```

### Sealed Secrets の使用

```bash
# Sealed Secrets Controller をインストール
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Secret を暗号化
kubectl create secret generic github-oauth \
  --from-literal=client-id=xxx \
  --from-literal=client-secret=xxx \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > github-oauth-sealed.yaml

# Git で管理 (暗号化されているので安全)
git add github-oauth-sealed.yaml
git commit -m "backup: add sealed secret for github-oauth"
git push
```

## PVC データのバックアップ

### スナップショットの作成

```bash
# VolumeSnapshot を作成
cat <<EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: session-data-snapshot
  namespace: ccplant
spec:
  volumeSnapshotClassName: csi-aws-vsc
  source:
    persistentVolumeClaimName: session-data-pvc
EOF

# スナップショットの確認
kubectl get volumesnapshot -n ccplant
kubectl describe volumesnapshot session-data-snapshot -n ccplant
```

### Velero による PVC バックアップ

```bash
# PVC を含むバックアップ
velero backup create ccplant-with-volumes \
  --include-namespaces ccplant \
  --snapshot-volumes=true \
  --wait

# 特定の PVC のみバックアップ
velero backup create session-data-backup \
  --include-namespaces ccplant \
  --include-resources pvc,pv \
  --selector app=ccplant \
  --wait
```

### restic による PVC バックアップ

```bash
# Velero に restic を追加
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket ccplant-backups \
  --use-restic \
  --secret-file ./credentials-velero

# restic を使用したバックアップ
velero backup create ccplant-restic-backup \
  --include-namespaces ccplant \
  --default-volumes-to-restic \
  --wait

# バックアップの確認
velero backup describe ccplant-restic-backup --details
```

## リストア手順

### Velero によるリストア

```bash
# 1. バックアップ一覧を確認
velero backup get

# 2. リストアを実行
velero restore create ccplant-restore \
  --from-backup ccplant-backup \
  --wait

# 3. リストア状況を確認
velero restore describe ccplant-restore
velero restore logs ccplant-restore

# 4. リソースの確認
kubectl get all -n ccplant
kubectl get secrets -n ccplant
kubectl get configmaps -n ccplant
kubectl get pvc -n ccplant
```

### 特定のリソースのみリストア

```bash
# Secret のみリストア
velero restore create secrets-restore \
  --from-backup ccplant-backup \
  --include-resources secrets \
  --wait

# 特定の Secret のみリストア
velero restore create github-oauth-restore \
  --from-backup ccplant-backup \
  --include-resources secrets \
  --selector secret=github-oauth \
  --wait
```

### 手動リストア (YAML から)

```bash
# 1. Namespace を作成
kubectl create namespace ccplant

# 2. Secret をリストア
kubectl apply -f secrets-backup.yaml

# 3. ConfigMap をリストア
kubectl apply -f configmaps-backup.yaml

# 4. その他のリソースをリストア
kubectl apply -f deployment-backup.yaml
kubectl apply -f service-backup.yaml
kubectl apply -f ingress-backup.yaml

# 5. 動作確認
kubectl get pods -n ccplant
kubectl get svc -n ccplant
```

### PVC のリストア

```bash
# スナップショットからリストア
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: session-data-pvc-restored
  namespace: ccplant
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  dataSource:
    name: session-data-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
EOF

# PVC の確認
kubectl get pvc -n ccplant
kubectl describe pvc session-data-pvc-restored -n ccplant
```

## 災害復旧計画

### 災害復旧シナリオ

#### シナリオ 1: 単一 Pod の障害

```bash
# 影響: 最小
# RTO: 自動 (数分以内)
# RPO: なし

# 対応: Kubernetes が自動的に再起動
kubectl get pods -n ccplant -w
```

#### シナリオ 2: Namespace の削除

```bash
# 影響: 中
# RTO: 1時間
# RPO: 24時間

# 対応手順:
# 1. Namespace を再作成
kubectl create namespace ccplant

# 2. Velero でリストア
velero restore create ccplant-namespace-restore \
  --from-backup ccplant-daily-20240127 \
  --wait

# 3. 動作確認
kubectl get all -n ccplant
curl https://ccplant.example.com
```

#### シナリオ 3: クラスター全体の障害

```bash
# 影響: 大
# RTO: 4時間
# RPO: 24時間

# 対応手順:
# 1. 新しいクラスターを構築
kubeadm init --config kubeadm-config.yaml

# 2. Velero をインストール
velero install --provider aws --bucket ccplant-backups

# 3. 最新のバックアップをリストア
velero restore create cluster-restore \
  --from-backup cluster-backup-weekly-latest \
  --wait

# 4. DNS を更新
# Ingress の IP を取得して DNS を更新

# 5. 動作確認
kubectl get all --all-namespaces
curl https://ccplant.example.com
```

#### シナリオ 4: データ損失 (PVC)

```bash
# 影響: 大
# RTO: 2時間
# RPO: 24時間

# 対応手順:
# 1. 最新のスナップショットを特定
kubectl get volumesnapshot -n ccplant

# 2. スナップショットから PVC を作成
kubectl apply -f pvc-from-snapshot.yaml

# 3. Pod を再起動して新しい PVC をマウント
kubectl delete pod -n ccplant -l app=ccplant
kubectl get pods -n ccplant -w

# 4. データの整合性を確認
kubectl exec -it <pod-name> -n ccplant -- ls -la /data
```

### 災害復旧手順書

```markdown
# 災害復旧手順書

## 1. 初動対応
- [ ] インシデントの発生を確認
- [ ] 影響範囲を特定
- [ ] 関係者に通知
- [ ] 復旧チームを招集

## 2. 影響評価
- [ ] サービスの停止状況を確認
- [ ] データ損失の有無を確認
- [ ] バックアップの最新状態を確認

## 3. 復旧作業
- [ ] 復旧シナリオを決定
- [ ] バックアップからリストア
- [ ] 動作確認
- [ ] DNS/ロードバランサーの更新

## 4. 検証
- [ ] すべてのサービスが正常動作
- [ ] データの整合性を確認
- [ ] パフォーマンステスト
- [ ] セキュリティチェック

## 5. 事後対応
- [ ] サービス再開を通知
- [ ] インシデントレポート作成
- [ ] 再発防止策の検討
- [ ] ポストモーテムの実施
```

## テストとドリル

### バックアップの検証

```bash
# 1. テスト用 Namespace を作成
kubectl create namespace ccplant-test

# 2. バックアップからリストア
velero restore create ccplant-test-restore \
  --from-backup ccplant-backup \
  --namespace-mappings ccplant:ccplant-test \
  --wait

# 3. リストアされたリソースを確認
kubectl get all -n ccplant-test

# 4. 動作確認
kubectl port-forward -n ccplant-test svc/ccplant-backend 8080:8080
curl http://localhost:8080/health

# 5. クリーンアップ
kubectl delete namespace ccplant-test
```

### 災害復旧ドリル

```bash
# 四半期ごとに実施

# 1. ドリル計画を作成
# 2. 関係者に通知
# 3. 本番と同等のテスト環境を準備
# 4. バックアップからリストア
# 5. 動作確認
# 6. RTO/RPO を測定
# 7. 結果をドキュメント化
# 8. 改善点を特定
```

### 自動テスト

```bash
# CronJob でバックアップの検証
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-validation
  namespace: ccplant
spec:
  schedule: "0 4 * * 0"  # 毎週日曜午前4時
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: validate
            image: bitnami/kubectl:latest
            command:
            - /bin/bash
            - -c
            - |
              # 最新のバックアップを取得
              LATEST_BACKUP=$(velero backup get --output json | jq -r '.items[0].metadata.name')

              # テスト Namespace にリストア
              velero restore create test-restore-$RANDOM \
                --from-backup $LATEST_BACKUP \
                --namespace-mappings ccplant:ccplant-test \
                --wait

              # 検証
              kubectl wait --for=condition=ready pod -l app=ccplant -n ccplant-test --timeout=300s

              # クリーンアップ
              kubectl delete namespace ccplant-test
          restartPolicy: OnFailure
```

## ベストプラクティス

### 1. バックアップの自動化

```bash
# Velero スケジュールバックアップ
velero schedule create ccplant-hourly \
  --schedule="0 * * * *" \
  --include-namespaces ccplant \
  --ttl 24h

velero schedule create ccplant-daily \
  --schedule="0 2 * * *" \
  --include-namespaces ccplant \
  --ttl 720h

velero schedule create ccplant-weekly \
  --schedule="0 3 * * 0" \
  --include-namespaces ccplant \
  --ttl 2160h
```

### 2. バックアップの暗号化

```bash
# バックアップストレージの暗号化 (S3)
aws s3api put-bucket-encryption \
  --bucket ccplant-backups \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

### 3. オフサイトバックアップ

```bash
# 別のリージョンにレプリケーション
aws s3api put-bucket-replication \
  --bucket ccplant-backups \
  --replication-configuration file://replication.json

# replication.json
{
  "Role": "arn:aws:iam::123456789012:role/replication-role",
  "Rules": [{
    "Status": "Enabled",
    "Priority": 1,
    "Destination": {
      "Bucket": "arn:aws:s3:::ccplant-backups-dr",
      "ReplicationTime": {
        "Status": "Enabled",
        "Time": {
          "Minutes": 15
        }
      }
    }
  }]
}
```

### 4. バックアップの監視

```bash
# Prometheus AlertRule
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: velero-alerts
  namespace: velero
spec:
  groups:
  - name: velero
    rules:
    - alert: VeleroBackupFailed
      expr: velero_backup_failure_total > 0
      for: 5m
      annotations:
        summary: "Velero backup failed"
        description: "Backup {{ $labels.schedule }} failed"
```

## 参考リンク

- [Velero Documentation](https://velero.io/docs/)
- [Kubernetes Backup Best Practices](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#backing-up-an-etcd-cluster)
- [Disaster Recovery Planning](https://cloud.google.com/architecture/dr-scenarios-planning-guide)
