output "table_bucket_arn" {
  description = "ARN of the S3 Table Bucket"
  value       = aws_s3tables_table_bucket.this.arn
}

output "table_bucket_name" {
  description = "Name of the S3 Table Bucket"
  value       = aws_s3tables_table_bucket.this.name
}

output "table_arn" {
  description = "ARN of the device_telemetry table"
  value       = aws_s3tables_table.device_telemetry.arn
}

output "table_name" {
  description = "Name of the device_telemetry table"
  value       = aws_s3tables_table.device_telemetry.name
}

output "namespace" {
  description = "Namespace of the table"
  value       = aws_s3tables_table.device_telemetry.namespace
}
