output "codecommit_repository_url" {
  description = "URL of the CodeCommit repository"
  value       = aws_codecommit_repository.main.clone_url_http
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for artifacts"
  value       = aws_s3_bucket.artifacts.bucket
}

output "lambda_function_name" {
  description = "Name of the deployment Lambda function"
  value       = aws_lambda_function.deploy.function_name
}

output "sns_topic_arn" {
  description = "ARN of the SNS notification topic"
  value       = aws_sns_topic.notifications.arn
}
