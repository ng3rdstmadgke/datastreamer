terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  glue_script_key = "scripts/temperature_etl.py"
}

resource "aws_iam_role" "this" {
  name        = "${var.name_prefix}-glue-job-role"
  description = "Glue job role for ${var.name_prefix}"
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
  name        = "${var.name_prefix}-glue-job-policy"
  description = "Glue job permissions for ${var.name_prefix}"
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
  key          = local.glue_script_key
  source       = var.script_source_path
  etag         = filemd5(var.script_source_path)
  content_type = "text/x-python"
}

resource "aws_glue_job" "this" {
  name         = "${var.name_prefix}-temperature-etl"
  role_arn     = aws_iam_role.this.arn
  description  = "ETL job for ${var.name_prefix}"
  glue_version = "4.0"

  command {
    name            = "glueetl"
    script_location = "s3://${var.script_bucket}/${local.glue_script_key}"
    python_version  = "3"
  }

  default_arguments = {
    // https://docs.aws.amazon.com/glue/latest/dg/aws-glue-programming-etl-glue-arguments.html
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"                   = ""
    "--enable-spark-ui"                  = "true"
    "--TempDir"                          = "s3://${var.analytics_bucket_name}/temp/"
    "--SOURCE_S3"                        = "s3://${var.data_bucket_name}/raw_data/device_sensor/"
    "--TARGET_S3"                        = "s3://${var.analytics_bucket_name}/curated/device_telemetry/"
    "--DLQ_S3"                           = "s3://${var.analytics_bucket_name}/dlq/raw_json/"
  }

  timeout           = var.timeout_minutes
  max_retries       = var.max_retries
  number_of_workers = var.number_of_workers
  worker_type       = var.worker_type

  execution_property {
    max_concurrent_runs = var.max_concurrent_runs
  }

  depends_on = [aws_s3_object.script]

}

resource "aws_iam_role" "scheduler" {
  name        = "${var.name_prefix}-glue-job-scheduler-role"
  description = "EventBridge Scheduler invocation role for ${var.name_prefix} Glue job"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSchedulerInvoke"
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "scheduler" {
  name = "${var.name_prefix}-glue-job-scheduler-policy"
  role = aws_iam_role.scheduler.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowGlueStartJob"
        Effect = "Allow"
        Action = [
          "glue:StartJobRun"
        ]
        Resource = aws_glue_job.this.arn
      }
    ]
  })
}

resource "aws_scheduler_schedule" "this" {
  name        = "${var.name_prefix}-glue-job-schedule"
  description = "15-minute schedule for ${var.name_prefix} Glue job"

  schedule_expression = "rate(15 minutes)"
  state               = "ENABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:glue:startJobRun"
    role_arn = aws_iam_role.scheduler.arn
    input = jsonencode({
      JobName = aws_glue_job.this.name
    })
  }
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

output "schedule_arn" {
  value = aws_scheduler_schedule.this.arn
}
