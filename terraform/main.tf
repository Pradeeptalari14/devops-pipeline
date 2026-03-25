# Local values for naming and tagging
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    CreatedBy   = "Pradeep"
  }
  name_prefix = "${var.project_name}-${var.environment}"
}

# Get current account info
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ═══════════════════════════════════════════════════════════
# S3 BUCKET - Build Artifacts
# ═══════════════════════════════════════════════════════════

resource "aws_s3_bucket" "artifacts" {
  bucket = "${local.name_prefix}-artifacts-${data.aws_caller_identity.current.account_id}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ═══════════════════════════════════════════════════════════
# DYNAMODB TABLE - Deployment State
# ═══════════════════════════════════════════════════════════

resource "aws_dynamodb_table" "deployments" {
  name         = "${local.name_prefix}-deployments"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "deployment_id"
  range_key    = "timestamp"
  
  attribute {
    name = "deployment_id"
    type = "S"
  }
  
  attribute {
    name = "timestamp"
    type = "S"
  }
  
  tags = local.common_tags
}

# ═══════════════════════════════════════════════════════════
# CODECOMMIT REPOSITORY
# ═══════════════════════════════════════════════════════════

resource "aws_codecommit_repository" "main" {
  repository_name = "${local.name_prefix}-repo"
  description     = "Source code repository for ${var.project_name}"
  tags            = local.common_tags
}

# ═══════════════════════════════════════════════════════════
# IAM ROLES
# ═══════════════════════════════════════════════════════════

# CodeBuild Role
data "aws_iam_policy_document" "codebuild_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "${local.name_prefix}-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_trust.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "codebuild_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "s3:GetObject",
      "s3:PutObject",
      "s3:GetObjectVersion",
      "lambda:InvokeFunction"
    ]
    resources = [
      "arn:aws:logs:*:*:log-group:/aws/codebuild/*",
      aws_s3_bucket.artifacts.arn,
      "${aws_s3_bucket.artifacts.arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "codebuild-policy"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild_policy.json
}

# Lambda Role
data "aws_iam_policy_document" "lambda_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "s3:GetObject",
      "sns:Publish"
    ]
    resources = [
      "arn:aws:logs:*:*:*",
      aws_dynamodb_table.deployments.arn,
      "${aws_s3_bucket.artifacts.arn}/*",
      aws_sns_topic.notifications.arn
    ]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "lambda-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

# EventBridge Role
data "aws_iam_policy_document" "events_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "events" {
  name               = "${local.name_prefix}-events-role"
  assume_role_policy = data.aws_iam_policy_document.events_trust.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "events" {
  name = "events-policy"
  role = aws_iam_role.events.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "codebuild:StartBuild"
      Resource = aws_codebuild_project.main.arn
    }]
  })
}

# ═══════════════════════════════════════════════════════════
# CODEBUILD PROJECT
# ═══════════════════════════════════════════════════════════

resource "aws_codebuild_project" "main" {
  name          = "${local.name_prefix}-builder"
  description   = "Build project for ${var.project_name}"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = "30"
  
  environment {
    type                        = "LINUX_CONTAINER"
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    privileged_mode             = false
    image_pull_credentials_type = "CODEBUILD"
  }
  
  source {
    type            = "CODECOMMIT"
    location        = aws_codecommit_repository.main.clone_url_http
    git_clone_depth = 1
    buildspec       = "buildspec/buildspec.yml"
  }
  
  artifacts {
    type     = "S3"
    location = aws_s3_bucket.artifacts.bucket
    path     = "build-output/"
  }
  
  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${local.name_prefix}"
      stream_name = "build-log"
    }
  }
  
  tags = local.common_tags
}

# ═══════════════════════════════════════════════════════════
# LAMBDA FUNCTION
# ═══════════════════════════════════════════════════════════

data "archive_file" "deploy_lambda" {
  type        = "zip"
  source_file = "${path.module}/../lambda/deploy_function.py"
  output_path = "${path.module}/deploy_lambda.zip"
}

resource "aws_lambda_function" "deploy" {
  function_name = "${local.name_prefix}-deploy"
  role          = aws_iam_role.lambda.arn
  handler       = "deploy_function.handler"
  runtime       = "python3.11"
  timeout       = 60
  memory_size   = 128
  
  filename         = data.archive_file.deploy_lambda.output_path
  source_code_hash = data.archive_file.deploy_lambda.output_base64sha256
  
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.deployments.name
      SNS_TOPIC_ARN  = aws_sns_topic.notifications.arn
    }
  }
  
  tags = local.common_tags
}

# ═══════════════════════════════════════════════════════════
# SNS NOTIFICATIONS
# ═══════════════════════════════════════════════════════════

resource "aws_sns_topic" "notifications" {
  name = "${local.name_prefix}-notifications"
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# ═══════════════════════════════════════════════════════════
# EVENTBRIDGE TRIGGER
# ═══════════════════════════════════════════════════════════

resource "aws_cloudwatch_event_rule" "codecommit_trigger" {
  name        = "${local.name_prefix}-codecommit-trigger"
  description = "Trigger CodeBuild on CodeCommit push"
  
  event_pattern = jsonencode({
    source      = ["aws.codecommit"]
    detail-type = ["CodeCommit Repository State Change"]
    detail = {
      event          = ["referenceCreated", "referenceUpdated"]
      repositoryName = [aws_codecommit_repository.main.repository_name]
      referenceType  = ["branch"]
      referenceName  = ["main", "master"]
    }
  })
  
  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "codebuild" {
  rule     = aws_cloudwatch_event_rule.codecommit_trigger.name
  arn      = aws_codebuild_project.main.arn
  role_arn = aws_iam_role.events.arn
}
