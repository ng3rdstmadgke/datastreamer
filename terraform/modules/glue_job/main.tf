terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

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
          var.support_bucket_arn,
          "${var.support_bucket_arn}/*"
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
      },
      {
        Effect = "Allow"
        Action = [
          "s3tables:GetTable",
          "s3tables:GetTableMetadataLocation",
          "s3tables:PutTableData",
          "s3tables:UpdateTableMetadataLocation",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3tables:GetTableBucket"
        ]
        Resource = var.table_bucket_arn
      }
    ]
  })

}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

resource "aws_s3_object" "script" {
  bucket       = var.script_bucket
  key          = local.glue_script_key
  source       = var.script_source_path
  etag         = filemd5(var.script_source_path)
  content_type = "text/x-python"
}

locals {
  s3tables_jar_name    = "s3-tables-catalog-for-iceberg-runtime-0.1.8.jar"
  s3tables_jar_path    = "${path.module}/jars/${local.s3tables_jar_name}"
  s3tables_s3_key      = "jars/${local.s3tables_jar_name}"
}

# JAR を support_bucket にアップロード
resource "aws_s3_object" "s3tables_runtime_jar" {
  bucket = var.support_bucket_name
  key    = local.s3tables_s3_key
  source = local.s3tables_jar_path
  etag   = filemd5(local.s3tables_jar_path)

  content_type = "application/java-archive"
}

# Glue Job に組み込む
resource "aws_glue_job" "this" {
  name         = "${var.name_prefix}-temperature-etl"
  role_arn     = aws_iam_role.this.arn
  glue_version = "5.0"
  description  = "ETL job for ${var.name_prefix}"

  command {
    name            = "glueetl"
    script_location = "s3://${var.script_bucket}/${local.glue_script_key}"
    python_version  = "3"
  }

  default_arguments = {
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"                   = ""
    "--enable-spark-ui"                  = "true"
    "--datalake-formats"                 = "iceberg"
    "--TempDir"                          = "s3://${var.support_bucket_name}/temp/"
    "--SOURCE_S3"                        = "s3://${var.data_bucket_name}/raw_data/device_sensor/"
    "--DLQ_S3"                           = "s3://${var.support_bucket_name}/dlq/raw_json/"
    "--TABLE_BUCKET_ARN"                 = var.table_bucket_arn
    "--TABLE_NAME"                       = var.table_name
    "--TABLE_NAMESPACE"                  = var.table_namespace

    # S3 Tables Catalog 設定
    "--conf" = join(" ", [
      "spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions",
      " --conf spark.sql.defaultCatalog=datastreamertablesbucket",
      " --conf spark.sql.catalog.datastreamertablesbucket=org.apache.iceberg.spark.SparkCatalog",
      " --conf spark.sql.catalog.datastreamertablesbucket.catalog-impl=software.amazon.s3tables.iceberg.S3TablesCatalog",
      " --conf spark.sql.catalog.datastreamertablesbucket.warehouse=${var.table_bucket_arn}"
    ])

    # ダウンロード済みの runtime JAR を Glue に渡す
    "--extra-jars" = "s3://${var.support_bucket_name}/${local.s3tables_s3_key}"
  }

  number_of_workers = var.number_of_workers
  worker_type       = var.worker_type
  timeout           = var.timeout_minutes
  max_retries       = var.max_retries

  execution_property {
    max_concurrent_runs = var.max_concurrent_runs
  }

  depends_on = [
    aws_s3_object.script,
    aws_s3_object.s3tables_runtime_jar
  ]
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
