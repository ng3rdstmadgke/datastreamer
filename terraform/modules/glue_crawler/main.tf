terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  role_name           = "${var.name_prefix}-glue-crawler-role"
  role_description    = "Glue crawler role for ${var.name_prefix}"
  policy_name         = "${var.name_prefix}-glue-crawler-policy"
  policy_description  = "Glue crawler permissions for ${var.name_prefix}"
  crawler_name        = "${var.name_prefix}-curated-device-telemetry"
  crawler_description = "Crawler for ${var.name_prefix}"
  database_name       = replace("${var.name_prefix}_analytics", "-", "_")
  s3_targets          = ["s3://${var.analytics_bucket_name}/curated/device_telemetry/"]
  configuration_json  = jsonencode({
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

resource "aws_iam_role" "this" {
  name        = local.role_name
  description = local.role_description
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
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
        Sid    = "ReadCuratedBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          var.analytics_bucket_arn
        ]
      },
      {
        Sid    = "GetObjectsCurated"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "${var.analytics_bucket_arn}/*"
        ]
      },
      {
        Sid    = "GlueCatalog"
        Effect = "Allow"
        Action = [
          "glue:*Database*",
          "glue:*Table*",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartitions",
          "glue:GetPartition",
          "glue:CreatePartition",
          "glue:UpdatePartition",
          "glue:DeletePartition",
          "glue:BatchGetPartition",
          "glue:BatchCreatePartition",
          "glue:BatchUpdatePartition",
          "glue:BatchDeletePartition"
        ]
        Resource = "*"
      },
      {
        Sid    = "Logs"
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

resource "aws_glue_catalog_database" "this" {
  name = local.database_name
}

resource "aws_glue_crawler" "this" {
  name          = local.crawler_name
  role          = aws_iam_role.this.arn
  database_name = aws_glue_catalog_database.this.name
  description   = local.crawler_description
  table_prefix  = var.table_prefix

  dynamic "s3_target" {
    for_each = local.s3_targets
    content {
      path = s3_target.value
    }
  }

  recrawl_policy {
    recrawl_behavior = var.recrawl_behavior
  }

  configuration = local.configuration_json
  schedule      = var.schedule

}

output "crawler_name" {
  value = aws_glue_crawler.this.name
}

output "database_name" {
  value = aws_glue_catalog_database.this.name
}

output "role_arn" {
  value = aws_iam_role.this.arn
}
