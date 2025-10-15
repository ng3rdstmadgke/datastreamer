output "data_bucket_name" {
  value = aws_s3_bucket.bucket["data"].bucket
}

output "analytics_bucket_name" {
  value = aws_s3_bucket.bucket["analytics"].bucket
}

output "kinesis_stream_name" {
  value = module.kinesis_stream.stream_name
}

output "firehose_delivery_stream_name" {
  value = module.firehose.delivery_stream_name
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
