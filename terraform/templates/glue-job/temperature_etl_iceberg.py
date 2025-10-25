import sys
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql import functions as F
from pyspark.sql.window import Window

# ====== 引数 ======
# --JOB_NAME my-job
# --SOURCE_S3 s3://<RAW_BUCKET>/raw_data/device_sensor/
# --DLQ_S3 s3://<SUPPORT_BUCKET>/dlq/raw_json/      # 任意。指定しない場合はDLQ無効
# --TABLE_BUCKET_ARN arn:aws:s3tables:ap-northeast-1:123456789012:bucket/my-table-bucket
# --TABLE_NAME device_telemetry
# --TABLE_NAMESPACE default
args = getResolvedOptions(
    sys.argv,
    ["JOB_NAME", "SOURCE_S3", "DLQ_S3", "TABLE_BUCKET_ARN", "TABLE_NAME", "TABLE_NAMESPACE"]
)

SOURCE_S3        = args["SOURCE_S3"].rstrip("/") + "/"
DLQ_S3           = args.get("DLQ_S3", "").rstrip("/")
TABLE_NAME       = args["TABLE_NAME"]
TABLE_NAMESPACE  = args["TABLE_NAMESPACE"]

# ====== Glue/Spark 初期化（Bookmark有効） ======
sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)  # ★ Bookmark を有効化

# -----------------------------------------------------------
# 重要：S3 Tables 用の Spark 設定は Terraform の --conf で渡します。
# ここではカタログ設定を一切書きません（重複を避けるため）。
#   spark.sql.defaultCatalog=datastreamertablesbucket
#   spark.sql.catalog.datastreamertablesbucket=org.apache.iceberg.spark.SparkCatalog
#   spark.sql.catalog.datastreamertablesbucket.catalog-impl=software.amazon.s3tables.iceberg.S3TablesCatalog
#   spark.sql.catalog.datastreamertablesbucket.warehouse=<TABLE_BUCKET_ARN>
# -----------------------------------------------------------

# ====== S3 JSON を読み込み（DynamicFrame -> DataFrame） ======
read_options = {
    "paths": [SOURCE_S3],
    "recurse": True,             # 日付フォルダを潜る場合に便利
    "groupFiles": "inPartition", # 小ファイルの結合に有効
    "jsonPath": "$",
    "withHeader": False
}

dyf_raw = glueContext.create_dynamic_frame_from_options(
    connection_type="s3",
    connection_options=read_options,
    format="json",
    format_options={"multiline": False}
)

df_raw = dyf_raw.toDF()

# 想定スキーマ
# device_id: string
# temperature: double
# timestamp: double (UNIX秒)
df_typed = (
    df_raw
      .withColumn("device_id",  F.col("device_id").cast("string"))
      .withColumn("temperature", F.col("temperature").cast("double"))
      .withColumn("timestamp",   F.col("timestamp").cast("double"))
)

# 不正行の抽出条件
cond_valid = (
    F.col("device_id").isNotNull()
    & F.col("temperature").isNotNull()
    & F.col("timestamp").isNotNull()
)

df_good = df_typed.filter(cond_valid)
df_bad  = df_typed.filter(~cond_valid)

# DLQ 出力（任意）
if DLQ_S3:
    # isEmpty() の代わりに効率の良い判定（count() > 0）を小さく評価
    if df_bad.limit(1).count() > 0:
        (df_bad.write.mode("append").json(DLQ_S3 + "/device_telemetry/"))

# ====== 正常データの整形 ======
# UNIX秒(double) -> timestamp(UTC)
# 1) from_unixtime(double) で文字列化
# 2) to_timestamp で timestamp へ
df = df_good.withColumn("event_time", F.to_timestamp(F.from_unixtime("timestamp")))

# 変換失敗を除外
df = df.filter(F.col("event_time").isNotNull())

# タイムゾーンを JST (UTC+9) に変換
df = df.withColumn("event_time", F.from_utc_timestamp("event_time", "Asia/Tokyo"))

# 温度スパイク除外（例）
df = df.filter((F.col("temperature") > -50) & (F.col("temperature") < 100))

# 重複除外（device_id + event_time で最新を採用）
w = Window.partitionBy("device_id", "event_time").orderBy(F.col("timestamp").desc_nulls_last())
df = df.withColumn("rn", F.row_number().over(w)).filter(F.col("rn") == 1).drop("rn")

# パーティション列（JST基準）
df = (
    df.withColumn("year",  F.year("event_time"))
      .withColumn("month", F.month("event_time"))
      .withColumn("day",   F.dayofmonth("event_time"))
)

# ====== 最終カラム選択 ======
df_out = df.select(
    "device_id",
    "temperature",
    "event_time",
    "year",
    "month",
    "day"
)

print("=== Schema ===")
df_out.printSchema()
print(f"=== Record Count: {df_out.count()} ===")

# ====== S3 Tables（Iceberg）へ書き込み ======
# Terraform 側 --conf の defaultCatalog と一致させる
catalog = "datastreamertablesbucket"
namespace = TABLE_NAMESPACE
table = TABLE_NAME
table_identifier = f"{catalog}.{namespace}.{table}"

# 必要なら namespace を事前作成（S3 Tables でも Iceberg の NAMESPACE が有効）
try:
    spark.sql(f"CREATE NAMESPACE IF NOT EXISTS {catalog}.{namespace}")
    print(f"=== Namespace {catalog}.{namespace} ready ===")
except Exception as e:
    print(f"=== Namespace creation skipped or already exists: {e} ===")

# テーブル存在チェック
try:
    spark.sql(f"DESCRIBE TABLE {table_identifier}")
    table_exists = True
    print(f"=== Table {table_identifier} exists, appending data ===")
except Exception:
    table_exists = False
    print(f"=== Table {table_identifier} does not exist, creating table ===")

# 作成 or 追記
if not table_exists:
    (
        df_out
          .writeTo(table_identifier)
          .using("iceberg")
          .tableProperty("format-version", "2")
          .partitionedBy("year", "month", "day")
          .create()
    )
    print(f"=== Created Iceberg table: {table_identifier} ===")
else:
    (
        df_out
          .writeTo(table_identifier)
          .using("iceberg")
          .append()
    )
    print(f"=== Appended data to Iceberg table: {table_identifier} ===")

print(f"=== Successfully wrote to Iceberg table: {table_identifier} ===")

job.commit()  # ★ Bookmark を確定
