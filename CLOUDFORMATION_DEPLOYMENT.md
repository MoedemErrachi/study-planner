# AWS CloudFormation Deployment Guide

This guide deploys Study Planner to AWS using CloudFormation with Auto Scaling Groups for both frontend and backend.

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                    Route 53 (DNS)                    │
└──────────────────┬──────────────────────────────────┘
                   │
┌──────────────────┴──────────────────────────────────┐
│            Internet Gateway                         │
└─────────┬──────────────────────────────┬────────────┘
          │                              │
    ┌─────▼─────┐                  ┌─────▼─────┐
    │ Frontend  │                  │  Backend  │
    │    ALB    │                  │    ALB    │
    └─────┬─────┘                  └─────┬─────┘
          │                              │
    ┌─────▼─────────────┐         ┌──────▼──────────┐
    │   ASG Frontend    │         │   ASG Backend   │
    │  (Nginx + Vite)   │         │  (Node + PM2)   │
    │  (2-4 instances)  │         │  (2-4 instances)│
    └───────────────────┘         └────────┬────────┘
                                           │
                                    ┌──────▼────────┐
                                    │  RDS MySQL    │
                                    │  Multi-AZ     │
                                    └────────────────┘
```

## Prerequisites

1. **AWS Account** with appropriate IAM permissions
2. **AWS CLI** configured locally
3. **VPC Setup**:
   - VPC with 2+ AZs
   - Public subnets for ALBs
   - Private subnets for instances
   - Security groups pre-created with proper ingress/egress rules
4. **RDS MySQL instance** running (see DEPLOYMENT.md)
5. **EC2 Key Pair** created in AWS
6. **GitHub Repo** with project code pushed (already done)

## Step 1: Create Required Exports (VPC Setup)

If you don't have the VPC exports, create a base networking stack first. You need these exports:
- `SGFE` - Frontend Security Group ID
- `SGBE` - Backend Security Group ID
- `PrivateFESubnets` - Private subnets for frontend (comma-separated)
- `PrivateBESubnets` - Private subnets for backend (comma-separated)
- `TGFEArn` - Target Group ARN for frontend ALB
- `TGBEArn` - Target Group ARN for backend ALB

Or create a simple networking CloudFormation stack first.

## Step 2: Deploy Backend Stack

Deploy the backend first (it must be running before frontend can connect to it).

### Via AWS Console

1. Go to **CloudFormation** → **Create Stack**
2. Upload `backend-asg-template.yaml`
3. Fill in parameters:
   - **GitHubRepo**: `https://github.com/MoedemErrachi/study-planner.git`
   - **RDSEndpoint**: Your RDS endpoint (e.g., `study-planner-db.xxxxx.us-east-1.rds.amazonaws.com`)
   - **RDSUser**: `admin`
   - **RDSPassword**: Your RDS password
   - **RDSDatabase**: `study_planner`
   - **Environment**: `dev` (or `staging`/`prod`)
   - **KeyName**: Your EC2 key pair name
4. Click **Create Stack**

### Via AWS CLI

```bash
aws cloudformation create-stack \
  --stack-name study-planner-backend \
  --template-body file://backend-asg-template.yaml \
  --parameters \
    ParameterKey=GitHubRepo,ParameterValue=https://github.com/MoedemErrachi/study-planner.git \
    ParameterKey=RDSEndpoint,ParameterValue=study-planner-db.xxxxx.us-east-1.rds.amazonaws.com \
    ParameterKey=RDSUser,ParameterValue=admin \
    ParameterKey=RDSPassword,ParameterValue=YourRDSPassword \
    ParameterKey=Environment,ParameterValue=dev \
    ParameterKey=KeyName,ParameterValue=my-key-pair
```

### Wait for Stack Completion

```bash
aws cloudformation wait stack-create-complete --stack-name study-planner-backend
echo "Backend stack complete!"
```

Verify instances are healthy in the target group.

## Step 3: Get Backend ALB Endpoint

```bash
# Get backend ALB DNS name
aws cloudformation describe-stacks \
  --stack-name study-planner-backend \
  --query 'Stacks[0].Outputs' \
  --output table

# Or via Load Balancer console
# Copy the DNS name of the Backend ALB
```

## Step 4: Deploy Frontend Stack

Now deploy the frontend, pointing it to the backend ALB.

### Via AWS Console

1. Go to **CloudFormation** → **Create Stack**
2. Upload `frontend-asg-template.yaml`
3. Fill in parameters:
   - **GitHubRepo**: `https://github.com/MoedemErrachi/study-planner.git`
   - **BackendALB**: Backend ALB DNS name (from Step 3)
   - **BackendPort**: `4000`
   - **Environment**: `dev`
   - **KeyName**: Your EC2 key pair name
4. Click **Create Stack**

### Via AWS CLI

