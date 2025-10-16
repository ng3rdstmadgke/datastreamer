了解。ここまで一緒に作ってきた内容を、ゼロから本番運用まで見据えた**詳細版の手順書**としてまとめます。
（東京タイムゾーン／ap-northeast-1前提。必要に応じてリージョン名・バケット名は置き換えてください。）

---

# 0. ゴール（何ができる？）

* Producer（IoT/アプリ）が **Kinesis Data Streams** にJSONを流す
* **Kinesis Data Firehose** が S3（raw）へ **バッファ転送 + 圧縮**
* **AWS Glue（PySpark）** が **ジョブブックマーク有効**の **増分ETL** で **Parquet**（Snappy）に変換（`year/month/day` パーティション）
* **Glue Crawler** が Data Catalog に登録
* **Athena** で安い・速いクエリ（パーティションプルーニング）
  -（任意）**EventBridge** で定期実行、**QuickSight** で可視化

---

# 1. 事前準備（命名・ネットワーク・IAM）

## 1-1. 命名・S3バケット

* 原則として用途別に分離：

  * `temperature-data-bucket`（raw）
  * `temperature-analytics-bucket`（curated / dlq / query-results 等）
* S3 バケット作成（バージョニングON推奨／ブロックパブリックアクセスON／暗号化SSE-S3またはSSE-KMS）

```bash
aws s3api create-bucket \
  --bucket temperature-data-bucket \
  --create-bucket-configuration LocationConstraint=ap-northeast-1

aws s3api put-bucket-versioning \
  --bucket temperature-data-bucket \
  --versioning-configuration Status=Enabled
```

> **ポイント**
>
> * Athenaの結果保存用に `s3://temperature-analytics-bucket/athena-results/` を用意
> * KMSを使う場合は、Kinesis・Firehose・Glue・AthenaロールにKMS権限を付与

## 1-2. IAM ロール（最小権限の考え方）

* **Producer 側**（EC2/Lambda/ECS等）：Kinesis Put 権限
* **Firehose ロール**：Kinesis 読み取り + S3 書き込み
* **Glue ジョブ実行ロール**：S3 読み書き、Glue Catalog、CloudWatch Logs
* **Crawler ロール**：S3 読み取り、Glue Catalog

最小例（抜粋・概略）

```json
// Producer（Kinesis put）
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow",
      "Action": ["kinesis:PutRecord","kinesis:PutRecords"],
      "Resource": "arn:aws:kinesis:ap-northeast-1:<ACCOUNT_ID>:stream/temperature-stream"
    }
  ]
}
```

```json
// Firehose ロールのS3書き込み（rawバケット）
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow",
      "Action": ["s3:AbortMultipartUpload","s3:GetBucketLocation","s3:GetObject","s3:ListBucket","s3:ListBucketMultipartUploads","s3:PutObject"],
      "Resource": [
        "arn:aws:s3:::temperature-data-bucket",
        "arn:aws:s3:::temperature-data-bucket/*"
      ]
    }
  ]
}
```

```json
// Glue ジョブ（raw 読み、curated 書き、Catalog 参照・更新）
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow",
      "Action": ["s3:GetObject","s3:ListBucket"],
      "Resource": ["arn:aws:s3:::temperature-data-bucket","arn:aws:s3:::temperature-data-bucket/*"]
    },
    { "Effect": "Allow",
      "Action": ["s3:PutObject","s3:AbortMultipartUpload","s3:ListBucket"],
      "Resource": ["arn:aws:s3:::temperature-analytics-bucket","arn:aws:s3:::temperature-analytics-bucket/*"]
    },
    { "Effect": "Allow",
      "Action": ["glue:*Database*","glue:*Table*","glue:CreateTable","glue:UpdateTable","glue:GetTable","glue:GetTables"],
      "Resource": "*"
    },
    { "Effect": "Allow",
      "Action": ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],
      "Resource": "*"
    }
  ]
}
```

---

# 2. Kinesis Data Streams（受け口）

## 2-1. ストリーム作成

```bash
aws kinesis create-stream \
  --stream-name temperature-stream \
  --shard-count 1
```

