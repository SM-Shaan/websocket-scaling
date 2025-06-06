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
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "WebSocket port"
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
    description     = "WebSocket from ALB"
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

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Update system and install required packages
    yum update -y
    yum install -y docker git python3-pip net-tools

    # Install Node.js and npm
    curl -sL https://rpm.nodesource.com/setup_18.x | bash -
    yum install -y nodejs

    # Start and enable Docker
    systemctl daemon-reload
    systemctl enable docker
    systemctl start docker

    # Add ec2-user to docker group
    usermod -aG docker ec2-user

    # Create project directory
    PROJECT_DIR="/home/ec2-user/websocket"
    mkdir -p $PROJECT_DIR
    cd $PROJECT_DIR

    # Create requirements.txt
    cat > requirements.txt << "REQEOF"
    fastapi==0.109.2
    uvicorn==0.27.1
    websockets==12.0
    python-multipart==0.0.9
    python-dotenv==1.0.1
    REQEOF

    # Create app.py
    cat > app.py << "APPEOF"
    from fastapi import FastAPI, WebSocket, WebSocketDisconnect
    from fastapi.middleware.cors import CORSMiddleware
    import uvicorn
    import json
    import logging
    logger = logging.getLogger("uvicorn")

    app = FastAPI()

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    active_connections: dict[str, WebSocket] = {}
    @app.get("/")
    async def root():
      return {"message": "WebSocket server is running"}

    @app.get("/health")
    async def health_check():
        return {
            "status": "healthy",
            "connections": len(active_connections),
            "active_clients": list(active_connections.keys())
        }

    @app.websocket("/ws")
    async def websocket_endpoint(websocket: WebSocket):
        try:
            await websocket.accept()
            client_id = str(id(websocket))
            active_connections[client_id] = websocket
            logger.info(f"New WebSocket connection established: {client_id}")

            await websocket.send_json({
                "type": "connection",
                "status": "connected",
                "client_id": client_id
            })

            try:
                while True:
                    data = await websocket.receive_text()
                    logger.info(f"Received message from {client_id}: {data}")
                    response = {
                        "type": "echo",
                        "message": data,
                        "client_id": client_id
                    }
                    await websocket.send_json(response)
            except WebSocketDisconnect:
                logger.info(f"WebSocket disconnected: {client_id}")
                del active_connections[client_id]
            except Exception as e:
                logger.error(f"Error in WebSocket connection {client_id}: {str(e)}")
                await websocket.close(code=1011, reason="Internal server error")
        except Exception as e:
            logger.error(f"Failed to establish WebSocket connection: {str(e)}")
            if websocket.client_state.CONNECTED:
                await websocket.close(code=1011, reason="Connection failed")

    if __name__ == "__main__":
        uvicorn.run(app, host="0.0.0.0", port=8000)
    APPEOF

    # Create Dockerfile
    cat > Dockerfile << "DOCKEREOF"
    FROM python:3.11-slim
    WORKDIR /app
    COPY requirements.txt .
    RUN pip install --no-cache-dir -r requirements.txt
    COPY . .
    EXPOSE 8000
    CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
    DOCKEREOF

    # Create logs directory
    mkdir -p /home/ec2-user/logs
    chown -R ec2-user:ec2-user /home/ec2-user/logs
    chmod -R 755 /home/ec2-user/logs

    # Set permissions
    chown -R ec2-user:ec2-user $PROJECT_DIR
    chmod -R 755 $PROJECT_DIR

    # Build and run Docker container
    cd $PROJECT_DIR
    docker build -t websocket-app:latest .
    docker run -d \
        --name websocket-app \
        -p 8000:8000 \
        -v /home/ec2-user/logs:/home/ec2-user/logs \
        --restart unless-stopped \
        websocket-app:latest

    # Verify container is running
    docker ps
    docker logs websocket-app
    netstat -tulpn | grep -E "8000"
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
resource "aws_lb_target_group" "websocket" {
  name        = "websocket-tg-${formatdate("YYYYMMDDHHmmss", timestamp())}"
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
    port               = "8000"
    protocol           = "HTTP"
    timeout            = 10
    unhealthy_threshold = 3
  }

  # Enable stickiness for WebSocket connections
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  # Enable WebSocket support
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "websocket-tg"
    Environment = var.environment
  }
}

# WebSocket Listener
resource "aws_lb_listener" "websocket" {
  load_balancer_arn = aws_lb.websocket.arn
  port              = 8000
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
