#!/bin/bash
set -eu

PROJECT_DIR=$(cd $(dirname $0)/.. && pwd)
cd $PROJECT_DIR

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
DATA_BUCKET_NAME=temperature-data-bucket-h50t99ys

printf -v KINESIS_STREAM_SOURCE_CONFIGURATION '{"RoleARN":"arn:aws:iam::%s:role/datastream-KinesisFirehoseRole","KinesisStreamARN":"arn:aws:kinesis:ap-northeast-1:%s:stream/temperature-stream"}' "$AWS_ACCOUNT_ID" "$AWS_ACCOUNT_ID"
printf -v S3_DESTINATION_CONFIGURATION '{"RoleARN":"arn:aws:iam::%s:role/datastream-KinesisFirehoseRole","BucketARN":"arn:aws:s3:::%s","Prefix":"raw_data/","BufferingHints":{"IntervalInSeconds":60,"SizeInMBs":5},"CompressionFormat":"GZIP"}' "$AWS_ACCOUNT_ID" "$DATA_BUCKET_NAME"

aws firehose create-delivery-stream \
  --delivery-stream-name temperature-to-s3 \
  --delivery-stream-type KinesisStreamAsSource \
  --kinesis-stream-source-configuration "${KINESIS_STREAM_SOURCE_CONFIGURATION}" \
  --s3-destination-configuration "${S3_DESTINATION_CONFIGURATION}"
