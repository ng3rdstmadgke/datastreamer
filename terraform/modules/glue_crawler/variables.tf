variable "name_prefix" {
  type        = string
  description = "Prefix used to build Glue crawler/IAM resource names (e.g., project-stage)."
}

variable "role_description" {
  type        = string
  description = "Description for the Glue crawler IAM role."
  default     = null
}

variable "policy_description" {
  type        = string
  description = "Description for the Glue crawler IAM policy."
  default     = null
}

variable "crawler_suffix" {
  type        = string
  description = "Suffix appended to the Glue crawler name."
  default     = "curated-device-telemetry"
}

variable "crawler_description" {
  type        = string
  description = "Override description for the Glue crawler."
  default     = null
}

variable "database_suffix" {
  type        = string
  description = "Suffix used when generating the Glue database name."
  default     = "analytics"
}

variable "table_prefix" {
  type        = string
  description = "Optional prefix prepended to generated table names."
  default     = ""
}

variable "analytics_bucket_arn" {
  type        = string
  description = "ARN of the analytics bucket the crawler reads."
}

variable "analytics_bucket_name" {
  type        = string
  description = "Name of the analytics bucket the crawler reads."
}

variable "curated_prefix" {
  type        = string
  description = "Prefix within the analytics bucket that stores curated data."
  default     = "curated/device_telemetry/"
}

variable "s3_targets_override" {
  type        = list(string)
  description = "Optional override list of S3 targets. If null, a target is built from analytics bucket and curated_prefix."
  default     = null
}

variable "recrawl_behavior" {
  type        = string
  description = "Recrawl behavior for the crawler."
  default     = "CRAWL_EVERYTHING"
}

variable "configuration_json_override" {
  type        = string
  description = "Optional override for the crawler configuration JSON."
  default     = null
}

variable "schedule" {
  type        = string
  description = "Optional crawler schedule (cron)."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to Glue resources."
  default     = {}
}
