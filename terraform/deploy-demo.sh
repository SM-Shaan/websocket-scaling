#!/bin/bash

# Demo Setup Deployment Script
# This script deploys the distributed demo setup with nginx, two websocket apps, and redis

set -e

echo "🚀 Starting Demo Setup Deployment..."

# Check if required files exist
if [ ! -f "websocket-key.pub" ]; then
    echo "❌ Error: websocket-key.pub not found in current directory"
    echo "Please ensure you have the SSH key pair files:"
    echo "  - websocket-key (private key)"
    echo "  - websocket-key.pub (public key)"
    exit 1
fi

if [ ! -f "websocket-key" ]; then
    echo "❌ Error: websocket-key not found in current directory"
    echo "Please ensure you have the SSH key pair files:"
    echo "  - websocket-key (private key)"
    echo "  - websocket-key.pub (public key)"
    exit 1
fi

# Set proper permissions for SSH key
chmod 600 websocket-key
chmod 644 websocket-key.pub

echo "✅ SSH key files found and permissions set"

# Initialize Terraform
echo "📦 Initializing Terraform..."
terraform init

# Plan the deployment
echo "📋 Planning deployment..."
terraform plan -var-file="demo-terraform.tfvars" -out=demo-plan.tfplan

# Ask for confirmation
echo ""
echo "⚠️  This will create 4 EC2 instances:"
echo "   - 1 Nginx instance (load balancer)"
echo "   - 2 WebSocket application instances"
echo "   - 1 Redis instance (session storage)"
echo ""
read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    exit 1
fi

# Apply the deployment
echo "🚀 Deploying infrastructure..."
terraform apply demo-plan.tfplan

# Get outputs
echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "📊 Infrastructure Details:"
echo "=========================="
terraform output

echo ""
echo "🧪 Testing the deployment..."
echo "=========================="

# Get Nginx IP
NGINX_IP=$(terraform output -raw nginx_public_ip)

if [ -n "$NGINX_IP" ]; then
    echo "Testing Nginx endpoint: http://$NGINX_IP"
    
    # Wait a bit for services to start
    echo "Waiting for services to start..."
    sleep 30
    
    # Test the endpoint
    if curl -s -f "http://$NGINX_IP" > /dev/null; then
        echo "✅ Application is responding!"
        echo ""
        echo "🎉 Deployment successful! You can now access your application at:"
        echo "   http://$NGINX_IP"
        echo ""
        echo "📝 To test session persistence:"
        echo "   curl http://$NGINX_IP"
        echo ""
        echo "🔧 To SSH into instances:"
        echo "   ssh -i websocket-key ec2-user@$NGINX_IP"
    else
        echo "⚠️  Application not responding yet. Please wait a few minutes and try again."
        echo "   You can check the status by SSH'ing into the instances."
    fi
else
    echo "❌ Could not retrieve Nginx IP address"
fi

echo ""
echo "📚 For more information, see DEMO_DEPLOYMENT.md"
echo ""
echo "🗑️  To destroy the infrastructure when done:"
echo "   terraform destroy -var-file=\"demo-terraform.tfvars\"" 