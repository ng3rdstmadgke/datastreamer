terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_kinesis_stream" "this" {
  name             = "${var.name_prefix}-${var.stream_suffix}"
  shard_count      = var.stream_mode == "PROVISIONED" ? var.shard_count : null
  retention_period = var.retention_period
  stream_mode_details {
    stream_mode = var.stream_mode
  }
  tags = var.tags
}

output "stream_name" {
  value = aws_kinesis_stream.this.name
}

output "stream_arn" {
  value = aws_kinesis_stream.this.arn
}
