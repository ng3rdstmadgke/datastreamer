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

  default_tags {
    tags = {
      PROJECT = var.project
      STAGE   = var.stage
    }
  }
}

locals {
  stage           = var.stage
  project         = var.project
  name_prefix     = "${var.project}-${var.stage}"
  glue_script_key = "scripts/temperature_etl.py"
}

module "s3_buckets" {
  source = "../../modules/s3_bucket"

  for_each = {
    data      = var.data_bucket_name
    analytics = var.analytics_bucket_name
  }

  bucket_name = each.value
}
module "kinesis_stream" {
  source = "../../modules/kinesis_stream"

  name_prefix = local.name_prefix
  shard_count = 1
}

module "firehose" {
  source = "../../modules/firehose_delivery_stream"

  name_prefix        = local.name_prefix
  kinesis_stream_arn = module.kinesis_stream.stream_arn
  s3_bucket_arn      = module.s3_buckets["data"].bucket_arn
  s3_prefix          = "raw_data/"
  buffering_interval = 60
  buffering_size     = 5
  compression_format = "GZIP"
  enable_logging     = false
}

module "glue_job" {
  source = "../../modules/glue_job"

  name_prefix           = local.name_prefix
  data_bucket_arn       = module.s3_buckets["data"].bucket_arn
  analytics_bucket_arn  = module.s3_buckets["analytics"].bucket_arn
  data_bucket_name      = module.s3_buckets["data"].bucket_name
  analytics_bucket_name = module.s3_buckets["analytics"].bucket_name
  script_bucket         = module.s3_buckets["analytics"].bucket_name
  script_key            = local.glue_script_key
  script_source_path    = abspath("${path.module}/../../templates/glue-job/temperature_etl.py")
  timeout_minutes       = 30
  max_retries           = 1
  worker_type           = "G.1X"
  number_of_workers     = 5
  max_concurrent_runs   = 1
}

module "glue_crawler" {
  source = "../../modules/glue_crawler"

  name_prefix           = local.name_prefix
  table_prefix          = ""
  analytics_bucket_arn  = module.s3_buckets["analytics"].bucket_arn
  analytics_bucket_name = module.s3_buckets["analytics"].bucket_name
  recrawl_behavior      = "CRAWL_EVERYTHING"
  schedule              = null
}
