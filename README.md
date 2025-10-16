# Datastreamer Infrastructure

## Overview

このリポジトリは、IoT 温度テレメトリを収集・加工する AWS ベースのデータパイプラインを Terraform で管理します。Kinesis Data Stream に流れ込んだイベントを Firehose で S3（Raw）に蓄積し、Glue Job が ETL を実行して Analytics バケットへ加工データを出力します。Glue Crawler は 1 時間おきにカタログを更新し、Athena/Redshift Spectrum からの分析を支援します。

## Architecture

- **Kinesis Data Stream** `datastreamer-<stage>-stream`  
  センサークライアント (`sensor.py`) が送信する温度データを受信。
- **Kinesis Firehose Delivery Stream** `datastreamer-<stage>-firehose`  
  Stream から Raw データバケット `s3://<data-bucket>/raw_data/device_sensor/` へ圧縮転送。
- **S3 Buckets**  
  - `datastreamer-<stage>-data-bucket-*` (raw)  
  - `datastreamer-<stage>-analytics-bucket-*` (curated)
- **Glue Job** `datastreamer-<stage>-temperature-etl`  
  EventBridge Scheduler (`rate(15 minutes)`) が `StartJobRun` を発行。脚本は `terraform/templates/glue-job/temperature_etl.py`。
- **Glue Crawler** `datastreamer-<stage>-curated-device-telemetry`  
  Analytics バケットを対象に 1 時間おき (`cron(0 * * * ? *)`) にカタログ更新。
- **IAM**  
  各モジュール内でロール／ポリシーを定義。`PROJECT=datastreamer`, `STAGE=<stage>` タグを共通付与。

### Naming & State

- 命名規則: `datastreamer-<stage>-<resource>`
- Terraform state: `s3://tfstate-store-a5gnpkub/datastreamer/<stage>/terraform.tfstate`, `use_lockfile = true`
- リージョン: `ap-northeast-1`
- 認証: Devcontainer の EC2 インスタンスプロファイル (AdministratorAccess)

```bash
# Glue Crawler を手動起動したい場合
aws glue start-crawler --name datastreamer-prod-curated-device-telemetry
```

```sql
# Athena 例: 当日の平均温度
SELECT device_id, AVG(temperature) AS avg_temp
FROM device_telemetry
WHERE year='2025' AND month='10' AND day='15'
GROUP BY device_id
ORDER BY avg_temp DESC;
```

## Terraform

Terraform の操作は Git リポジトリ内の `terraform/envs/production` で実行します。

```bash
cd terraform/envs/production

# 依存モジュールとバックエンドの初期化
terraform init

# 差分確認
terraform plan

# 変更適用（差分を確認してから実行）
terraform apply -auto-approve

# EventBridge Scheduler, Glue, Firehose などを含む構成が作成されます
```

環境を追加する場合は `terraform/envs/<stage>` を作成し、対象 stage の `-var="stage=<stage>"` を指定してください。

### Terraform ディレクトリ構成

```
terraform/
├── backend/             # backend.hcl 共通化
├── envs/
│   ├── production/      # 環境別エントリポイント
│   └── staging/
└── modules/
    ├── firehose_delivery_stream/
    ├── glue_crawler/
    ├── glue_job/
    ├── kinesis_stream/
    └── s3_bucket/
```

## Operational Notes

- **Glue Job スケジュール**: EventBridge Scheduler (`aws_scheduler_schedule`) が 15 分間隔で `StartJobRun` を実行。
- **Glue Crawler スケジュール**: `cron(0 * * * ? *)` で 1 時間おきに実行。必要に応じて `module "glue_crawler"` の `schedule` を調整。
- **Sensor CLI**: テストデータ送信には `script/sensor.sh` を利用します。

```bash
# Kinesis へ模擬データ送信
./script/sensor.sh prod   # Ctrl+C で停止
```

- **Glue Job スクリプト編集**: `terraform/templates/glue-job/temperature_etl.py` を更新後、`terraform apply` で再デプロイすると S3 にアップロードされます。
- **Secrets**: 秘密情報は AWS Secrets Manager に保管する運用を想定（Terraform モジュールから参照する場合はキー名を指定）。

## Next Steps

- `terraform plan` ⇒ `apply` で本番環境へ反映
- 必要に応じて `staging` 環境を `terraform/envs/staging` に追加
- GitHub Actions で `fmt → init → validate → plan → (手動) apply` パイプラインを構築
