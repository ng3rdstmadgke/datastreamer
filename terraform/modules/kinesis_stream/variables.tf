variable "name_prefix" {
  type        = string
  description = "Prefix used to build the Kinesis stream name (e.g., project-stage)."
}

variable "shard_count" {
  type        = number
  description = "Number of shards when stream_mode is PROVISIONED."
  default     = 1
}
