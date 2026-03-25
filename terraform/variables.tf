variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "devops-pipeline"
}

variable "notification_email" {
  description = "Email for build notifications"
  type        = string
  default     = "talaripradeep45@gmail.com"
}
