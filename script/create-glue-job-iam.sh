#!/bin/bash
set -eu

PROJECT_DIR=$(cd $(dirname $0)/.. && pwd)
cd $PROJECT_DIR

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws iam create-role \
  --role-name datastream-GlueJobRole \
  --assume-role-policy-document file://${PROJECT_DIR}/resources/glue-job/trust-policy.json

aws iam create-policy \
  --policy-name datastream-GlueJobPolicy \
  --policy-document file://${PROJECT_DIR}/resources/glue-job/policy.json

aws iam attach-role-policy \
  --role-name datastream-GlueJobRole \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/datastream-GlueJobPolicy