terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.region
}

locals {
  stage       = var.stage
  project     = var.project
  name_prefix = "${var.project}-${var.stage}"

  tags = {
    PROJECT = var.project
    STAGE   = var.stage
  }

  bucket_names = {
    data      = var.data_bucket_name
    analytics = var.analytics_bucket_name
  }

  kinesis_stream_name = "${local.name_prefix}-stream"
  firehose_name       = "${local.name_prefix}-firehose"
  glue_job_name       = "${local.name_prefix}-temperature-etl"
  glue_database_name  = replace("${local.name_prefix}_analytics", "-", "_")
  glue_crawler_name   = "${local.name_prefix}-curated-device-telemetry"
  glue_script_key     = "scripts/temperature_etl.py"

  glue_job_default_arguments = jsondecode(
    templatefile("${path.module}/../../templates/glue-job/args.json", {
      analytics_bucket = var.analytics_bucket_name
      data_bucket      = var.data_bucket_name
    })
  )

  glue_crawler_configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
      Tables = {
        AddOrUpdateBehavior = "MergeNewColumns"
      }
    }
    Grouping = {
      TableLevelConfiguration = 3
    }
  })
}

resource "aws_s3_bucket" "bucket" {
  for_each = local.bucket_names

  bucket = each.value
  tags   = local.tags
}

resource "aws_s3_bucket_versioning" "bucket" {
  for_each = aws_s3_bucket.bucket

  bucket = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket" {
  for_each = aws_s3_bucket.bucket

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "bucket" {
  for_each = aws_s3_bucket.bucket

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

module "kinesis_stream" {
  source = "../../modules/kinesis_stream"

  name        = local.kinesis_stream_name
  shard_count = 1
  tags        = local.tags
}

module "firehose" {
  source = "../../modules/firehose_delivery_stream"

  name               = local.firehose_name
  role_name          = "${local.name_prefix}-kinesis-firehose-role"
  role_description   = "Permissions for Firehose to read from Kinesis and write to S3."
  policy_name        = "${local.name_prefix}-kinesis-firehose-policy"
  policy_description = "Allow Firehose to pull from the source stream and deliver to S3."
  kinesis_stream_arn = module.kinesis_stream.stream_arn
  s3_bucket_arn      = aws_s3_bucket.bucket["data"].arn
  s3_prefix          = "raw_data/"
  buffering_interval = 60
  buffering_size     = 5
  compression_format = "GZIP"
  enable_logging     = false
  tags               = local.tags
}

module "glue_job" {
  source = "../../modules/glue_job"

  name                 = local.glue_job_name
  role_name            = "${local.name_prefix}-glue-job-role"
  role_description     = "Glue job execution role."
  policy_name          = "${local.name_prefix}-glue-job-policy"
  policy_description   = "Glue job access to data and analytics buckets plus catalog."
  data_bucket_arn      = aws_s3_bucket.bucket["data"].arn
  analytics_bucket_arn = aws_s3_bucket.bucket["analytics"].arn
  description          = "Incremental ETL for temperature data (JSON -> Parquet)"
  script_bucket        = aws_s3_bucket.bucket["analytics"].bucket
  script_key           = local.glue_script_key
  script_source_path   = abspath("${path.module}/../../templates/glue-job/temperature_etl.py")
  default_arguments    = local.glue_job_default_arguments
  timeout_minutes      = 30
  max_retries          = 1
  worker_type          = "G.1X"
  number_of_workers    = 5
  max_concurrent_runs  = 1
  tags                 = local.tags
}

module "glue_crawler" {
  source = "../../modules/glue_crawler"

  name                 = local.glue_crawler_name
  role_name            = "${local.name_prefix}-glue-crawler-role"
  role_description     = "Glue crawler execution role."
  policy_name          = "${local.name_prefix}-glue-crawler-policy"
  policy_description   = "Glue crawler access to analytics bucket and catalog."
  database_name        = local.glue_database_name
  description          = "Catalog curated device telemetry stored in the analytics bucket."
  table_prefix         = ""
  analytics_bucket_arn = aws_s3_bucket.bucket["analytics"].arn
  s3_targets           = ["s3://${aws_s3_bucket.bucket["analytics"].bucket}/curated/device_telemetry/"]
  configuration_json   = local.glue_crawler_configuration
  recrawl_behavior     = "CRAWL_EVERYTHING"
  schedule             = null
  tags                 = local.tags
}
