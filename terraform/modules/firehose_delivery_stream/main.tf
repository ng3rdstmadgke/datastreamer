terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id        = data.aws_caller_identity.current.account_id
  role_name         = "${var.name_prefix}-kinesis-firehose-role"
  role_description  = "Kinesis Firehose role for ${var.name_prefix}"
  policy_name       = "${var.name_prefix}-kinesis-firehose-policy"
  policy_description = "Allow Firehose ${var.name_prefix} to read from Kinesis and write to S3"
  stream_name       = "${var.name_prefix}-firehose"
  log_group_name    = "/aws/kinesisfirehose/${local.stream_name}"
  log_stream_name   = "S3Delivery"
}

resource "aws_iam_role" "firehose" {
  name        = local.role_name
  description = local.role_description
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = local.account_id
        }
      }
      }
    ]
  })

}

resource "aws_iam_policy" "firehose" {
  name        = local.policy_name
  description = local.policy_description
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadFromKinesisStream"
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:DescribeStreamSummary",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards"
        ]
        Resource = var.kinesis_stream_arn
      },
      {
        Sid    = "WriteToS3"
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      },
      {
        Sid    = "CloudWatchLogging"
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })

}

resource "aws_iam_role_policy_attachment" "firehose" {
  role       = aws_iam_role.firehose.name
  policy_arn = aws_iam_policy.firehose.arn
}

resource "aws_kinesis_firehose_delivery_stream" "this" {
  name        = local.stream_name
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = var.kinesis_stream_arn
    role_arn           = aws_iam_role.firehose.arn
  }

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose.arn
    bucket_arn         = var.s3_bucket_arn
    prefix             = var.s3_prefix
    buffering_interval = var.buffering_interval
    buffering_size     = var.buffering_size
    compression_format = var.compression_format

    dynamic "cloudwatch_logging_options" {
      for_each = var.enable_logging ? [1] : []
      content {
        enabled         = true
        log_group_name  = local.log_group_name
        log_stream_name = local.log_stream_name
      }
    }
  }
}

output "delivery_stream_arn" {
  value = aws_kinesis_firehose_delivery_stream.this.arn
}

output "delivery_stream_name" {
  value = aws_kinesis_firehose_delivery_stream.this.name
}

output "role_arn" {
  value = aws_iam_role.firehose.arn
}

output "role_name" {
  value = aws_iam_role.firehose.name
}
