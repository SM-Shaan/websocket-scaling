provider "aws" {
  region = var.region
}

# VPC and Network Configuration
resource "aws_vpc" "demo" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "demo-websocket-vpc"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "demo" {
  vpc_id = aws_vpc.demo.id

  tags = {
    Name        = "demo-websocket-igw"
    Environment = var.environment
  }
}

# Public Subnets
resource "aws_subnet" "demo_public" {
  count             = 2
  vpc_id            = aws_vpc.demo.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name        = "demo-websocket-public-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# Route Table
resource "aws_route_table" "demo_public" {
  vpc_id = aws_vpc.demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo.id
  }

  tags = {
    Name        = "demo-websocket-public-rt"
    Environment = var.environment
  }
}

# Route Table Association
resource "aws_route_table_association" "demo_public" {
  count          = 2
  subnet_id      = aws_subnet.demo_public[count.index].id
  route_table_id = aws_route_table.demo_public.id
}

# Security Group for Nginx
resource "aws_security_group" "nginx" {
  name        = "demo-nginx-sg"
  description = "Security group for Nginx load balancer"
  vpc_id      = aws_vpc.demo.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP traffic"
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
    Name        = "demo-nginx-sg"
    Environment = var.environment
  }
}

# Security Group for WebSocket Applications
resource "aws_security_group" "websocket_apps" {
  name        = "demo-websocket-apps-sg"
  description = "Security group for WebSocket applications"
  vpc_id      = aws_vpc.demo.id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx.id]
    description     = "Flask app traffic from Nginx"
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
    Name        = "demo-websocket-apps-sg"
    Environment = var.environment
  }
}

# Security Group for Redis
resource "aws_security_group" "redis" {
  name        = "demo-redis-sg"
  description = "Security group for Redis"
  vpc_id      = aws_vpc.demo.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.websocket_apps.id]
    description     = "Redis access from WebSocket apps"
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
    Name        = "demo-redis-sg"
    Environment = var.environment
  }
}

# Create key pair
resource "aws_key_pair" "demo_websocket" {
  key_name   = "demo-websocket-key-${formatdate("YYYYMMDDHHmmss", timestamp())}"
  public_key = file("${path.module}/websocket-key.pub")
}

# EC2 Instance - Redis (deploy first)
resource "aws_instance" "redis" {
  ami           = "ami-04173560437081c75"  # Amazon Linux 2023 AMI for ap-southeast-1
  instance_type = "t2.micro"
  key_name      = aws_key_pair.demo_websocket.key_name
  subnet_id     = aws_subnet.demo_public[1].id
  vpc_security_group_ids = [aws_security_group.redis.id]

  user_data = base64encode(
    <<-EOF
    #!/bin/bash
    set -e
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

    echo "Starting Redis user data script..."

    # Update system and install required packages
    echo "Updating system and installing packages..."
    yum update -y
    yum install -y docker git

    # Start and enable Docker
    echo "Starting Docker service..."
    systemctl daemon-reload
    systemctl enable docker
    systemctl start docker

    # Add ec2-user to docker group
    echo "Adding ec2-user to docker group..."
    usermod -aG docker ec2-user

    # Create project directory
    echo "Creating project directory..."
    PROJECT_DIR="/home/ec2-user/redis"
    mkdir -p $PROJECT_DIR
    cd $PROJECT_DIR

    # Create docker-compose.yml
    echo "Creating docker-compose.yml..."
    cat > docker-compose.yml << "COMPOSEEOF"
version: '3'

services:
  redis:
    image: redis:latest
    ports:
      - "6379:6379"
    restart: unless-stopped
COMPOSEEOF

    # Set permissions
    echo "Setting permissions..."
    chown -R ec2-user:ec2-user $PROJECT_DIR
    chmod -R 755 $PROJECT_DIR

    # Start Redis container
    echo "Starting Redis container..."
    cd $PROJECT_DIR
    docker-compose up -d

    # Verify container is running
    echo "Verifying container status..."
    docker ps
    echo "Container logs:"
    docker logs redis_redis_1

    echo "Redis user data script completed."
  EOF
  )

  tags = {
    Name        = "demo-redis-instance"
    Environment = var.environment
  }
}

