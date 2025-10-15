variable "name" {
  type        = string
  description = "Glue job name."
}

variable "role_name" {
  type        = string
  description = "IAM role name for the Glue job."
}

variable "role_description" {
  type        = string
  description = "Description for the Glue job IAM role."
  default     = null
}

variable "policy_name" {
  type        = string
  description = "IAM policy name for the Glue job."
}

variable "policy_description" {
  type        = string
  description = "Description for the Glue job IAM policy."
  default     = null
}

variable "data_bucket_arn" {
  type        = string
  description = "ARN of the raw data bucket the job reads from."
}

variable "analytics_bucket_arn" {
  type        = string
  description = "ARN of the analytics bucket the job writes to."
}

variable "description" {
  type        = string
  description = "Description for the Glue job."
  default     = null
}

variable "script_bucket" {
  type        = string
  description = "S3 bucket containing the Glue script."
}

variable "script_key" {
  type        = string
  description = "S3 key for the Glue script file."
}

variable "script_source_path" {
  type        = string
  description = "Local path to the Glue script to upload."
}

variable "upload_script" {
  type        = bool
  description = "Whether to upload the script to S3."
  default     = true
}

variable "default_arguments" {
  type        = map(string)
  description = "Default arguments passed to the Glue job."
  default     = {}
}

variable "glue_version" {
  type        = string
  description = "Glue version."
  default     = "4.0"
}

variable "python_version" {
  type        = string
  description = "Python version for the Glue job."
  default     = "3"
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

variable "tags" {
  type        = map(string)
  description = "Tags applied to the Glue job."
  default     = {}
}
