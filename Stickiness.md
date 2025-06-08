# WebSocket Session Stickiness: Importance and Demonstration

## What is Session Stickiness?

Session stickiness (also known as session affinity) is a load balancing feature that ensures all requests from a specific client are routed to the same server instance. In the context of WebSocket connections, this is crucial because:

1. WebSocket connections are stateful and maintain a persistent connection
2. Each server instance maintains its own set of active WebSocket connections
3. Without stickiness, a client might be routed to different servers, causing connection issues

## Why is Stickiness Important?

Without session stickiness:
- WebSocket connections might be routed to different servers
- Messages sent by a client might not reach the intended server
- **Reliability**: Prevents connection drops and message loss that could occur when switching between instances.
- **State Management**: If your application maintains state on the server side (like user sessions, game states, or chat rooms), stickiness ensures this state remains consistent.
- **Performance**: Reduces overhead by avoiding the need to replicate state across multiple instances.

## Without stickiness, you might encounter these issues:

1. **Connection Drops**: Clients might be disconnected when the load balancer routes them to a different instance.
2. **Message Loss**: Messages might be lost if sent to an instance that doesn't have the client's connection.
3. **State Inconsistency**: Server-side state might become inconsistent across instances.
4. **Poor User Experience**: Users might experience disconnections or missing messages.

## How to Demonstrate the Importance of Stickiness

### Step 1: Deploy Without Stickiness
1. Modify the target group configuration in `terraform/main.tf`:
   ```hcl
   resource "aws_lb_target_group" "websocket" {
     # ... other configurations ...
     
     # Disable stickiness
     stickiness {
       type            = "lb_cookie"
       cookie_duration = 86400
       enabled         = false  # Set to false
     }
   }
   ```

2. Apply the Terraform changes:
   ```bash
   terraform apply
   ```

### Step 2: Test Without Stickiness
1. Open the test client in multiple browser windows
2. Connect to the WebSocket server
3. Send messages between clients
4. Observe the following issues:
   - Connections might be established on different servers
   - Messages might not be received by all clients
   - Connection state might be inconsistent

Expected Result: You'll see different hostnames, indicating connections to different instances


### Step 3: Enable Stickiness
1. Modify the target group configuration:
   ```hcl
   resource "aws_lb_target_group" "websocket" {
     # ... other configurations ...
     
     # Enable stickiness
     stickiness {
       type            = "lb_cookie"
       cookie_duration = 86400
       enabled         = true  # Set to true
     }
   }
   ```

2. Apply the Terraform changes:
   ```bash
   terraform apply
   ```

### Step 4: Test With Stickiness
1. Open the test client in multiple browser windows
2. Connect to the WebSocket server
3. Send messages between clients
4. Observe the improvements:
   - Connections are consistently routed to the same server
   - Messages are properly delivered to all clients
   - Connection state remains consistent

Expected Result: Each window will maintain connection to the same instance

## How to Verify Stickiness

1. Check the server logs to see which server handles each connection
2. Use the health check endpoint to see active connections on each server
3. Monitor the ALB metrics to verify connection distribution

## Common Issues Without Stickiness

1. **Connection Drops**: Clients might experience frequent disconnections
2. **Message Loss**: Messages might not reach all intended recipients
3. **State Inconsistency**: Different servers might have different views of the connection state
4. **Poor User Experience**: Real-time updates might be delayed or missed

## Best Practices

1. Always enable stickiness for WebSocket applications
2. Set an appropriate cookie duration (e.g., 24 hours)
3. Monitor connection distribution across servers
4. Implement proper error handling for connection issues
5. Use health checks to ensure server availability

## Monitoring WebSocket Communication Flow

### 1. Server-Side Logging
Add detailed logging to your FastAPI application to track communication flow:

```python
import logging
import json
import socket

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('websocket.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("websocket")

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    client_id = str(id(websocket))
    hostname = socket.gethostname()
    
    try:
        await websocket.accept()
        logger.info(f"New connection - Client: {client_id}, Server: {hostname}")
        
        while True:
            data = await websocket.receive_text()
            logger.info(f"Received from {client_id} on {hostname}: {data}")
            
            response = {
                "type": "echo",
                "message": data,
                "client_id": client_id,
                "hostname": hostname
            }
            await websocket.send_json(response)
            logger.info(f"Sent to {client_id} on {hostname}: {json.dumps(response)}")
            
    except WebSocketDisconnect:
        logger.info(f"Disconnected - Client: {client_id}, Server: {hostname}")
    except Exception as e:
        logger.error(f"Error for {client_id} on {hostname}: {str(e)}")
```

