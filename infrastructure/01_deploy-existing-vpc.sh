#!/bin/bash
set -e

# ============================================================
# Deploy Python Demo App to ECS using Existing VPC
# ============================================================

# Configuration - Update these values for your environment
AWS_PROFILE="personal"
AWS_REGION="us-east-1"

# Existing VPC Configuration
VPC_ID="vpc-85ab11e2"
PUBLIC_SUBNET_1="subnet-0710342d"   # us-east-1a
PUBLIC_SUBNET_2="subnet-7f160209"   # us-east-1b
PRIVATE_SUBNET_1="subnet-f3dff9ab"  # us-east-1c (or use same as public if no private)
PRIVATE_SUBNET_2="subnet-260b331b"  # us-east-1e (or use same as public if no private)

# ECS Configuration
CLUSTER_NAME="python-demo-cluster"
SERVICE_NAME="python-demo-app"
APP_PORT=5001
DESIRED_COUNT=2

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile $AWS_PROFILE)
echo "AWS Account ID: $ACCOUNT_ID"

# ============================================================
# Step 1: Create ECS Cluster and ECR Repository
# ============================================================
echo ""
echo "Step 1: Creating ECS Cluster and ECR Repository..."
aws cloudformation create-stack \
  --stack-name python-demo-cluster \
  --template-body file://infrastructure/ecs-cluster.yaml \
  --parameters ParameterKey=ClusterName,ParameterValue=$CLUSTER_NAME \
  --region $AWS_REGION \
  --profile $AWS_PROFILE

echo "Waiting for cluster stack to complete..."
aws cloudformation wait stack-create-complete \
  --stack-name python-demo-cluster \
  --region $AWS_REGION \
  --profile $AWS_PROFILE

echo "✅ Cluster created!"
