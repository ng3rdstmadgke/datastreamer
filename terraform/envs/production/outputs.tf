output "data_bucket_name" {
  value = module.s3_buckets["data"].bucket_name
}

output "analytics_bucket_name" {
  value = module.s3_buckets["analytics"].bucket_name
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

output "glue_crawler_name" {
  value = module.glue_crawler.crawler_name
}

output "glue_database_name" {
  value = module.glue_crawler.database_name
}
