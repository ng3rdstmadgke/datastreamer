variable "name_prefix" {
  type        = string
  description = "Prefix used to build resource names (e.g., project-stage)."
}

variable "role_description" {
  type        = string
  description = "Description for the Firehose IAM role."
  default     = null
}

variable "kinesis_stream_arn" {
  type        = string
  description = "ARN of the Kinesis data stream source."
}

variable "s3_bucket_arn" {
  type        = string
  description = "ARN of the S3 destination bucket."
}

variable "s3_prefix" {
  type        = string
  description = "Prefix for S3 delivery objects (must end with /)."
  default     = "raw_data/"
}

variable "buffering_interval" {
  type        = number
  description = "Buffering interval in seconds."
  default     = 60
}

variable "buffering_size" {
  type        = number
  description = "Buffering size in MB."
  default     = 5
}

variable "compression_format" {
  type        = string
  description = "Compression format for S3 objects."
  default     = "GZIP"
}

variable "policy_description" {
  type        = string
  description = "Description for the Firehose IAM policy."
  default     = null
}

variable "log_group_name" {
  type        = string
  description = "CloudWatch log group for Firehose delivery."
  default     = "/aws/kinesisfirehose/default"
}

variable "log_stream_name" {
  type        = string
  description = "CloudWatch log stream for Firehose delivery."
  default     = "S3Delivery"
}

variable "enable_logging" {
  type        = bool
  description = "Whether to enable CloudWatch logging for the delivery stream."
  default     = false
}

variable "external_id" {
  type        = string
  description = "External ID required by Firehose when assuming the role. Defaults to current account ID."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the delivery stream."
  default     = {}
}