# EC2 Instance - WebSocket App 1
resource "aws_instance" "websocket_app1" {
  ami           = "ami-04173560437081c75"  # Amazon Linux 2023 AMI for ap-southeast-1
  instance_type = "t2.micro"
  key_name      = aws_key_pair.demo_websocket.key_name
  subnet_id     = aws_subnet.demo_public[0].id
  vpc_security_group_ids = [aws_security_group.websocket_apps.id]

  depends_on = [aws_instance.redis]

  user_data = base64encode(
    <<-EOF
    #!/bin/bash
    set -e
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

    echo "Starting WebSocket app 1 user data script..."

    # Update system and install required packages
    echo "Updating system and installing packages..."
    yum update -y
    yum install -y docker git python3-pip

    # Start and enable Docker
    echo "Starting Docker service..."
    systemctl daemon-reload
    systemctl enable docker
    systemctl start docker

    # Add ec2-user to docker group
    echo "Adding ec2-user to docker group..."
    usermod -aG docker ec2-user

    # Create project directory
    echo "Creating project directory..."
    PROJECT_DIR="/home/ec2-user/app"
    mkdir -p $PROJECT_DIR
    cd $PROJECT_DIR

    # Create requirements.txt
    echo "Creating requirements.txt..."
    cat > requirements.txt << "REQEOF"
flask==2.0.1
flask-session==0.4.0
redis==4.0.2
werkzeug==2.0.3
REQEOF

    # Create app.py
    echo "Creating app.py..."
    cat > app.py << "APPEOF"
from flask import Flask, session, jsonify
from flask_session import Session
import redis
import os
import socket

app = Flask(__name__)

# Configure Redis for session storage
app.config['SESSION_TYPE'] = 'redis'
app.config['SESSION_REDIS'] = redis.Redis(
    host='${aws_instance.redis.private_ip}',
    port=6379,
    db=0
)
Session(app)

@app.route('/')
def index():
    if 'visits' not in session:
        session['visits'] = 0
    session['visits'] += 1
    
    return jsonify({
        'message': f'Hello from {socket.gethostname()}!',
        'visits': session['visits'],
        'session_id': session.sid
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
APPEOF

    # Create Dockerfile
    echo "Creating Dockerfile..."
    cat > Dockerfile << "DOCKEREOF"
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["python", "app.py"]
DOCKEREOF

    # Set permissions
    echo "Setting permissions..."
    chown -R ec2-user:ec2-user $PROJECT_DIR
    chmod -R 755 $PROJECT_DIR

    # Build and run Docker container
    echo "Building Docker container..."
    cd $PROJECT_DIR
    docker build -t websocket-app:latest .

    echo "Starting Docker container..."
    docker run -d \
        --name websocket-app \
        -p 5000:5000 \
        --restart unless-stopped \
        websocket-app:latest

    # Verify container is running
    echo "Verifying container status..."
    docker ps
    echo "Container logs:"
    docker logs websocket-app

    echo "WebSocket app 1 user data script completed."
  EOF
  )

  tags = {
    Name        = "demo-websocket-app1-instance"
    Environment = var.environment
  }
}

# EC2 Instance - WebSocket App 2
resource "aws_instance" "websocket_app2" {
  ami           = "ami-04173560437081c75"  # Amazon Linux 2023 AMI for ap-southeast-1
  instance_type = "t2.micro"
  key_name      = aws_key_pair.demo_websocket.key_name
  subnet_id     = aws_subnet.demo_public[0].id
  vpc_security_group_ids = [aws_security_group.websocket_apps.id]

  depends_on = [aws_instance.redis]

  user_data = base64encode(
    <<-EOF
    #!/bin/bash
    set -e
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

    echo "Starting WebSocket app 2 user data script..."

    # Update system and install required packages
    echo "Updating system and installing packages..."
    yum update -y
    yum install -y docker git python3-pip

    # Start and enable Docker
    echo "Starting Docker service..."
    systemctl daemon-reload
    systemctl enable docker
    systemctl start docker

    # Add ec2-user to docker group
    echo "Adding ec2-user to docker group..."
    usermod -aG docker ec2-user

    # Create project directory
    echo "Creating project directory..."
    PROJECT_DIR="/home/ec2-user/app"
    mkdir -p $PROJECT_DIR
    cd $PROJECT_DIR

    # Create requirements.txt
    echo "Creating requirements.txt..."
    cat > requirements.txt << "REQEOF"
flask==2.0.1
flask-session==0.4.0
redis==4.0.2
werkzeug==2.0.3
REQEOF

    # Create app.py
    echo "Creating app.py..."
    cat > app.py << "APPEOF"
from flask import Flask, session, jsonify
from flask_session import Session
import redis
import os
import socket

app = Flask(__name__)

# Configure Redis for session storage
app.config['SESSION_TYPE'] = 'redis'
app.config['SESSION_REDIS'] = redis.Redis(
    host='${aws_instance.redis.private_ip}',
    port=6379,
    db=0
)
Session(app)

@app.route('/')
def index():
    if 'visits' not in session:
        session['visits'] = 0
    session['visits'] += 1
    
    return jsonify({
        'message': f'Hello from {socket.gethostname()}!',
        'visits': session['visits'],
        'session_id': session.sid
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
APPEOF

    # Create Dockerfile
    echo "Creating Dockerfile..."
    cat > Dockerfile << "DOCKEREOF"
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["python", "app.py"]
DOCKEREOF

    # Set permissions
    echo "Setting permissions..."
    chown -R ec2-user:ec2-user $PROJECT_DIR
    chmod -R 755 $PROJECT_DIR

    # Build and run Docker container
    echo "Building Docker container..."
    cd $PROJECT_DIR
    docker build -t websocket-app:latest .

    echo "Starting Docker container..."
    docker run -d \
        --name websocket-app \
        -p 5000:5000 \
        --restart unless-stopped \
        websocket-app:latest

    # Verify container is running
    echo "Verifying container status..."
    docker ps
    echo "Container logs:"
    docker logs websocket-app

    echo "WebSocket app 2 user data script completed."
  EOF
  )

  tags = {
    Name        = "demo-websocket-app2-instance"
    Environment = var.environment
  }
}

# EC2 Instance - Nginx (deploy last)
resource "aws_instance" "nginx" {
  ami           = "ami-04173560437081c75"  # Amazon Linux 2023 AMI for ap-southeast-1
  instance_type = "t2.micro"
  key_name      = aws_key_pair.demo_websocket.key_name
  subnet_id     = aws_subnet.demo_public[0].id
  vpc_security_group_ids = [aws_security_group.nginx.id]

  depends_on = [aws_instance.websocket_app1, aws_instance.websocket_app2]

  user_data = base64encode(
    <<-EOF
    #!/bin/bash
    set -e
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

    echo "Starting Nginx user data script..."

    # Update system and install required packages
    echo "Updating system and installing packages..."
    yum update -y
    yum install -y docker git

    # Start and enable Docker
    echo "Starting Docker service..."
    systemctl daemon-reload
    systemctl enable docker
    systemctl start docker

    # Add ec2-user to docker group
    echo "Adding ec2-user to docker group..."
    usermod -aG docker ec2-user

    # Create project directory
    echo "Creating project directory..."
    PROJECT_DIR="/home/ec2-user/nginx"
    mkdir -p $PROJECT_DIR
    cd $PROJECT_DIR

    # Create nginx.conf
    echo "Creating nginx.conf..."
    cat > nginx.conf << "NGINXEOF"
events {
    worker_connections 1024;
}

http {
    upstream backend {
        ip_hash;  # This enables sticky sessions based on client IP
        server ${aws_instance.websocket_app1.private_ip}:5000;
        server ${aws_instance.websocket_app2.private_ip}:5000;
    }

    server {
        listen 80;
        server_name localhost;

        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # WebSocket support
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }
}
NGINXEOF

    # Create docker-compose.yml
    echo "Creating docker-compose.yml..."
    cat > docker-compose.yml << "COMPOSEEOF"
version: '3'

services:
  nginx:
    image: nginx:latest
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    restart: unless-stopped
COMPOSEEOF

    # Set permissions
    echo "Setting permissions..."
    chown -R ec2-user:ec2-user $PROJECT_DIR
    chmod -R 755 $PROJECT_DIR

    # Start Nginx container
    echo "Starting Nginx container..."
    cd $PROJECT_DIR
    docker-compose up -d

    # Verify container is running
    echo "Verifying container status..."
    docker ps
    echo "Container logs:"
    docker logs nginx_nginx_1

    echo "Nginx user data script completed."
  EOF
  )

  tags = {
    Name        = "demo-nginx-instance"
    Environment = var.environment
  }
}

# Outputs
output "nginx_public_ip" {
  description = "Public IP of the Nginx instance"
  value       = aws_instance.nginx.public_ip
}

output "websocket_app1_public_ip" {
  description = "Public IP of the first WebSocket app instance"
  value       = aws_instance.websocket_app1.public_ip
}

output "websocket_app2_public_ip" {
  description = "Public IP of the second WebSocket app instance"
  value       = aws_instance.websocket_app2.public_ip
}

output "redis_public_ip" {
  description = "Public IP of the Redis instance"
  value       = aws_instance.redis.public_ip
}

output "nginx_url" {
  description = "URL to access the application through Nginx"
  value       = "http://${aws_instance.nginx.public_ip}"
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
} 