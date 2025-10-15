variable "name" {
  type        = string
  description = "Glue crawler name."
}

variable "role_name" {
  type        = string
  description = "IAM role name for the Glue crawler."
}

variable "role_description" {
  type        = string
  description = "Description for the Glue crawler IAM role."
  default     = null
}

variable "policy_name" {
  type        = string
  description = "IAM policy name for the Glue crawler."
}

variable "policy_description" {
  type        = string
  description = "Description for the Glue crawler IAM policy."
  default     = null
}

variable "database_name" {
  type        = string
  description = "Name for the Glue database."
}

variable "description" {
  type        = string
  description = "Description for the crawler."
  default     = null
}

variable "table_prefix" {
  type        = string
  description = "Optional prefix prepended to generated table names."
  default     = null
}

variable "s3_targets" {
  type        = list(string)
  description = "List of S3 target paths."
}

variable "analytics_bucket_arn" {
  type        = string
  description = "ARN of the analytics bucket the crawler reads."
}

variable "recrawl_behavior" {
  type        = string
  description = "Recrawl behavior for the crawler."
  default     = "CRAWL_EVERYTHING"
}

variable "configuration_json" {
  type        = string
  description = "JSON configuration for the crawler."
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
