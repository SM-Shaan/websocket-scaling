# Demo Setup Deployment Script (PowerShell)
# This script deploys the distributed demo setup with nginx, two websocket apps, and redis

param(
    [switch]$Force
)

Write-Host "🚀 Starting Demo Setup Deployment..." -ForegroundColor Green

# Check if required files exist
if (-not (Test-Path "websocket-key.pub")) {
    Write-Host "❌ Error: websocket-key.pub not found in current directory" -ForegroundColor Red
    Write-Host "Please ensure you have the SSH key pair files:" -ForegroundColor Yellow
    Write-Host "  - websocket-key (private key)" -ForegroundColor Yellow
    Write-Host "  - websocket-key.pub (public key)" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path "websocket-key")) {
    Write-Host "❌ Error: websocket-key not found in current directory" -ForegroundColor Red
    Write-Host "Please ensure you have the SSH key pair files:" -ForegroundColor Yellow
    Write-Host "  - websocket-key (private key)" -ForegroundColor Yellow
    Write-Host "  - websocket-key.pub (public key)" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ SSH key files found" -ForegroundColor Green

# Initialize Terraform
Write-Host "📦 Initializing Terraform..." -ForegroundColor Blue
terraform init

# Plan the deployment
Write-Host "📋 Planning deployment..." -ForegroundColor Blue
terraform plan -var-file="demo-terraform.tfvars" -out=demo-plan.tfplan

# Ask for confirmation
Write-Host ""
Write-Host "⚠️  This will create 4 EC2 instances:" -ForegroundColor Yellow
Write-Host "   - 1 Nginx instance (load balancer)" -ForegroundColor Yellow
Write-Host "   - 2 WebSocket application instances" -ForegroundColor Yellow
Write-Host "   - 1 Redis instance (session storage)" -ForegroundColor Yellow
Write-Host ""

if (-not $Force) {
    $confirmation = Read-Host "Do you want to proceed with the deployment? (y/N)"
    if ($confirmation -ne "y" -and $confirmation -ne "Y") {
        Write-Host "❌ Deployment cancelled" -ForegroundColor Red
        exit 1
    }
}

# Apply the deployment
Write-Host "🚀 Deploying infrastructure..." -ForegroundColor Green
terraform apply demo-plan.tfplan

# Get outputs
Write-Host ""
Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Infrastructure Details:" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
terraform output

Write-Host ""
Write-Host "🧪 Testing the deployment..." -ForegroundColor Blue
Write-Host "==========================" -ForegroundColor Blue

# Get Nginx IP
$nginxIP = terraform output -raw nginx_public_ip

if ($nginxIP) {
    Write-Host "Testing Nginx endpoint: http://$nginxIP" -ForegroundColor Blue
    
    # Wait a bit for services to start
    Write-Host "Waiting for services to start..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    
    # Test the endpoint
    try {
        $response = Invoke-WebRequest -Uri "http://$nginxIP" -TimeoutSec 10 -ErrorAction Stop
        Write-Host "✅ Application is responding!" -ForegroundColor Green
        Write-Host ""
        Write-Host "🎉 Deployment successful! You can now access your application at:" -ForegroundColor Green
        Write-Host "   http://$nginxIP" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "📝 To test session persistence:" -ForegroundColor Yellow
        Write-Host "   curl http://$nginxIP" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "🔧 To SSH into instances (using Git Bash or WSL):" -ForegroundColor Yellow
        Write-Host "   ssh -i websocket-key ec2-user@$nginxIP" -ForegroundColor Cyan
    }
    catch {
        Write-Host "⚠️  Application not responding yet. Please wait a few minutes and try again." -ForegroundColor Yellow
        Write-Host "   You can check the status by SSH'ing into the instances." -ForegroundColor Yellow
    }
}
else {
    Write-Host "❌ Could not retrieve Nginx IP address" -ForegroundColor Red
}

Write-Host ""
Write-Host "📚 For more information, see DEMO_DEPLOYMENT.md" -ForegroundColor Blue
Write-Host ""
Write-Host "🗑️  To destroy the infrastructure when done:" -ForegroundColor Yellow
Write-Host "   terraform destroy -var-file=`"demo-terraform.tfvars`"" -ForegroundColor Cyan 