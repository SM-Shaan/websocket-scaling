# WebSocket Server Troubleshooting Guide

## Table of Contents
- [AWS Permission Issues](#aws-permission-issues)
- [Connection Issues](#connection-issues)
- [Port Conflicts](#port-conflicts)
- [SSH Key Setup](#ssh-key-setup)
- [WebSocket Client Setup](#websocket-client-setup)
- [Infrastructure Verification](#infrastructure-verification)
- [Logs and Debugging](#logs-and-debugging)
- [Security Group Verification](#security-group-verification)

## AWS Permission Issues

### Service-Linked Role Creation
If you encounter permission issues with Elastic Load Balancing, create the service-linked role:
```bash
aws iam create-service-linked-role --aws-service-name elasticloadbalancing.amazonaws.com
```

## Connection Issues

### Check Server Logs
If connections are failing, check these logs:
```bash
# EC2 instance logs
cat /var/log/user-data.log

# Docker container logs
docker logs websocket-app

# Application logs
cat /home/ec2-user/logs/websocket_server.log
```

### Health Check Endpoint
Verify server health:
```bash
curl http://websocket-alb-20250608061811-154881805.ap-southeast-1.elb.amazonaws.com/health
```

## Port Conflicts

### Check Port Usage
Verify if port 8000 is available:
```bash
netstat -ano | findstr :8000
```

## SSH Key Setup

### Generate SSH Key Pair
```bash
# Navigate to terraform directory
cd terraform

# Generate key pair
ssh-keygen -t rsa -b 2048 -f websocket-key -N '""'

# Set correct permissions for the private key
icacls websocket-key /inheritance:r /grant:r "$($env:USERNAME):(R,W)"

# Verify key permissions
ls -l terraform/websocket-key
```

## WebSocket Client Setup

### Install WSCAT
For command-line WebSocket testing:
```bash
sudo npm install -g wscat
```

## Infrastructure Verification

### Check ALB Status
```bash
# Get ALB DNS name and state
aws elbv2 describe-load-balancers --query 'LoadBalancers[*].{DNSName:DNSName,State:State.Code}' --output table
```

### Check EC2 Instances
```bash
# Get instance status and IPs
aws ec2 describe-instances --filters "Name=tag:Name,Values=websocket-instance*" --query 'Reservations[*].Instances[*].{InstanceId:InstanceId,State:State.Name,PublicIP:PublicIpAddress}' --output table
```

### Verify Target Group Health
```bash
# Check target group health
aws elbv2 describe-target-health --target-group-arn $(aws elbv2 describe-target-groups --names websocket-tg-* --query 'TargetGroups[0].TargetGroupArn' --output text)
```

### Check Terraform State
```bash
# List all managed resources
cd terraform
terraform state list
```

## Infrastructure Components

### Required Components
1. VPC with:
   - Public subnets
   - Private subnets
   - NAT Gateway for private subnet internet access
   - ALB in public subnet for external access

## Security Group Verification

### Required Security Group Rules
1. ALB Security Group:
   - Inbound: Port 80/443 from 0.0.0.0/0
   - Outbound: All traffic

2. EC2 Security Group:
   - Inbound: Port 8000 from ALB security group
   - Outbound: All traffic

### Verify Security Groups
```bash
# Check security group rules
aws ec2 describe-security-groups --filters "Name=group-name,Values=websocket-*" --query 'SecurityGroups[*].{GroupName:GroupName,IpPermissions:IpPermissions,IpPermissionsEgress:IpPermissionsEgress}' --output table
```

## Common Issues and Solutions

1. **Connection Timeouts**
   - Check security group rules
   - Verify ALB health checks
   - Check instance status

2. **WebSocket Upgrade Failures**
   - Verify ALB listener rules
   - Check application logs
   - Verify client connection URL

3. **Instance Health Issues**
   - Check instance system logs
   - Verify application is running
   - Check resource utilization

4. **ALB Issues**
   - Verify target group health
   - Check listener rules
   - Verify security group rules

