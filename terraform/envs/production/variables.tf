variable "stage" {
  type        = string
  description = "Deployment stage identifier."
  default     = "prod"
}

variable "project" {
  type        = string
  description = "Project identifier used for naming/tagging."
  default     = "datastreamer"
}

variable "region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "ap-northeast-1"
}

variable "data_bucket_name" {
  type        = string
  description = "Name of the S3 bucket storing raw telemetry data."
}

variable "analytics_bucket_name" {
  type        = string
  description = "Name of the S3 bucket storing curated analytics output."
}
