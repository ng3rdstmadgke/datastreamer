variable "name_prefix" {
  type        = string
  description = "Prefix used to build Lambda/DynamoDB resource names (e.g., project-stage)."
}

variable "kinesis_stream_arn" {
  type        = string
  description = "ARN of the Kinesis Data Stream to consume."
}

variable "kinesis_stream_name" {
  type        = string
  description = "Name of the Kinesis Data Stream to consume."
}

variable "lambda_source_dir" {
  type        = string
  description = "Absolute path to the Lambda function source directory."
}
