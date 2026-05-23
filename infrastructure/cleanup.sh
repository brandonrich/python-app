#!/bin/bash
set -e

# ============================================================
# Cleanup Script - Delete All ECS Infrastructure
# ============================================================

AWS_PROFILE="personal"
AWS_REGION="us-east-1"

echo "⚠️  WARNING: This will delete all ECS infrastructure and stop billing."
echo ""
echo "The following stacks will be deleted:"
echo "  - python-demo-service (ALB, ECS Service, Task Definitions)"
echo "  - python-demo-security-groups (Security Groups)"
echo "  - python-demo-cluster (ECS Cluster, ECR Repository)"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Starting cleanup..."

# ============================================================
# Step 1: Delete ECS Service Stack
# ============================================================
echo ""
echo "Step 1: Deleting ECS service (ALB, tasks, target groups)..."
aws cloudformation delete-stack \
  --stack-name python-demo-service \
  --region $AWS_REGION \
  --profile $AWS_PROFILE || echo "Service stack not found or already deleted"

echo "Waiting for service stack to delete (this may take 5-10 minutes)..."
aws cloudformation wait stack-delete-complete \
  --stack-name python-demo-service \
  --region $AWS_REGION \
  --profile $AWS_PROFILE || echo "✅ Service stack deleted"

# ============================================================
# Step 2: Delete Security Groups Stack
# ============================================================
echo ""
echo "Step 2: Deleting security groups..."
aws cloudformation delete-stack \
  --stack-name python-demo-security-groups \
  --region $AWS_REGION \
  --profile $AWS_PROFILE || echo "Security groups stack not found or already deleted"

echo "Waiting for security groups stack to delete..."
aws cloudformation wait stack-delete-complete \
  --stack-name python-demo-security-groups \
  --region $AWS_REGION \
  --profile $AWS_PROFILE || echo "✅ Security groups deleted"

# ============================================================
# Step 3: Delete ECS Cluster and ECR Repository
# ============================================================
echo ""
echo "Step 3: Deleting ECS cluster and ECR repository..."
aws cloudformation delete-stack \
  --stack-name python-demo-cluster \
  --region $AWS_REGION \
  --profile $AWS_PROFILE || echo "Cluster stack not found or already deleted"

echo "Waiting for cluster stack to delete..."
aws cloudformation wait stack-delete-complete \
  --stack-name python-demo-cluster \
  --region $AWS_REGION \
  --profile $AWS_PROFILE || echo "✅ Cluster stack deleted"

echo ""
echo "=========================================="
echo "✅ CLEANUP COMPLETE!"
echo "=========================================="
echo ""
echo "All infrastructure has been deleted."
echo "You will no longer be charged for these resources."
echo ""
