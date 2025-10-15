#!/bin/bash
set -eu

PROJECT_DIR=$(cd $(dirname $0)/.. && pwd)
cd $PROJECT_DIR

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws s3 cp ${PROJECT_DIR}/resources/glue-job/temperature_etl.py s3://temperature-analytics-bucket-h50t99ys/scripts/temperature_etl.py