* **シャード設計**：1シャード ≈ 書込 1MB/s or 1000rec/s / 読取 2MB/s
* デバイス台数・レコードサイズ・頻度から逆算（足りなければスケールアウト）

## 2-2. Producer（送信サンプル / Python）

```python
import boto3, json, random, time
kinesis = boto3.client("kinesis", region_name="ap-northeast-1")

while True:
    rec = {
        "device_id": f"sensor-{random.randint(1,5)}",
        "temperature": round(random.uniform(15, 30), 2),
        "timestamp": time.time()  # UNIX秒
    }
    kinesis.put_record(
        StreamName="temperature-stream",
        Data=json.dumps(rec),
        PartitionKey=rec["device_id"]  # シャーディングキー
    )
    time.sleep(1)
```

---

# 3. Kinesis Data Firehose（S3 raw への自動転送）

## 3-1. Delivery Stream 作成

```bash
aws firehose create-delivery-stream \
  --delivery-stream-name temperature-to-s3 \
  --delivery-stream-type KinesisStreamAsSource \
  --kinesis-stream-source-configuration RoleARN=arn:aws:iam::<ACCOUNT_ID>:role/KinesisFirehoseRole, \
                                        KinesisStreamARN=arn:aws:kinesis:ap-northeast-1:<ACCOUNT_ID>:stream/temperature-stream \
  --s3-destination-configuration RoleARN=arn:aws:iam::<ACCOUNT_ID>:role/KinesisFirehoseRole, \
                                 BucketARN=arn:aws:s3:::temperature-data-bucket, \
                                 Prefix="raw_data/", \
                                 BufferingHints={IntervalInSeconds=60,SizeInMBs=5}, \
                                 CompressionFormat=GZIP
```

* **BufferingHints**：1分 or 5MB 到達で出力（遅延 vs ファイル数のトレードオフ）
* **出力形式**：GZIP JSON Lines（1行1レコード）

**S3レイアウト例**

```
s3://temperature-data-bucket/raw_data/2025/10/15/12/temperature-2025-10-15-12-30.gz
```

---

# 4. Glue ジョブ（増分ETL：JSON→Parquet, append）

## 4-1. 目的

* Firehose の raw（JSON）をクレンジング・正規化
* `year/month/day` パーティションの **Parquet（Snappy）** に変換
* **Job Bookmark 有効**で **新規ファイルのみ処理**（append運用）

## 4-2. スクリプト（完成版）

> 先ほど提示した「**ジョブブックマーク有効＋append**」サンプルをそのまま使えます。
> 主要ポイントだけ再掲：

* `job.init(..., enableJobBookmark=True)`
* 入力は `create_dynamic_frame_from_options(connection_type="s3", format="json")`
* 不正行をDLQへ（任意）
* `.write.mode("append").partitionBy("year","month","day").format("parquet")`

💡 **パーティションの切り方（UTC/JST）** は最初に決めて統一。
JSTで切る場合：`from_utc_timestamp(col("event_time"), 'Asia/Tokyo')` などで派生列を作成。

## 4-3. Glue ジョブ パラメータ例

```bash
--SOURCE_S3 s3://temperature-data-bucket/raw_data/
--TARGET_S3 s3://temperature-analytics-bucket/curated/device_telemetry/
--DLQ_S3    s3://temperature-analytics-bucket/dlq/raw_json/
```

## 4-4. 実行環境

* Glue Version: **4.0**
* Worker Type: G.1X / G.2X（データ量次第）
* 最大同時実行や DPU も要件に合わせて調整

## 4-5. Job Bookmark の運用

* **有効化**：ジョブ設定 or `job.init(..., enableJobBookmark=True)`
* **再処理したい**：コンソールの「ブックマークをリセット」→ 再実行
* **常時append** を基本にし、overwriteは避ける（重複や不整合の温床）

---

# 5. Glue Crawler（Catalog 登録）

## 5-1. Crawler 設定

* 対象パス：`s3://temperature-analytics-bucket/curated/device_telemetry/`
* データ形式：Parquet（自動検出）
* パーティション列：`year`, `month`, `day`（自動）

## 5-2. 実行

* Crawler 実行 → Glue Data Catalog にテーブル作成（例：`device_telemetry`）

---

