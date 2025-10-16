variable "name_prefix" {
  type        = string
  description = "Prefix used to build Glue job/IAM resource names (e.g., project-stage)."
}

variable "data_bucket_arn" {
  type        = string
  description = "ARN of the raw data bucket the job reads from."
}

variable "analytics_bucket_arn" {
  type        = string
  description = "ARN of the analytics bucket the job writes to."
}

variable "data_bucket_name" {
  type        = string
  description = "Name of the raw data bucket."
}

variable "analytics_bucket_name" {
  type        = string
  description = "Name of the analytics bucket."
}

variable "script_bucket" {
  type        = string
  description = "S3 bucket containing the Glue script."
}

variable "script_source_path" {
  type        = string
  description = "Local path to the Glue script to upload."
}

variable "timeout_minutes" {
  type        = number
  description = "Job timeout in minutes."
  default     = 30
}

variable "max_retries" {
  type        = number
  description = "Number of retries for the job."
  default     = 1
}

variable "worker_type" {
  type        = string
  description = "Glue worker type."
  default     = "G.1X"
}

variable "number_of_workers" {
  type        = number
  description = "Number of workers for the Glue job."
  default     = 5
}

variable "max_concurrent_runs" {
  type        = number
  description = "Maximum concurrent Glue job runs."
  default     = 1
}
