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

# check the security group configuration
```bash
aws ec2 describe-security-groups --filters "Name=group-name,Values=websocket-sg-*" --query "SecurityGroups[*].[GroupId,GroupName,IpPermissions]" --output json
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

## If websocket connection fails like:
```txt
7:10:31 PM - Attempting to connect...
7:10:32 PM - WebSocket Error: error
7:10:32 PM - Connection closed. Code: 1006, Reason: No reason provided
7:10:32 PM - Attempting to reconnect (1/3)...
```

Then, try the following commands: 
```bash
#First, let's SSH into one of the EC2 instances and check if Docker is installed and running:
ssh -i E:\websocket\terraform\websocket-key ec2-user@13.229.135.195 "sudo yum install -y docker && sudo systemctl start docker && sudo systemctl enable docker && sudo usermod -a -G docker ec2-user"

#Now that Docker is installed, let's copy our application files to the EC2 instance:
scp -i E:\websocket\terraform\websocket-key app.py requirements.txt Dockerfile ec2-user@13.229.135.195:~/

# Now let's build and run the Docker container on the EC2 instance:
ssh -i E:\websocket\terraform\websocket-key ec2-user@13.229.135.195 "docker build -t websocket-app . && docker run -d -p 8000:8000 --name websocket-app websocket-app"

# verify that both containers are running and check their logs
ssh -i E:\websocket\terraform\websocket-key ec2-user@52.77.245.76 "docker ps && docker logs websocket-app"
```

## Check stickiness of target group:
```bash
aws elbv2 describe-target-groups --names websocket-tg --query 'TargetGroups[0].StickinessConfig'
```

## For local development: find where k6 is installed:
```bash
Get-ChildItem -Path "C:\Program Files\k6" -ErrorAction SilentlyContinue
# Then, run
& 'C:\Program Files\k6\k6.exe' run load-test.js
```

## For deployment: 
###  check if we can access Grafana:
```bash
Invoke-WebRequest -Uri "http://54.255.207.156:3000/api/health" -UseBasicParsing | Select-Object -ExpandProperty Content
```
### access the Prometheus metrics endpoint directly:
```bash
Invoke-WebRequest -Uri "http://54.255.207.156:9090/metrics" -UseBasicParsing | Select-Object -ExpandProperty Content
```
### check if we can access Grafana and verify the Prometheus datasource:
```bash

```
##  verify if the WebSocket instances are running and accessible:
```bash
Invoke-WebRequest -Uri "http://52.221.201.44:8000/health" -UseBasicParsing | Select-Object -ExpandProperty Content
# The WebSocket instances are not accessible directly from the internet if they're in a private subnet, then: 
Invoke-WebRequest -Uri "http://websocket-alb-20250612035316-1435454575.ap-southeast-1.elb.amazonaws.com/health" -UseBasicParsing | Select-Object -ExpandProperty Content
```

## check if we can access the metrics endpoint through the ALB:
```bash
Invoke-WebRequest -Uri "http://websocket-alb-20250612035316-1435454575.ap-southeast-1.elb.amazonaws.com/metrics" -UseBasicParsing | Select-Object -ExpandProperty Content
```

##  check if we can access Prometheus and verify it's scraping metrics from our WebSocket instances
```bash
curl http://54.255.207.156:9090/api/v1/targets
```

## check if we can access Grafana and verify the Prometheus datasource is configured
```bash
$pair = "admin:admin"; $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair)); $basicAuthValue = "Basic $encodedCreds"; Invoke-WebRequest -Uri "http://54.255.207.156:3000/api/datasources" -Headers @{Authorization = $basicAuthValue}
```

## verify the metrics endpoint is accessible on one of the WebSocket instances::
```bash
curl http://52.221.201.44:8000/metrics
```

## verify if Prometheus is running and accessible:
```bash
curl http://localhost:9090/-/healthy
```
## After SSH into Ec2 instances, if Docker-compose is not installed:
```bash
sudo yum install -y docker-compose
# If that doesn't work, we can install it using pip:
sudo yum install -y python3-pip
sudo pip3 install docker-compose

# After installing Docker Compose, let's check if Docker is running
sudo systemctl status docker
```

## check if Prometheus is accessible from Grafana:
```bash
docker-compose exec grafana wget -qO- http://prometheus:9090/api/v1/status/config
```
## verify if Prometheus is actually receiving metrics from k6 by checking its targets:
```bash
curl -s http://localhost:9090/api/v1/targets
```
## check if Prometheus is now storing the metrics from k6.
```bash
docker-compose exec prometheus wget -qO- 'http://localhost:9090/api/v1/query?query=ws_connection_success_rate'
```
## ping Prometheus from within the k6 container.
```bash
docker-compose exec k6 ping prometheus
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

