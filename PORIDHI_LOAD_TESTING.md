# WebSocket Load Testing for Poridhi Lab Environment

This guide explains how to run load testing for your WebSocket application in the Poridhi lab environment using the provided load balancer URLs.

## Load Balancer URLs

- **WebSocket Server**: https://67ac2c9d1fcfb0b6f0fdcee7-lb-261.bm-southwest.lab.poridhi.io/
- **Prometheus**: https://67ac2c9d1fcfb0b6f0fdcee7-lb-736.bm-southwest.lab.poridhi.io/
- **Grafana**: https://67ac2c9d1fcfb0b6f0fdcee7-lb-158.bm-southwest.lab.poridhi.io/

## Prerequisites

1. Docker and Docker Compose installed
2. Access to the Poridhi lab environment
3. The WebSocket server should be running and accessible

## Quick Start

### Option 1: Using the provided scripts

**For Linux/Mac:**
```bash
chmod +x run-load-test-poridhi.sh
./run-load-test-poridhi.sh
```

**For Windows (PowerShell):**
```powershell
.\run-load-test-poridhi.ps1
```

### Option 2: Manual execution

1. **Start the monitoring stack:**
   ```bash
   docker-compose -f docker-compose-poridhi.yml up -d prometheus grafana
   ```

2. **Run the load test:**
   ```bash
   docker-compose -f docker-compose-poridhi.yml run --rm k6
   ```

3. **View results:**
   - Prometheus: http://localhost:9090
   - Grafana: http://localhost:3000 (admin/admin)

4. **Stop the monitoring stack:**
   ```bash
   docker-compose -f docker-compose-poridhi.yml down
   ```

## Configuration Files

### Modified Files for Poridhi Lab

1. **`k6/websocket-test-poridhi.js`** - k6 load test script
   - Uses WSS (secure WebSocket) connection
   - Points to the load balancer URL
   - Includes custom metrics for monitoring

2. **`prometheus/prometheus-poridhi.yml`** - Prometheus configuration
   - Scrapes metrics from the load balancer URL
   - Uses HTTPS with TLS verification disabled

3. **`docker-compose-poridhi.yml`** - Docker Compose configuration
   - Runs only Prometheus, Grafana, and k6
   - Uses the Poridhi-specific configurations

## Load Test Parameters

The load test is configured with the following stages:

1. **Ramp up**: 0 → 50 users over 1 minute
2. **Sustain**: 50 users for 3 minutes
3. **Ramp up**: 50 → 100 users over 1 minute
4. **Sustain**: 100 users for 3 minutes
5. **Ramp down**: 100 → 0 users over 1 minute

**Total test duration**: 9 minutes

## Performance Thresholds

- **Connection success rate**: > 95%
- **Message success rate**: > 95%
- **Message latency (95th percentile)**: < 500ms

## Monitoring

### Prometheus Metrics

The following custom metrics are collected:

- `ws_connection_success_rate` - Rate of successful WebSocket connections
- `ws_message_success_rate` - Rate of successful message exchanges
- `ws_message_latency` - Message round-trip latency
- `ws_connection_errors` - Count of connection errors
- `ws_message_errors` - Count of message errors

### Grafana Dashboards

Access Grafana at http://localhost:3000 with credentials:
- Username: `admin`
- Password: `admin`

The dashboards will show:
- WebSocket connection metrics
- Message throughput
- Latency distributions
- Error rates

## Troubleshooting

### Common Issues

1. **Connection refused errors**
   - Verify the WebSocket server is running
   - Check if the load balancer URL is accessible

2. **TLS/SSL errors**
   - The configuration uses `insecure_skip_verify: true` for testing
   - In production, use proper SSL certificates

3. **Prometheus scraping issues**
   - Check if the `/metrics` endpoint is accessible
   - Verify network connectivity to the load balancer

### Debug Commands

```bash
# Test WebSocket connection
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" https://67ac2c9d1fcfb0b6f0fdcee7-lb-261.bm-southwest.lab.poridhi.io/ws

# Check Prometheus metrics endpoint
curl https://67ac2c9d1fcfb0b6f0fdcee7-lb-261.bm-southwest.lab.poridhi.io/metrics

# View k6 logs
docker-compose -f docker-compose-poridhi.yml logs k6
```

## Customization

### Modifying Load Test Parameters

Edit `k6/websocket-test-poridhi.js` to change:

- **User count**: Modify the `target` values in the `stages` array
- **Test duration**: Adjust the `duration` values
- **Message frequency**: Change the interval in `socket.setInterval()`
- **Connection duration**: Modify the timeout in `socket.setTimeout()`

### Adding Custom Metrics

```javascript
// Add new custom metrics
const customMetric = new Counter('custom_metric_name');

// Use in your test
customMetric.add(1);
```

## Security Notes

- The current configuration disables TLS verification for testing purposes
- In production environments, use proper SSL certificates
- Consider implementing authentication for the WebSocket connections
- Monitor for potential DoS attacks during load testing

## Support

For issues related to:
- **Poridhi Lab Environment**: Contact your lab administrator
- **Load Testing Configuration**: Check the troubleshooting section above
- **WebSocket Application**: Review the main application documentation 