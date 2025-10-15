terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_iam_role" "this" {
  name        = var.role_name
  description = var.role_description
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

  tags = var.tags
}

resource "aws_iam_policy" "this" {
  name        = var.policy_name
  description = var.policy_description
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

  tags = var.tags
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
  name         = var.name
  role_arn     = aws_iam_role.this.arn
  description  = var.description
  glue_version = var.glue_version

  command {
    name            = "glueetl"
    script_location = "s3://${var.script_bucket}/${var.script_key}"
    python_version  = var.python_version
  }

  default_arguments = var.default_arguments
  timeout           = var.timeout_minutes
  max_retries       = var.max_retries
  number_of_workers = var.number_of_workers
  worker_type       = var.worker_type

  execution_property {
    max_concurrent_runs = var.max_concurrent_runs
  }

  depends_on = [aws_s3_object.script]

  tags = var.tags
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
