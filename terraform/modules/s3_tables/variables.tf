variable "table_bucket_name" {
  description = "S3 Table Bucket name (must be unique globally)"
  type        = string
}

variable "table_name" {
  description = "Table name within the namespace"
  type        = string
  default     = "device_telemetry"
}

variable "namespace" {
  description = "Namespace for organizing tables"
  type        = string
  default     = "default"
}
