variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket."
}

variable "enable_versioning" {
  type        = bool
  description = "Whether to enable versioning on the bucket."
  default     = true
}

variable "enable_encryption" {
  type        = bool
  description = "Whether to enable default AES256 encryption."
  default     = true
}
