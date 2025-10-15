#!/bin/bash
set -e

BUCKET_NAME=temperature-analytics-bucket-h50t99ys
aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --create-bucket-configuration LocationConstraint=ap-northeast-1

aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled
