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
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "websocket-ec2-sg"
    Environment = var.environment
  }
}

# Launch Template for EC2 instances
resource "aws_launch_template" "websocket" {
  name_prefix   = "websocket-"
  image_id      = "ami-04173560437081c75"  # Amazon Linux 2023 AMI for ap-southeast-1
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups            = [aws_security_group.ec2.id]
    subnet_id                  = aws_subnet.public[0].id
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              systemctl start docker
              systemctl enable docker
              
              # Replace the following line with your actual Docker image
              # Format: docker run -d -p 8000:8000 [YOUR_REGISTRY]/[YOUR_IMAGE_NAME]:[TAG]
              # Examples:
              # - For Docker Hub: docker run -d -p 8000:8000 yourusername/websocket-app:latest
              # - For ECR: docker run -d -p 8000:8000 aws_account_id.dkr.ecr.region.amazonaws.com/websocket-app:latest
              # - For local image: docker run -d -p 8000:8000 websocket-app:latest
              docker run -d -p 8000:8000 websocket-app:latest
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

# EC2 Instance
resource "aws_instance" "websocket" {
  launch_template {
    id      = aws_launch_template.websocket.id
    version = "$Latest"
  }

  tags = {
    Name        = "websocket-instance"
    Environment = var.environment
  }
}

# Update target group to use EC2 instance
resource "aws_lb_target_group_attachment" "websocket" {
  target_group_arn = aws_lb_target_group.websocket.arn
  target_id        = aws_instance.websocket.id
  port             = 8000
}

# Add EC2 instance output
output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.websocket.public_ip
}

# Application Load Balancer
resource "aws_lb" "websocket" {
  name               = "websocket-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name        = "websocket-alb"
    Environment = var.environment
  }
}

# Target Group
resource "aws_lb_target_group" "websocket" {
  name        = "websocket-tg-unique"
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
    unhealthy_threshold = 2
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  tags = {
    Name        = "websocket-tg"
    Environment = var.environment
  }
}

# HTTP Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.websocket.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.websocket.arn
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}
