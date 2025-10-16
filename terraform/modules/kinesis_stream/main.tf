terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_kinesis_stream" "this" {
  name             = "${var.name_prefix}-stream"
  shard_count      = var.shard_count
  retention_period = 24

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }
}

output "stream_name" {
  value = aws_kinesis_stream.this.name
}

output "stream_arn" {
  value = aws_kinesis_stream.this.arn
}
