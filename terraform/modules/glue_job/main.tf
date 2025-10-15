terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  role_name          = "${var.name_prefix}-glue-job-role"
  role_description   = "Glue job role for ${var.name_prefix}"
  policy_name        = "${var.name_prefix}-glue-job-policy"
  policy_description = "Glue job permissions for ${var.name_prefix}"
  job_name           = "${var.name_prefix}-${var.job_suffix}"
  job_description    = "ETL job for ${var.name_prefix}"
  default_arguments = {
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"                   = ""
    "--enable-spark-ui"                  = "true"
    "--TempDir"                          = "s3://${var.analytics_bucket_name}/temp/"
    "--SOURCE_S3"                        = "s3://${var.data_bucket_name}/raw_data/"
    "--TARGET_S3"                        = "s3://${var.analytics_bucket_name}/curated/device_telemetry/"
    "--DLQ_S3"                           = "s3://${var.analytics_bucket_name}/dlq/raw_json/"
  }
}

resource "aws_iam_role" "this" {
  name        = local.role_name
  description = local.role_description
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = ""
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

}

resource "aws_iam_policy" "this" {
  name        = local.policy_name
  description = local.policy_description
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.data_bucket_arn,
          "${var.data_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:ListBucket",
          "s3:GetObject"
        ]
        Resource = [
          var.analytics_bucket_arn,
          "${var.analytics_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:*Database*",
          "glue:*Table*",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:GetTable",
          "glue:GetTables"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })

}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

resource "aws_s3_object" "script" {
  count = var.upload_script ? 1 : 0

  bucket       = var.script_bucket
  key          = var.script_key
  source       = var.script_source_path
  etag         = filemd5(var.script_source_path)
  content_type = "text/x-python"
}

resource "aws_glue_job" "this" {
  name         = local.job_name
  role_arn     = aws_iam_role.this.arn
  description  = local.job_description
  glue_version = "4.0"

  command {
    name            = "glueetl"
    script_location = "s3://${var.script_bucket}/${var.script_key}"
    python_version  = "3"
  }

  default_arguments = local.default_arguments
  timeout           = var.timeout_minutes
  max_retries       = var.max_retries
  number_of_workers = var.number_of_workers
  worker_type       = var.worker_type

  execution_property {
    max_concurrent_runs = var.max_concurrent_runs
  }

  depends_on = [aws_s3_object.script]

}

output "job_name" {
  value = aws_glue_job.this.name
}

output "job_arn" {
  value = aws_glue_job.this.arn
}

output "role_arn" {
  value = aws_iam_role.this.arn
}
