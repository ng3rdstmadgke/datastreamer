variable "name_prefix" {
  type        = string
  description = "Prefix used to build Glue crawler/IAM resource names."
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

variable "recrawl_behavior" {
  type        = string
  description = "Recrawl behavior for the crawler."
  default     = "CRAWL_EVERYTHING"
}

variable "schedule" {
  type        = string
  description = "Optional crawler schedule (cron)."
  default     = null
}
