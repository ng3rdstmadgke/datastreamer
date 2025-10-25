terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.82.0"  # S3 Tables support
    }
  }
}

# S3 Table Bucket (Iceberg専用ストレージ)
resource "aws_s3tables_table_bucket" "this" {
  name = var.table_bucket_name
}

resource "aws_s3tables_namespace" "default" {
  namespace        = var.namespace
  table_bucket_arn = aws_s3tables_table_bucket.this.arn
}

# S3 Table (Iceberg テーブル定義)
resource "aws_s3tables_table" "device_telemetry" {
  name              = var.table_name
  table_bucket_arn  = aws_s3tables_table_bucket.this.arn
  namespace         = aws_s3tables_namespace.default.namespace
  format            = "ICEBERG"
}

# Note: S3 Tables permissions are managed via IAM policies in the glue_job module
# Resource-based policies can be added here if needed for cross-account access