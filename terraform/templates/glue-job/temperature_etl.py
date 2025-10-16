import sys
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql import functions as F
from pyspark.sql.window import Window
from awsglue.dynamicframe import DynamicFrame

# ====== 引数 ======
# --JOB_NAME my-job
# --SOURCE_S3 s3://<RAW_BUCKET>/raw_data/
# --TARGET_S3 s3://<CURATED_BUCKET>/curated/device_telemetry/
# --DLQ_S3 s3://<CURATED_BUCKET>/dlq/raw_json/   # 任意。指定しない場合はDLQ無効
args = getResolvedOptions(
    sys.argv,
    ["JOB_NAME", "SOURCE_S3", "TARGET_S3", "DLQ_S3"]
)

SOURCE_S3 = args["SOURCE_S3"].rstrip("/") + "/"
TARGET_S3 = args["TARGET_S3"].rstrip("/") + "/"
DLQ_S3    = args.get("DLQ_S3", "").rstrip("/")

# ====== Glue/Spark 初期化（Bookmark有効） ======
sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
# ★ ここが重要：Bookmark 有効化
job.init(args["JOB_NAME"], args)

# ====== S3 JSON を DynamicFrame で読み込み ======
# JSON Lines, GZIP混在OK。multilineはFalse
read_options = {
    "paths": [SOURCE_S3],
    "recurse": True,            # 日付フォルダを潜る場合に便利
    "groupFiles": "inPartition",# 小ファイルの結合に有効
    "jsonPath": "$",            # 1レコード=1JSONオブジェクト想定
    "withHeader": False
}

dyf_raw = glueContext.create_dynamic_frame_from_options(
    connection_type="s3",
    connection_options=read_options,
    format="json",
    format_options={"multiline": False}
)

# ====== (任意) 破損レコードをDLQへ分離 ======
# DynamicFrame は corrupt を自動で列に出さないため、
# いったん DataFrame 化して try_cast で弾く方法を使う。
df_raw = dyf_raw.toDF()

# 想定スキーマ
# device_id: string
# temperature: double
# timestamp: double (UNIX秒、小数OK)
df_typed = (
    df_raw
    .withColumn("device_id", F.col("device_id").cast("string"))
    .withColumn("temperature", F.col("temperature").cast("double"))
    .withColumn("timestamp", F.col("timestamp").cast("double"))
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
    if df_bad.rdd.isEmpty() is False:
        (df_bad
         .write
         .mode("append")
         .json(DLQ_S3 + "/device_telemetry/"))

# ====== 正常データの整形 ======
# タイムスタンプ正規化
df = df_good.withColumn("event_time", F.to_timestamp("timestamp"))

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
print(df.printSchema())

# ====== 書き出し（append, Parquet, Snappy, Partitioned） ======
# ファイルサイズ調整（例：1日あたり数ファイルに）※要件で調整
df_out = df.repartition(8, "year", "month", "day")  # データ量に応じて 2/4/8/16 など

(
    df_out
    .write
    .mode("append")                    # ★ append（上書きしない）
    .format("parquet")
    .option("compression", "snappy")
    .partitionBy("year", "month", "day")
    .save(TARGET_S3)
)

job.commit()  # ★ Bookmark がここで確定