# 6. Athena（分析・検証）

## 6-1. 設定

* クエリ結果出力先：`s3://temperature-analytics-bucket/athena-results/` を設定
* Database：Crawlerが作ったDBを選択

## 6-2. 代表クエリ

```sql
-- 直近日のデバイス別平均温度（パーティション絞り込みを徹底）
SELECT device_id, AVG(temperature) AS avg_temp
FROM device_telemetry
WHERE year=2025 AND month=10 AND day=15
GROUP BY device_id
ORDER BY avg_temp DESC;
```

> **パーティションプルーニング**（`WHERE year=... AND month=... AND day=...`）でスキャン量を最小化。
> **JSONに直接クエリしない**（コスト高＋遅い）。

---

# 7. スケジューリング・監視・アラート

## 7-1. スケジュール

* **EventBridge** で Glue ジョブを 5〜15分間隔（日次でも可）で起動
* 例：`rate(5 minutes)` / `cron(*/15 * * * ? *)`

## 7-2. 監視

* **Kinesis**：Put/Read Throttles、Iterator Age
* **Firehose**：DeliveryToS3.Success/Failure、DataFreshness
* **Glue**：ジョブ成功率・所要時間、CloudWatch Logs
* **Athena**：スキャン量（コスト）と失敗率

## 7-3. アラート

* CloudWatch アラーム → SNS 通知（失敗増加／遅延増加／スキャン量急増）

---

# 8. 性能・コスト最適化の勘所

* **Parquet + Snappy** を徹底（JSON直クエリは避ける）
* **ファイルサイズ**：128–512MB 目安（`repartition` / `coalesce` で調整）
* **小ファイル問題**：Firehoseのバッファ設定／Glueでのコンパクション
* **シャード設計（Kinesis）**：スループット余裕を持たせる
* **Athena**：必要パーティションのみクエリ／結果セットの保存場所は専用プレフィックスに
* **S3 ライフサイクル**：古い Parquet を Glacier に移行

---

# 9. セキュリティ／ガバナンス

* **S3ブロックパブリックアクセス**／**SSE-KMS**（鍵のローテとKey Policy）
* **VPCエンドポイント**（S3/Kinesis/Glue/Athena を私設網から利用）
* **IAM最小権限**（サービス毎にロールを分離、必要権限のみ許可）
* **CloudTrail**／**Config**：変更監査
* **タグ付け**：バケット・ストリーム・ジョブ・クエリにコスト配賦タグ

---

# 10. 検証チェックリスト（動作確認の順番）

1. **Producer** から Kinesis put → CloudWatch（Kinesis）で受信メトリクス上昇
2. **Firehose** の成功転送（DeliveryToS3.Success）→ S3 `raw_data/` に GZIP が溜まる
3. **Glueジョブ** 実行 → `curated/device_telemetry/` に Parquet + パーティションが出力
4. **Crawler** 実行 → Glue Catalog にテーブルができる
5. **Athena** で **パーティション絞って** クエリ → 結果が出る／スキャン量が小さい
6. **再実行**：Job Bookmark が効いて **新規ファイルだけ** 処理されることを確認
7. **DLQ**（任意）：欠損・型不正なレコードがDLQに吐かれていることを確認

---

## 付録：よくある詰まりどころ

* **Athenaでテーブルは見えるがデータ0件**

  * パーティションがCrawler未検出 → Crawler再実行 or `MSCK REPAIR TABLE`
  * WHEREで日付を間違えている（UTC/JST混在）
* **重複レコード**

  * Bookmark無効／overwrite運用／Producer側の再送設計
* **小ファイルだらけで遅い・高い**

  * Firehoseバッファ/Glueでrepartition・定期コンパクション
* **KMSまわりでアクセス拒否**

  * 各ロールにKMSの`Encrypt/Decrypt/GenerateDataKey`とKey Policyの許可が必要

---

これで「Kinesis → Firehose → S3(raw) → Glue（増分ETL） → S3(curated, Parquet) → Crawler → Athena」の**実践的なフロー一式**が揃いました。
次は、**JSTでパーティションを切る版**、**Delta Lake / Apache Iceberg対応**、**Terraform/CDKでのIaC化**、どれから進めますか？
