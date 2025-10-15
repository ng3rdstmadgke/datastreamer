#!/bin/bash
set -eu

PROJECT_DIR=$(cd $(dirname $0)/.. && pwd)
cd $PROJECT_DIR

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)


# Glue Database 作成
DB_NAME=temperature_analytics
aws glue create-database --database-input Name=$DB_NAME

aws glue create-crawler \
  --name curated-device-telemetry-crawler \
  --role datastream-GlueCrawlerRole \
  --database-name $DB_NAME \
  --targets '{"S3Targets":[{"Path":"s3://temperature-analytics-bucket-h50t99ys/curated/device_telemetry/"}]}' \
  --table-prefix "" \
  --configuration '{
    "Version":1.0,
    "CrawlerOutput":{
      "Partitions":{"AddOrUpdateBehavior":"InheritFromTable"},
      "Tables":{"AddOrUpdateBehavior":"MergeNewColumns"}
    },
    "Grouping":{"TableLevelConfiguration":3}
  }' \
  --recrawl-policy RecrawlBehavior=CRAWL_EVERYTHING
