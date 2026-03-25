# Terraform Backend Configuration
# Stores state in S3 with DynamoDB locking

terraform {
  backend "s3" {
    bucket         = "terraform-state-755953012638"
    key            = "devops-pipeline/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
