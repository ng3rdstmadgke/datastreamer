terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_kinesis_stream" "this" {
  name             = var.name
  shard_count      = var.shard_count
  retention_period = var.retention_period
  stream_mode_details {
    stream_mode = var.stream_mode
  }
  tags = var.tags
}

output "stream_arn" {
  value = aws_kinesis_stream.this.arn
}

output "stream_name" {
  value = aws_kinesis_stream.this.name
}
