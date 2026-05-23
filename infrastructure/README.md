# Infrastructure as Code - CloudFormation Templates

This directory contains CloudFormation templates for deploying the Python Demo App to AWS ECS.

## Files

### vpc-and-security.yaml
**Network Infrastructure**

Creates the networking layer:
- **VPC** (10.0.0.0/16): Virtual private cloud
- **Public Subnets** (2): Host Application Load Balancer
  - 10.0.1.0/24 in us-east-1a
  - 10.0.2.0/24 in us-east-1b
- **Private Subnets** (2): Host ECS tasks
  - 10.0.10.0/24 in us-east-1a
  - 10.0.11.0/24 in us-east-1b
- **Internet Gateway**: Allows public subnet traffic to internet
- **Security Groups**:
  - ALB SG: Allows HTTP (80) and HTTPS (443) from 0.0.0.0/0
  - ECS SG: Allows port 5001 from ALB SG only

**Stack Output Exports:**
- `python-demo-vpc-id`: VPC ID
- `python-demo-public-subnet-1` & `2`: Public subnet IDs
- `python-demo-private-subnet-1` & `2`: Private subnet IDs
- `python-demo-alb-sg`: ALB security group ID
- `python-demo-ecs-sg`: ECS security group ID

---

### ecs-cluster.yaml
**Container Registry & Cluster**

Sets up the container infrastructure:
- **ECR Repository**:
  - Private Docker registry named `python-demo-app`
  - Image scanning enabled (scans on push)
  - Lifecycle policy keeps last 5 images
- **ECS Cluster**:
  - Fargate cluster with Container Insights enabled
  - Supports both FARGATE and FARGATE_SPOT capacity providers
  - Default strategy: 1 base FARGATE task, burst with FARGATE
- **CloudWatch Log Group**:
  - Centralized logging: `/ecs/python-demo-app`
  - 7-day retention

**Stack Output Exports:**
- `python-demo-ecs-cluster-name`: Cluster name
- `python-demo-ecr-uri`: ECR repository URI (use for pushing images)
- `python-demo-ecs-log-group`: CloudWatch log group name

---

### ecs-service.yaml
**Service, Load Balancing, & Auto Scaling**

Deploys the application:

**Load Balancer:**
- Application Load Balancer (internet-facing)
- Listens on HTTP:80 (add HTTPS in production)
- Target group with health checks every 30s on `/health` endpoint

**ECS Service:**
- Runs on Fargate (no server management)
- 2 tasks running by default, up to 4 with auto scaling
- Each task: 256 vCPU, 512 MB memory (configurable)
- Assigns public IPs to tasks
- Deployment circuit breaker enabled (auto-rollback on failure)
- Health checks ensure only healthy tasks receive traffic

**IAM Roles:**
- **ECSTaskExecutionRole**: Allows pulling images from ECR, writing logs to CloudWatch
- **ECSTaskRole**: Application permissions (extensible for app needs)

**Auto Scaling:**
- Scales from 2-4 tasks
- Tracks CPU utilization (target: 70%)
- Scale-up happens in 60 seconds
- Scale-down waits 300 seconds (5 minutes) to avoid flapping

**Parameters:**
- `ImageUri`: Docker image from ECR (required)
- `ServiceName`: Service name (default: python-demo-app)
- `ContainerPort`: App port (default: 5001)
- `DesiredCount`: Initial task count (default: 2)
- `TaskCpu`: vCPU units (options: 256, 512, 1024... default: 256)
- `TaskMemory`: Memory in MB (options: 512, 1024, 2048... default: 512)

**Stack Output Exports:**
- `python-demo-alb-dns`: DNS name of load balancer
- `python-demo-ecs-service-name`: Service name
- `python-demo-task-definition-arn`: Task definition ARN

---

## Deployment Commands

