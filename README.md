# Glue Crawler


```bash
aws glue start-crawler --name curated-device-telemetry-crawler


```




```sql
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
terraform init -backend-config=../../backend/backend.hcl

# 差分確認
terraform plan -var="stage=prod"

# 変更適用（差分を確認してから実行）
terraform apply -var="stage=prod"
```

環境を追加する場合は `terraform/envs/<stage>` を作成し、対象 stage の `-var="stage=<stage>"` を指定してください。
