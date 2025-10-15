#!/bin/bash
set -eu

PROJECT_DIR=$(cd $(dirname $0)/.. && pwd)
cd $PROJECT_DIR

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws glue create-job \
  --name temperature-etl-job \
  --role datastream-GlueJobRole \
  --command Name=glueetl,ScriptLocation=s3://temperature-analytics-bucket-h50t99ys/scripts/temperature_etl.py,PythonVersion=3 \
  --glue-version 4.0 \
  --default-arguments file://${PROJECT_DIR}/resources/glue-job/args.json \
  --description "Incremental ETL for temperature data (JSON -> Parquet)" \
  --max-retries 1 \
  --timeout 30 \
  --number-of-workers 5 \
  --worker-type G.1X