```bash
BACKEND_ALB=$(aws cloudformation describe-stacks \
  --stack-name study-planner-backend \
  --query 'Stacks[0].Outputs[0].OutputValue' \
  --output text)

aws cloudformation create-stack \
  --stack-name study-planner-frontend \
  --template-body file://frontend-asg-template.yaml \
  --parameters \
    ParameterKey=GitHubRepo,ParameterValue=https://github.com/MoedemErrachi/study-planner.git \
    ParameterKey=BackendALB,ParameterValue=$BACKEND_ALB \
    ParameterKey=BackendPort,ParameterValue=4000 \
    ParameterKey=Environment,ParameterValue=dev \
    ParameterKey=KeyName,ParameterValue=my-key-pair
```

### Wait for Stack Completion

```bash
aws cloudformation wait stack-create-complete --stack-name study-planner-frontend
echo "Frontend stack complete!"
```

## Step 5: Test the Deployment

### Get Frontend ALB Endpoint

```bash
FRONTEND_ALB=$(aws cloudformation describe-stacks \
  --stack-name study-planner-frontend \
  --query 'Stacks[0].Outputs[0].OutputValue' \
  --output text)

echo "Frontend URL: http://$FRONTEND_ALB"
```

### Test API Connectivity

```bash
# Test backend health
BACKEND_ALB=$(aws cloudformation describe-stacks \
  --stack-name study-planner-backend \
  --query 'Stacks[0].Outputs[0].OutputValue' \
  --output text)

curl http://$BACKEND_ALB:4000/tasks
# Should return: []

# From frontend, this should work
curl http://$FRONTEND_ALB/health
# Should return: healthy
```

### Open in Browser

Open your frontend ALB URL in a browser:
```
http://<FRONTEND_ALB_DNS>
```

Test the app:
1. Add a task
2. Toggle complete
3. Edit task
4. Delete task

## Step 6: Monitor Auto Scaling

### View Auto Scaling Activity

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names asg-study-planner-frontend asg-study-planner-backend
```

### View CloudWatch Metrics

In AWS Console:
- **CloudWatch** → **Dashboards** → Create dashboard
- Add metrics for ASG CPU utilization
- Monitor scaling events

### View Logs

SSH into an instance and check:

```bash
# SSH to frontend instance
ssh -i my-key.pem ec2-user@<FRONTEND_IP>

# Check nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# SSH to backend instance
ssh -i my-key.pem ec2-user@<BACKEND_IP>

# Check PM2 logs
pm2 logs study-planner-api
```

## Step 7: Set Up Custom Domain (Optional)

1. Register domain in **Route 53** or external registrar
2. Create **Route 53 Hosted Zone**
3. Add **Alias Records**:
   - `study-planner.yourdomain.com` → Frontend ALB
   - `api.study-planner.yourdomain.com` → Backend ALB (if needed)
4. Update frontend build to use custom domain:
   ```bash
   VITE_API_URL="http://api.study-planner.yourdomain.com" npm run build
   ```

## Step 8: Enable HTTPS (ACM + ALB Listener)

1. Request certificate in **AWS Certificate Manager**
2. Validate domain ownership
3. Update ALB listeners to use HTTPS (port 443)
4. Redirect HTTP → HTTPS

## Cleanup / Delete Stacks

When done or testing, delete stacks (reverse order):

```bash
# Delete frontend first
aws cloudformation delete-stack --stack-name study-planner-frontend

# Wait for deletion
aws cloudformation wait stack-delete-complete --stack-name study-planner-frontend

# Delete backend
aws cloudformation delete-stack --stack-name study-planner-backend

# Wait for deletion
aws cloudformation wait stack-delete-complete --stack-name study-planner-backend

echo "All stacks deleted!"
```

## Troubleshooting

### Instances Not Healthy
- Check security group ingress rules
- Check ALB target group health checks
- SSH to instance and review logs:
  ```bash
  sudo tail -f /var/log/user-data.log
  pm2 logs
  ```

### Frontend Can't Reach Backend
- Verify backend ALB DNS is correct in frontend stack parameters
- Check VPC peering / security groups between frontend and backend subnets
- Check backend `/health` endpoint:
  ```bash
  curl http://<BACKEND_ALB>:4000/tasks
  ```

### Build Failures
- SSH to instance and manually run build steps
- Check Node.js and npm versions
- Verify GitHub repo is accessible

### Database Connection Errors
- Verify RDS security group allows inbound from backend security group on port 3306
- Check .env variables (RDSEndpoint, credentials)
- Test connection from backend instance:
  ```bash
  mysql -h <RDS_ENDPOINT> -u admin -p -e "SELECT 1;"
  ```

## Cost Optimization

- Use **Savings Plans** or **Reserved Instances** for predictable workloads
- Set up **AWS Budgets** to monitor spending
- Use **Spot Instances** for non-critical environments (add to launch template)
- Clean up unused resources regularly

## Next Steps

1. Set up **CI/CD pipeline** (GitHub Actions → CodeDeploy)
2. Enable **RDS automated backups** and **Multi-AZ**
3. Set up **CloudTrail** for audit logging
4. Configure **VPC Flow Logs** for network monitoring
5. Add **WAF** (Web Application Firewall) to ALBs
6. Enable **GuardDuty** for threat detection
