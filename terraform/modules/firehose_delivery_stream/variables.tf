variable "name_prefix" {
  type        = string
  description = "Prefix used to build resource names (e.g., project-stage)."
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

variable "enable_logging" {
  type        = bool
  description = "Whether to enable CloudWatch logging for the delivery stream."
  default     = false
}
