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


# Get ECR repository URI
ECR_URI=$(aws cloudformation describe-stacks \
  --stack-name python-demo-cluster \
  --query 'Stacks[0].Outputs[?OutputKey==`ECRRepositoryUri`].OutputValue' \
  --output text \
  --region $AWS_REGION \
  --profile $AWS_PROFILE)

echo "ECR Repository: $ECR_URI"

# ============================================================
# Step 2: Build and Push Docker Image to ECR
# ============================================================
echo ""
echo "Step 2: Building and pushing Docker image..."

# Login to ECR
aws ecr get-login-password --region $AWS_REGION --profile $AWS_PROFILE | \
  docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build image
echo "Building Docker image..."
docker build -t $SERVICE_NAME:latest .

# Tag and push
echo "Tagging and pushing to ECR..."
docker tag $SERVICE_NAME:latest $ECR_URI:latest
docker push $ECR_URI:latest

echo "✅ Image pushed to ECR!"