### 2. Client-Side Monitoring
Enhance the test client to show detailed connection information:

```javascript
ws.onopen = function() {
    const connectionInfo = {
        timestamp: new Date().toISOString(),
        event: 'connection_established',
        url: ws.url
    };
    console.log('Connection Info:', connectionInfo);
    addMessage(`Connected to: ${ws.url}`, 'status');
};

ws.onmessage = function(event) {
    const messageInfo = {
        timestamp: new Date().toISOString(),
        event: 'message_received',
        data: event.data
    };
    console.log('Message Info:', messageInfo);
    addMessage(`Received: ${event.data}`, 'received');
};
```

### 3. Network Monitoring Tools

#### Using Browser Developer Tools
1. Open Chrome DevTools (F12)
2. Go to Network tab
3. Filter by "WS" to see WebSocket connections
4. Click on a WebSocket connection to see:
   - Headers
   - Frames (messages)
   - Timing information

#### Using AWS CloudWatch
1. Enable detailed monitoring for your ALB
2. Monitor these metrics:
   - `RequestCount`
   - `HealthyHostCount`
   - `UnHealthyHostCount`
   - `TargetResponseTime`

### 4. Health Check Endpoint
Add a health check endpoint to monitor server status:

```python
@app.get("/health")
async def health_check():
    hostname = socket.gethostname()
    return {
        "status": "healthy",
        "hostname": hostname,
        "connections": len(active_connections),
        "active_clients": list(active_connections.keys())
    }
```

### 5. Monitoring Commands

#### Check Server Logs
```bash
# View real-time logs
tail -f websocket.log

# Search for specific client
grep "client_id" websocket.log

# Count connections per server
grep "New connection" websocket.log | awk '{print $NF}' | sort | uniq -c
```

#### Check Network Connections
```bash
# List all WebSocket connections
netstat -an | grep :8000

# Monitor connections in real-time
watch -n 1 'netstat -an | grep :8000'
```

#### Check Server Health
```bash
# Test health endpoint
curl http://your-server:8000/health

# Monitor multiple servers
for server in server1 server2; do
    echo "=== $server ==="
    curl -s http://$server:8000/health
    echo
done
```

### 6. Visualizing Communication Flow

1. **Server-side Visualization**:
   - Log connection events to a structured format (JSON)
   - Use tools like ELK Stack or Grafana to visualize
   - Create dashboards showing:
     - Active connections per server
     - Message flow patterns
     - Connection durations
     - Error rates

2. **Client-side Visualization**:
   - Add timestamps to all messages
   - Show connection status changes
   - Display message flow direction
   - Highlight errors and reconnection attempts

### 7. Step-by-Step Testing Instructions

1. **Prepare Test Environment**:
   ```bash
   # SSH into Instance 1
   ssh -i your-key.pem ec2-user@52.221.232.163
   
   # Check server logs
   docker logs websocket-app
   ```

2. **Test Direct Connection**:
   ```bash
   # Install websocat
   sudo yum install -y epel-release
   sudo yum install -y websocat
   
   # Connect to Instance 1
   websocat ws://52.221.232.163:8000/ws
   ```

3. **Test Through ALB**:
   ```bash
   # Connect to ALB
   websocat ws://websocket-alb-20250606023454-943737327.ap-southeast-1.elb.amazonaws.com:8000/ws
   ```

4. **Monitor Connections**:
   ```bash
   # Check health endpoint
   curl http://websocket-alb-20250606023454-943737327.ap-southeast-1.elb.amazonaws.com:8000/health
   ```


By implementing these monitoring techniques, you can:
- Track message flow between clients and servers
- Identify connection issues
- Monitor server performance
- Debug communication problems
- Ensure proper load balancing
- Verify session stickiness

## Conclusion

Session stickiness is crucial for WebSocket applications to maintain consistent and reliable connections. Without it, the real-time nature of WebSocket communication can be compromised, leading to poor user experience and potential data loss. Always ensure stickiness is properly configured in your load balancer settings for WebSocket applications.

---------------------------------------------

## Adding Images for Better Visualization

2. Take screenshots of:
   - ALB configuration showing stickiness settings
   - Test client showing different hostnames without stickiness
   - Test client showing same hostname with stickiness
   - Server logs showing connection distribution

3. Add images to the documentation:
   ```markdown
   ![ALB Stickiness Configuration](docs/images/alb-stickiness.png)
   ![Test Without Stickiness](docs/images/test-without-stickiness.png)
   ![Test With Stickiness](docs/images/test-with-stickiness.png)
   ```