### 1. Create VPC Stack
```bash
aws cloudformation create-stack \
  --stack-name python-demo-vpc \
  --template-body file://infrastructure/vpc-and-security.yaml \
  --region us-east-1
```

### 2. Create Cluster Stack
```bash
aws cloudformation create-stack \
  --stack-name python-demo-cluster \
  --template-body file://infrastructure/ecs-cluster.yaml \
  --region us-east-1
```

### 3. Get ECR Repository URI
```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=us-east-1
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/python-demo-app:latest"
echo "ECR URI: $ECR_URI"
```

### 4. Push Initial Image to ECR
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Build and push
docker build -t $ECR_URI .
docker push $ECR_URI
```

### 5. Create Service Stack
```bash
aws cloudformation create-stack \
  --stack-name python-demo-service \
  --template-body file://infrastructure/ecs-service.yaml \
  --parameters ParameterKey=ImageUri,ParameterValue=$ECR_URI \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

---

## Updating Stacks

### Update Parameter Values
```bash
aws cloudformation update-stack \
  --stack-name python-demo-service \
  --template-body file://infrastructure/ecs-service.yaml \
  --parameters \
    ParameterKey=ImageUri,ParameterValue=$ECR_URI \
    ParameterKey=DesiredCount,ParameterValue=3 \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

### Update Template Only
```bash
aws cloudformation update-stack \
  --stack-name python-demo-vpc \
  --template-body file://infrastructure/vpc-and-security.yaml \
  --region us-east-1
```

---

## Monitoring

### Check Stack Status
```bash
aws cloudformation describe-stacks \
  --stack-name python-demo-vpc \
  --region us-east-1 \
  --query 'Stacks[0].StackStatus'
```

### View Stack Events
```bash
aws cloudformation describe-stack-events \
  --stack-name python-demo-service \
  --region us-east-1
```

### Get Output Values
```bash
aws cloudformation describe-stacks \
  --stack-name python-demo-service \
  --query 'Stacks[0].Outputs' \
  --region us-east-1
```

---

## Cleanup

### Delete Service Stack
```bash
aws cloudformation delete-stack --stack-name python-demo-service --region us-east-1
aws cloudformation wait stack-delete-complete --stack-name python-demo-service --region us-east-1
```

### Delete Cluster Stack
```bash
aws cloudformation delete-stack --stack-name python-demo-cluster --region us-east-1
aws cloudformation wait stack-delete-complete --stack-name python-demo-cluster --region us-east-1
```

### Delete VPC Stack
```bash
aws cloudformation delete-stack --stack-name python-demo-vpc --region us-east-1
aws cloudformation wait stack-delete-complete --stack-name python-demo-vpc --region us-east-1
```

---

## Cost Estimation (US East 1)

**Minimum (2 tasks, t3.micro equivalent):**
- ECS Fargate: ~$15/month
- ALB: ~$16/month
- Data transfer: Variable
- **Total: ~$31+/month**

**With Auto Scaling to 4 tasks:**
- ECS Fargate: ~$31/month
- ALB: ~$16/month
- **Total: ~$47+/month**

**With Fargate Spot (70% discount):**
- Mix 1 Fargate + 1-3 Fargate Spot
- Savings: ~$10-15/month

See AWS Pricing Calculator for exact estimates: https://calculator.aws/

---

## Best Practices

1. **Use private subnets for ECS tasks** — NAT gateway for outbound internet
2. **Enable ALB access logs** — Audit and troubleshoot traffic
3. **Use HTTPS in production** — Add ACM certificate and HTTPS listener
4. **Set up RDS in private subne** — Separate database from application
5. **Use CloudWatch alarms** — Monitor CPU, memory, error rates
6. **Enable VPC Flow Logs** — Network troubleshooting
7. **Use IAM instance profiles** — Least privilege access
8. **Implement blue-green deployments** — Zero-downtime updates

---

## References

- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/best_practices.html)
- [Fargate Pricing](https://aws.amazon.com/fargate/pricing/)
