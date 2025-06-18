#!/bin/bash

echo "Starting WebSocket Load Testing for Poridhi Lab Environment"
echo "=========================================================="
echo ""
echo "Load Balancer URLs:"
echo "- WebSocket Server: https://67ac2c9d1fcfb0b6f0fdcee7-lb-261.bm-southwest.lab.poridhi.io/"
echo "- Prometheus: https://67ac2c9d1fcfb0b6f0fdcee7-lb-736.bm-southwest.lab.poridhi.io/"
echo "- Grafana: https://67ac2c9d1fcfb0b6f0fdcee7-lb-158.bm-southwest.lab.poridhi.io/"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker first."
    exit 1
fi

# Start the monitoring stack
echo "Starting Prometheus and Grafana..."
docker-compose -f docker-compose-poridhi.yml up -d prometheus grafana

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 10

# Run k6 load test
echo "Starting k6 load test..."
docker-compose -f docker-compose-poridhi.yml run --rm k6

echo ""
echo "Load test completed!"
echo "You can view results at:"
echo "- Prometheus: http://localhost:9090"
echo "- Grafana: http://localhost:3000 (admin/admin)"
echo ""
echo "To stop the monitoring stack, run:"
echo "docker-compose -f docker-compose-poridhi.yml down" 