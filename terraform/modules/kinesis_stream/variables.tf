variable "name_prefix" {
  type        = string
  description = "Prefix used to build the Kinesis stream name (e.g., project-stage)."
}

variable "stream_suffix" {
  type        = string
  description = "Suffix appended to the stream name."
  default     = "stream"
}

variable "shard_count" {
  type        = number
  description = "Number of shards when stream_mode is PROVISIONED."
  default     = 1
}

variable "stream_mode" {
  type        = string
  description = "Stream mode, either PROVISIONED or ON_DEMAND."
  default     = "PROVISIONED"
}

variable "retention_period" {
  type        = number
  description = "Data retention period in hours (24-8760)."
  default     = 24
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the stream."
  default     = {}
}
