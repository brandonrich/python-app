#!/bin/bash
set -e

# ============================================================
# Deploy Python Demo App to ECS using Split Templates
# ============================================================

# Configuration - Update these values for your environment
AWS_PROFILE="personal"
AWS_REGION="us-east-1"

# Existing VPC Configuration
VPC_ID="vpc-85ab11e2"
PUBLIC_SUBNET_1="subnet-0710342d"   # us-east-1a
PUBLIC_SUBNET_2="subnet-7f160209"   # us-east-1b

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

# ============================================================
# Step 3: Create Security Groups in Existing VPC
# ============================================================
echo ""
echo "Step 3: Creating security groups in existing VPC..."
aws cloudformation create-stack \
  --stack-name python-demo-security-groups \
  --template-body file://infrastructure/security-groups-existing-vpc.yaml \
  --parameters \
    ParameterKey=VpcId,ParameterValue=$VPC_ID \
    ParameterKey=AppPort,ParameterValue=$APP_PORT \
  --region $AWS_REGION \
  --profile $AWS_PROFILE

echo "Waiting for security groups to be created..."
aws cloudformation wait stack-create-complete \
  --stack-name python-demo-security-groups \
  --region $AWS_REGION \
  --profile $AWS_PROFILE

echo "✅ Security groups created!"

# Get security group IDs
ALB_SG_ID=$(aws cloudformation describe-stacks \
  --stack-name python-demo-security-groups \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBSecurityGroupId`].OutputValue' \
  --output text \
  --region $AWS_REGION \
  --profile $AWS_PROFILE)

ECS_SG_ID=$(aws cloudformation describe-stacks \
  --stack-name python-demo-security-groups \
  --query 'Stacks[0].Outputs[?OutputKey==`ECSSecurityGroupId`].OutputValue' \
  --output text \
  --region $AWS_REGION \
  --profile $AWS_PROFILE)

echo "ALB Security Group: $ALB_SG_ID"
echo "ECS Security Group: $ECS_SG_ID"

# ============================================================
# Step 4: Deploy Load Balancer (Separate Stack)
# ============================================================
echo ""
echo "Step 4: Deploying Application Load Balancer..."
aws cloudformation create-stack \
  --stack-name python-demo-alb \
  --template-body file://infrastructure/ecs-alb.yaml \
  --parameters \
    ParameterKey=VpcId,ParameterValue=$VPC_ID \
    ParameterKey=PublicSubnet1Id,ParameterValue=$PUBLIC_SUBNET_1 \
    ParameterKey=PublicSubnet2Id,ParameterValue=$PUBLIC_SUBNET_2 \
    ParameterKey=ALBSecurityGroupId,ParameterValue=$ALB_SG_ID \
    ParameterKey=ContainerPort,ParameterValue=$APP_PORT \
  --region $AWS_REGION \
  --profile $AWS_PROFILE

echo "Waiting for ALB stack to complete..."
aws cloudformation wait stack-create-complete \
  --stack-name python-demo-alb \
  --region $AWS_REGION \
  --profile $AWS_PROFILE

echo "✅ Load Balancer deployed!"

# Get Target Group ARN
TG_ARN=$(aws cloudformation describe-stacks \
  --stack-name python-demo-alb \
  --query 'Stacks[0].Outputs[?OutputKey==`TargetGroupArn`].OutputValue' \
  --output text \
  --region $AWS_REGION \
  --profile $AWS_PROFILE)

echo "Target Group ARN: $TG_ARN"

# ============================================================
# Step 5: Deploy ECS Service
# ============================================================
echo ""
echo "Step 5: Deploying ECS service..."
aws cloudformation create-stack \
  --stack-name python-demo-service \
  --template-body file://infrastructure/ecs-service-existing-vpc.yaml \
  --parameters \
    ParameterKey=VpcId,ParameterValue=$VPC_ID \
    ParameterKey=PublicSubnet1Id,ParameterValue=$PUBLIC_SUBNET_1 \
    ParameterKey=PublicSubnet2Id,ParameterValue=$PUBLIC_SUBNET_2 \
    ParameterKey=ECSSecurityGroupId,ParameterValue=$ECS_SG_ID \
    ParameterKey=ECSClusterName,ParameterValue=$CLUSTER_NAME \
    ParameterKey=ImageUri,ParameterValue=$ECR_URI:latest \
    ParameterKey=ServiceName,ParameterValue=$SERVICE_NAME \
    ParameterKey=ContainerPort,ParameterValue=$APP_PORT \
    ParameterKey=DesiredCount,ParameterValue=$DESIRED_COUNT \
    ParameterKey=TargetGroupArn,ParameterValue=$TG_ARN \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $AWS_REGION \
  --profile $AWS_PROFILE

echo "Waiting for service stack to complete (this may take 5-10 minutes)..."
aws cloudformation wait stack-create-complete \
  --stack-name python-demo-service \
  --region $AWS_REGION \
  --profile $AWS_PROFILE

echo "✅ Service deployed!"

# ============================================================
# Get Load Balancer DNS
# ============================================================
ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name python-demo-alb \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
  --output text \
  --region $AWS_REGION \
  --profile $AWS_PROFILE)

echo ""
echo "=========================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "=========================================="
echo ""
echo "Your application is now running at:"
echo "http://$ALB_DNS"
echo ""
echo "Try these endpoints:"
echo "  Health: http://$ALB_DNS/health"
echo "  API: http://$ALB_DNS/api/greeting"
echo "  Root: http://$ALB_DNS/"
echo ""
echo "Note: It may take 2-3 minutes for the load balancer to become healthy."
echo ""
