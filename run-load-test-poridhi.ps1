# PowerShell script for WebSocket Load Testing in Poridhi Lab Environment

Write-Host "Starting WebSocket Load Testing for Poridhi Lab Environment" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Load Balancer URLs:" -ForegroundColor Yellow
Write-Host "- WebSocket Server: https://67ac2c9d1fcfb0b6f0fdcee7-lb-261.bm-southwest.lab.poridhi.io/" -ForegroundColor Cyan
Write-Host "- Prometheus: https://67ac2c9d1fcfb0b6f0fdcee7-lb-736.bm-southwest.lab.poridhi.io/" -ForegroundColor Cyan
Write-Host "- Grafana: https://67ac2c9d1fcfb0b6f0fdcee7-lb-158.bm-southwest.lab.poridhi.io/" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is running
try {
    docker info | Out-Null
} catch {
    Write-Host "Error: Docker is not running. Please start Docker first." -ForegroundColor Red
    exit 1
}

# Start the monitoring stack
Write-Host "Starting Prometheus and Grafana..." -ForegroundColor Yellow
docker-compose -f docker-compose-poridhi.yml up -d prometheus grafana

# Wait for services to be ready
Write-Host "Waiting for services to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Run k6 load test
Write-Host "Starting k6 load test..." -ForegroundColor Yellow
docker-compose -f docker-compose-poridhi.yml run --rm k6

Write-Host ""
Write-Host "Load test completed!" -ForegroundColor Green
Write-Host "You can view results at:" -ForegroundColor Yellow
Write-Host "- Prometheus: http://localhost:9090" -ForegroundColor Cyan
Write-Host "- Grafana: http://localhost:3000 (admin/admin)" -ForegroundColor Cyan
Write-Host ""
Write-Host "To stop the monitoring stack, run:" -ForegroundColor Yellow
Write-Host "docker-compose -f docker-compose-poridhi.yml down" -ForegroundColor Cyan 