output "data_bucket_name" {
  value = module.s3_buckets["data"].bucket_name
}

output "support_bucket_name" {
  value = module.s3_buckets["support"].bucket_name
}

output "table_bucket_name" {
  value = module.s3_tables.table_bucket_name
}

output "kinesis_stream_name" {
  value = module.kinesis_stream.stream_name
}

output "firehose_delivery_stream_name" {
  value = module.firehose.delivery_stream_name
}

output "kinesis_consumer_lambda_name" {
  value = module.kinesis_consumer.lambda_name
}

output "telemetry_table_name" {
  value = module.kinesis_consumer.dynamodb_table_name
}

output "glue_job_name" {
  value = module.glue_job.job_name
}

output "s3_table_arn" {
  value = module.s3_tables.table_arn
}

output "s3_table_name" {
  value = module.s3_tables.table_name
}
