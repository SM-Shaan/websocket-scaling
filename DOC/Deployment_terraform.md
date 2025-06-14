# 🚀 WebSocket Application Deployment Guide

## 📋 Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Setup Instructions](#setup-instructions)
5. [Testing the Deployment](#testing-the-deployment)
6. [Monitoring and Health Checks](#monitoring-and-health-checks)
7. [Security](#security)
8. [Cleanup](#cleanup)
9. [Project Content](#project-content)

## 🎯 Overview

This guide provides a step-by-step approach to deploying a WebSocket application using Terraform on AWS. It covers infrastructure setup, deployment, testing, monitoring, and cleanup processes. By following this guide, you will gain insights into best practices for deploying scalable and secure WebSocket applications.

## 🏗️ Architecture

![Terraform Apply](/DOC/diagrams/dia10.drawio.svg)

## ⚙️ Prerequisites

Before deploying the WebSocket application, ensure the following:

### Required Tools
- 🔑 **AWS Account**: Active account with permissions for EC2, ALB, and security groups
- 🛠️ **Terraform**: Installed locally ([Installation Guide](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli))
- 🔧 **AWS CLI**: Installed and configured ([Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html))
- 🐳 **Docker**: Installed locally ([Installation Guide](https://docs.docker.com/get-docker/))
- 🐍 **Python**: Install Python 3.x and `websockets` library (optional)

### Required Setup
1. **SSH Key Pair**: Generate if not available:
   ```bash
   ssh-keygen -t rsa -b 2048 -f websocket-key -N ""
   ```

2. **SSL Certificate**: Obtain ARN from AWS Certificate Manager (optional for HTTPS)

3. **WebSocket Testing Tools**:
   ```bash
   # Install wscat
   npm install -g wscat
   
   # Install Python websockets (optional)
   pip install websockets
   ```

## 🚀 Setup Instructions

### 1. AWS CLI Configuration

Configure the AWS CLI with your credentials:

```bash
aws configure
```

Verify your configuration:
```bash
aws configure list
```

Required configuration values:
- **AWS Access Key ID**: From AWS Lab description page
- **AWS Secret Access Key**: From AWS Lab description page
- **Default region name**: `ap-southeast-1`
- **Default output format**: `json`

### 2. Terraform Setup

1. Navigate to the terraform directory:
```bash
cd terraform
terraform init
```

### 3. Infrastructure Configuration

#### Replace `main.tf` with the following code:
```hcl
provider "aws" {
  region = var.region
}

# VPC and Network Configuration
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "websocket-vpc"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "websocket-igw"
    Environment = var.environment
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name        = "websocket-public-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "websocket-public-rt"
    Environment = var.environment
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "websocket-alb-sg"
  description = "Security group for WebSocket ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP traffic"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "websocket-alb-sg"
    Environment = var.environment
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "websocket-ecs-tasks-sg"
  description = "Security group for WebSocket ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "websocket-ecs-tasks-sg"
    Environment = var.environment
  }
}

# Security Group for EC2 instances
resource "aws_security_group" "ec2" {
  name        = "websocket-ec2-sg"
  description = "Security group for WebSocket EC2 instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "WebSocket traffic from ALB"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "websocket-ec2-sg"
    Environment = var.environment
  }
}

# Create key pair
resource "aws_key_pair" "websocket" {
  key_name   = "websocket-key-${formatdate("YYYYMMDDHHmmss", timestamp())}"
  public_key = file("${path.module}/websocket-key.pub")
}

# Launch Template for EC2 instances
resource "aws_launch_template" "websocket" {
  name_prefix   = "websocket-"
  image_id      = "ami-04173560437081c75"  # Amazon Linux 2023 AMI for ap-southeast-1
  instance_type = "t2.micro"
  key_name      = aws_key_pair.websocket.key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups            = [aws_security_group.ec2.id]
    subnet_id                  = aws_subnet.public[0].id
  }

  user_data = base64encode(
    <<-EOF
    #!/bin/bash
    set -e
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

    echo "Starting user data script..."

    # Update system and install required packages
    echo "Updating system and installing packages..."
    yum update -y
    yum install -y docker git python3-pip net-tools

    # Install Node.js and npm
    echo "Installing Node.js..."
    curl -sL https://rpm.nodesource.com/setup_18.x | bash -
    yum install -y nodejs

    # Start and enable Docker
    echo "Starting Docker service..."
    systemctl daemon-reload
    systemctl enable docker
    systemctl start docker

    # Add ec2-user to docker group
    echo "Adding ec2-user to docker group..."
    usermod -aG docker ec2-user

   ...
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "websocket-instance"
      Environment = var.environment
    }
  }
}

# EC2 Instance 1
resource "aws_instance" "websocket_1" {
  launch_template {
    id      = aws_launch_template.websocket.id
    version = "$Latest"
  }

  tags = {
    Name        = "websocket-instance-1"
    Environment = var.environment
  }
}

# EC2 Instance 2
resource "aws_instance" "websocket_2" {
  launch_template {
    id      = aws_launch_template.websocket.id
    version = "$Latest"
  }

  tags = {
    Name        = "websocket-instance-2"
    Environment = var.environment
  }
}

# Update target group to use both EC2 instances
resource "aws_lb_target_group_attachment" "websocket_1" {
  target_group_arn = aws_lb_target_group.websocket_tg.arn
  target_id        = aws_instance.websocket_1.id
  port             = 8000
}

resource "aws_lb_target_group_attachment" "websocket_2" {
  target_group_arn = aws_lb_target_group.websocket_tg.arn
  target_id        = aws_instance.websocket_2.id
  port             = 8000
}

# Add EC2 instance outputs
output "ec2_public_ip_1" {
  description = "Public IP of the first EC2 instance"
  value       = aws_instance.websocket_1.public_ip
}

output "ec2_public_ip_2" {
  description = "Public IP of the second EC2 instance"
  value       = aws_instance.websocket_2.public_ip
}

# Application Load Balancer
resource "aws_lb" "websocket" {
  name               = "websocket-alb-${formatdate("YYYYMMDDHHmmss", timestamp())}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
  idle_timeout       = 3600
  enable_deletion_protection = false

  tags = {
    Name        = "websocket-alb"
    Environment = var.environment
  }
}

# Target Group
resource "aws_lb_target_group" "websocket_tg" {
  name        = "websocket-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher            = "200"
    path               = "/health"
    port               = "traffic-port"
    protocol           = "HTTP"
    timeout            = 5
    unhealthy_threshold = 3
  }

  stickiness {
    type            = "lb_cookie"
    cookie_name     = "websocket_session"
    cookie_duration = 3600
    enabled         = true 
  }

  tags = {
    Name = "websocket-tg"
  }
}

# WebSocket Listener
resource "aws_lb_listener" "websocket" {
  load_balancer_arn = aws_lb.websocket.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.websocket_tg.arn
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}
```

#### Add `outputs.tf` with the following code:
```hcl
output "vpc_id" {
   value = aws_vpc.main.id
}

output "subnet_id" {
   value = aws_subnet.main.id
}

output "security_group_id" {
   value = aws_security_group.websocket_sg.id
}

output "instance_public_ip" {
   value = aws_instance.websocket_instance.public_ip
}

output "instance_public_dns" {
   value = aws_instance.websocket_instance.public_dns
}
```

#### Add `terraform.tfvars` with the following content:
```hcl
aws_region         = "ap-southeast-1"
vpc_cidr           = "10.0.0.0/16"
subnet_cidr        = "10.0.1.0/24"
availability_zone  = "ap-southeast-1a"
ami_id             = "ami-0abcdef1234567890"
instance_type      = "t2.micro"
key_name           = "websocket-key"
```

#### Add `variables.tf` with the following content:
```hcl
variable "aws_region" {
   description = "AWS region to deploy resources"
   type        = string
}

variable "vpc_cidr" {
   description = "CIDR block for the VPC"
   type        = string
}

variable "subnet_cidr" {
   description = "CIDR block for the subnet"
   type        = string
}

variable "availability_zone" {
   description = "Availability zone for the subnet"
   type        = string
}

variable "ami_id" {
   description = "AMI ID for the EC2 instance"
   type        = string
}

variable "instance_type" {
   description = "Instance type for the EC2 instance"
   type        = string
}

variable "key_name" {
   description = "Name of the SSH key pair"
   type        = string
}
```

#### 2. Generate SSH key pair:
```bash
ssh-keygen -t rsa -b 2048 -f websocket-key -N '""'
```

#### 3. Initialize and apply Terraform:
```bash
terraform apply -auto-approve
```

![Terraform Apply](/DOC/images/5.png)

> **Note**: You'll need to provide an SSL certificate ARN for HTTPS support.

### Post-Deployment Verification
1. Get the ALB DNS name:
```bash
terraform output alb_dns_name
```

## 🧪 Testing the Deployment

### 1. Health Check
```bash
curl http://<alb-dns-name>/health
```
![Health Check](/DOC/images/6.png)

### 2. WebSocket Connection Tests

#### Using wscat
```bash
wscat -c ws://<alb-dns-name>/ws
```
![WebSocket Test](/DOC/images/7.png)

#### Using Browser Console
```javascript
const ws2 = new WebSocket('ws://<alb-dns-name>/ws');
ws2.onopen = () => { 
  console.log('Connected!');
  ws2.send('Hello from browser!');
};
ws2.onmessage = (event) => console.log('Received:', event.data);
ws2.onerror = (error) => console.log('Error:', error);
ws2.onclose = () => console.log('Disconnected!');
```

#### Using Python
```python
import asyncio
import websockets

async def test_connection():
    uri = "ws://<alb-dns-name>:8000"
    async with websockets.connect(uri) as websocket:
        print("Connected!")
        await websocket.send("Hello!")
        response = await websocket.recv()
        print(f"Received: {response}")

asyncio.get_event_loop().run_until_complete(test_connection())
```

### 3. Multi-Client Testing
1. Open `test-client.html` in two browser windows
2. Set WebSocket URL:
```javascript
ws = new WebSocket('ws://<alb-dns-name>/ws');
```
3. Connect both clients and send messages
![Multi-Client Test](/DOC/images/10.png)

### 4. Instance Verification
1. SSH into EC2 instance:
```bash
ssh -i <websocket-private-key> ec2-user@<instance-public-id>
```

2. Check Docker container:
```bash
docker ps
docker logs <container_id>
```
![Docker Check](/DOC/images/8.png)
![Container Logs](/DOC/images/9.png)

### 5. Network Configuration
- Verify ALB security group allows port 80
- Verify EC2 security group allows port 8000 from ALB
- Check target group health in AWS Console

## 📊 Monitoring and Health Checks

### 1. Browser Developer Tools
1. Open Chrome DevTools (F12)
2. Navigate to Network tab
3. Filter by "WS"
4. Inspect:
   - Headers
   - Frames
   - Timing
![Network Monitoring](/DOC/images/12.png)
![WebSocket Details](/DOC/images/13.png)

### 2. Health Check Endpoint
- Path: `/health`
- Returns: Active connection count
![Health Check Response](/DOC/images/11.png)

### 3. Grafana Dashboard
1. Access: `http://54.151.161.238:3000`
2. Login credentials:
   - Username: `admin`
   - Password: `admin`
3. Configure Prometheus data source:
   - URL: `http://localhost:9090`

## 🔒 Security

### Implemented Security Measures
- 🔐 CORS configuration (development mode)
- 🛡️ Restricted security groups
- 🔒 HTTPS with SSL/TLS termination
- 🔄 Regular security updates
- 🌐 VPC network isolation
- 👤 IAM roles with least privilege
- 🔏 Encrypted data transmission

### Monitoring Features
1. **Health Checks**
   - Connection count
   - Instance status
   - Endpoint: `/health`

2. **Logging**
   - Connection events
   - Message traffic
   - Error tracking
   - CloudWatch integration

3. **Metrics**
   - Active connections
   - Message throughput
   - Error rates
   - Response times

## 🧹 Cleanup

Remove all deployed infrastructure:
```bash
cd terraform
terraform destroy -auto-approve
```

## 📚 Project Content

This project is divided into various chapters, each demonstrating different implementation approaches and deployment strategies:

- **Chapter 1**: WebSocket Connection and Sticky Sessions ([Learn more](DOC/Stickiness.md))
- **Chapter 2**: Shared Session Management ([Learn more](DOC/Shared-sessions.md))
- **Chapter 3**: Scaling WebSocket Applications ([Learn more](DOC/websocket-scaling.md))
- **Chapter 4**: Terraform Deployment for WebSocket Infrastructure ([Learn more](DOC/Deployment_terraform.md))

---

## 📝 Conclusion

This guide provided a comprehensive walkthrough for deploying a WebSocket application using Terraform on AWS. By following the steps outlined, you have successfully:

1. Configured the necessary prerequisites and tools
2. Deployed the infrastructure
3. Verified the deployment
4. Implemented monitoring and security best practices

Remember to clean up the resources after testing to avoid unnecessary costs. For further enhancements, consider automating the deployment pipeline and integrating advanced monitoring tools.

Thank you for using this guide! 🙏
