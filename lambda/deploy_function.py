#!/usr/bin/env python3
"""Lambda function to handle deployments after CodeBuild."""

import json
import boto3
import os
import logging
from datetime import datetime
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

table_name = os.environ['DYNAMODB_TABLE']
sns_topic_arn = os.environ['SNS_TOPIC_ARN']
table = dynamodb.Table(table_name)


def handler(event, context):
    """Handle deployment after successful build."""
    
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        build_id = event.get('build_id', 'unknown')
        commit_id = event.get('commit_id', 'unknown')
        timestamp = event.get('timestamp', datetime.utcnow().isoformat())
        
        logger.info(f"Processing build {build_id}, commit {commit_id}")
        
        deployment_id = f"deploy-{datetime.utcnow().strftime('%Y%m%d-%H%M%S')}"
        
        deployment_result = {
            'deployment_id': deployment_id,
            'build_id': build_id,
            'commit_id': commit_id[:8] if commit_id else 'unknown',
            'timestamp': timestamp,
            'status': 'IN_PROGRESS',
        }
        
        table.put_item(Item=deployment_result)
        
        # Simulate deployment logic
        logger.info("Starting deployment...")
        
        # Update status to SUCCESS
        deployment_result['status'] = 'SUCCEEDED'
        deployment_result['completed_at'] = datetime.utcnow().isoformat()
        
        table.put_item(Item=deployment_result)
        
        logger.info(f"Deployment {deployment_id} completed successfully")
        
        # Send notification
        sns.publish(
            TopicArn=sns_topic_arn,
            Message=f"✅ Deployment Successful: {deployment_id}",
            Subject='Deployment Successful'
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Deployment completed successfully',
                'deployment_id': deployment_id
            })
        }
        
    except Exception as e:
        logger.error(f"Deployment failed: {str(e)}")
        
        sns.publish(
            TopicArn=sns_topic_arn,
            Message=f"❌ Deployment Failed: {str(e)}",
            Subject='Deployment Failed'
        )
        
        return {
            'statusCode': 500,
            'body': json.dumps({'message': 'Deployment failed', 'error': str(e)})
        }
