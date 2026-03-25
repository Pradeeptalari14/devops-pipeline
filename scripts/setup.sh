#!/bin/bash
set -e

echo "🚀 Setting up DevOps Pipeline..."

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="terraform-state-$ACCOUNT_ID"

# Create S3 bucket if needed
if ! aws s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
    echo "Creating S3 bucket for Terraform state..."
    aws s3 mb "s3://$BUCKET_NAME" --region ap-south-1
    aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled
fi

# Create DynamoDB table for locking
if ! aws dynamodb describe-table --table-name "terraform-locks" 2>/dev/null; then
    echo "Creating DynamoDB table for state locking..."
    aws dynamodb create-table \
        --table-name "terraform-locks" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST
fi

# Initialize Terraform
cd terraform
echo "Initializing Terraform..."
terraform init

echo "✅ Setup complete!"
echo "Next: terraform plan && terraform apply"
