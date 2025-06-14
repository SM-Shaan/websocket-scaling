# 🔗 WebSocket Connections and Session Stickiness

## 📋 Table of Contents
1. [What is WebSocket?](#what-is-websocket)
2. [WebSocket vs HTTP](#websocket-vs-http)
3. [Session Stickiness](#session-stickiness)
4. [Challenges Without Stickiness](#challenges-without-stickiness)
5. [Message Flow](#message-flow)
6. [Implementation](#implementation)
7. [Testing](#testing)
8. [Monitoring](#monitoring)
9. [Conclusion](#conclusion)

## 💡 What is WebSocket?

WebSocket is a communication protocol that provides a full-duplex, persistent connection between a client and a server. Unlike traditional HTTP requests, WebSocket connections:

## Session Stickiness in WebSocket

Session stickiness, also known as session affinity, is a load balancing feature that ensures all requests from a specific client are routed to the same server instance. This is particularly important in WebSocket connections due to their stateful and persistent nature. Here’s why stickiness is essential:

### Why Stickiness is Introduced in WebSocket Connections

1. **Connection State**: WebSocket connections maintain a persistent state on the server. Stickiness ensures that the client remains connected to the same server, preserving this state throughout the session.

2. **Message Order and Delivery**: In real-time applications, message order is critical. Stickiness guarantees that messages are routed to the correct server, ensuring proper sequencing and delivery.

3. **Session Data Consistency**: Many WebSocket applications rely on server-side session data, such as user authentication, chat history, or game states. Stickiness prevents inconsistencies by keeping the client connected to the same server.

4. **Resource Optimization**: By maintaining a consistent connection, stickiness reduces the overhead of re-establishing connections or synchronizing state across multiple servers.

5. **Improved User Experience**: Stickiness minimizes connection drops, message loss, and latency, providing a seamless and reliable experience for end-users.

Without session stickiness, WebSocket applications may face challenges such as connection interruptions, inconsistent state management, and degraded performance, making it a critical feature for ensuring reliability and efficiency in real-time communication systems.


### With Stickiness

![With Stickiness](/DOC/diagrams/stickiness.drawio.svg)

### Without Stickiness

![Without Stickiness](/DOC/diagrams/Notstickiness.drawio.svg)

## ⚠️ Challenges Without Stickiness

### 1. Connection Instability
- Frequent disconnections and reconnections
- Loss of connection state
- Unreliable user experience

### 2. Data Integrity Issues
- Incorrect message sequencing
- Occurrence of duplicate or missing messages
- Inconsistent data delivery

### 3. Increased Resource Consumption
- Higher server workload
- Elevated latency
- Suboptimal utilization of resources

### 4. Degraded User Experience
- Disrupted sessions
- Delayed or incomplete updates
- Subpar performance in real-time interactions

## 📊 Message Flow

## Message Flow Diagram

- Without Stickiness: Demonstrates how messages can be lost due to random routing
- With Stickiness: Shows how messages are consistently routed to the same server

### Test Scenario 1: Without Stickiness


![Dataflow Without Stickiness](/DOC/diagrams/dataflow2.drawio.svg)

1. Connect multiple clients
2. Send messages between clients
3. Observe:
   - Message delivery issues
   - Connection state loss
   - Inconsistent updates

### Test Scenario 2: With Stickiness

![Dataflow Stickiness](/DOC/diagrams/dataflow1.drawio.svg)

1. Connect multiple clients
2. Send messages between clients
3. Observe:
   - Consistent message delivery
   - Maintained connection state
   - Real-time updates


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

or, **Go to AWS console**:
1. Log in to the AWS Console and go to the EC2 service.
2. In the left sidebar, scroll down and click on Target Groups (under "Load Balancing").
3. Find your target group (it will be named something like websocket-tg).
4. Click on the target group to open its details.
5. Go to the Attributes tab.
6. Find the Stickiness section.
7. Click Edit.
8. Set Stickiness to Disabled.
9. Click Save changes.

After Disabling Stickiness:
- Wait a minute for the change to take effect.
- Rerun your test_stickiness.py script.
- If you have more than one healthy EC2 instance, you should now see different hostnames in the output, indicating that connections are being routed to different backends.


### Step 2. Apply the Terraform changes:
```bash
   cd terraform 

   # Generate key pair
   ssh-keygen -t rsa -b 2048 -f websocket-key -N '""'  #If key not present

   terraform init
   terraform apply
```

### Step 3: Test Without Stickiness
Change the url in test-client.html : 
```python
ws = new WebSocket('ws://<alb-dns-name>/ws'); # Change to your alb_dns_name
```
1. Open the test client in multiple browser windows
2. Connect to the WebSocket server
3. Send messages between clients
4. Observe the following issues:
   - Connections might be established on different servers
   - Messages might not be received by all clients
   - Connection state might be inconsistent

or **Run:**
```bash
python test_stickiness.py
```
![Health_check](/DOC/images/15.png)

*Expected Result: You'll see different hostnames, indicating connections to different instances**


### Step 4: Enable Stickiness
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
   cd terraform 
   
   # Generate key pair
   ssh-keygen -t rsa -b 2048 -f websocket-key -N '""' #If key not present

   terraform init
   terraform apply
```

### Step 5: Test With Stickiness
Change the url in test-client.html : 
```python
ws = new WebSocket('ws://<alb-dns-name>/ws'); # Change to your alb_dns_name
```

1. Open the test client in multiple browser windows

```bash
   # Windows PowerShell
   Start-Process "chrome.exe" "file:///E:/websocket/test-client.html"
   Start-Process "chrome.exe" "file:///E:/websocket/test-client.html"
```

2. Connect to the WebSocket server
3. Send messages between clients
4. Observe the improvements:
   - Connections are consistently routed to the same server
   - Messages are properly delivered to all clients
   - Connection state remains consistent

![Health_check](/DOC/images/10.png)

*Expected Result: Each window will maintain connection to the same instance*

or, **Run the test_stickiness.py**:

```bash
python test_stickiness.py
```

### Connection Test Results
1. First Connection:
   - Client ID: 140428593127568
   - Server Hostname: 45565bbfaa3e
   - Status: Successfully connected and maintained

2. Second Connection:
   - Client ID: 140428593131408
   - Server Hostname: 45565bbfaa3e
   - Status: Successfully connected and maintained

3. Third Connection:
   - Client ID: 140428593131408
   - Server Hostname: 45565bbfaa3e
   - Status: Successfully connected and maintained


### Checking Server Logs
To check connection details in the server logs:
```bash
# SSH into EC2 instance
ssh -i <websocket-private-key> ec2-user@18.141.164.235

# Check Docker container logs
docker logs websocket-app --tail 50
```

#### Server Log Analysis:
The server logs confirm proper connection handling:
```
INFO:     New WebSocket connection established: 140428593127568 on 45565bbfaa3e
INFO:     connection open
INFO:     Received message from 140428593127568: Test message 2
INFO:     WebSocket disconnected: 140428593127568
INFO:     connection closed
INFO:     ('10.0.1.223', 20920) - "WebSocket /ws" [accepted]
INFO:     New WebSocket connection established: 140428593131408 on 45565bbfaa3e
INFO:     connection open
INFO:     Received message from 140428593131408: Test message 3
INFO:     WebSocket disconnected: 140428593131408
INFO:     connection closed
```
## Architecture Diagram

### 1. With Stickiness

![Health_check](/DOC/diagrams/dia2.drawio.svg)

### 2. With Stickiness
![Health_check](/DOC/diagrams/dia1.drawio.svg)

- Without Session Stickiness: Shows random routing of connections
- With Session Stickiness: Shows cookie-based routing to maintain connection consistency


## State Management Comparison

### 1. With Stickiness
![Health_check](/DOC/diagrams/state1.drawio.svg)

### 2. With Stickiness
![Health_check](/DOC/diagrams/state2.drawio.svg)

- Without Stickiness: Shows how state can be fragmented across multiple servers
- With Stickiness: Shows how state is maintained on a single server


## Performance Impact
<!-- ### 1. With Stickiness

### 2. With Stickiness -->

- Without Stickiness: Shows the negative impacts (high latency, message loss, etc.)
- With Stickiness: Shows the positive impacts (low latency, no message loss, etc.)

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

![Health_check](/DOC/images/12.png)
![Health_check](/DOC/images/13.png)

<!-- #### Using AWS CloudWatch
1. Enable detailed monitoring for your ALB
2. Monitor these metrics:
   - `RequestCount`
   - `HealthyHostCount`
   - `UnHealthyHostCount`
   - `TargetResponseTime` -->

### 4. Health Check Endpoint
1. **Monitor ALB Health**:
```bash
   # Check target group health
   aws elbv2 describe-target-health \
     --target-group-arn arn:aws:elasticloadbalancing:ap-southeast-1:117572456155:targetgroup/websocket-tg-20250608033102/3fd710574e8e29b7 # change to yours
```
#### Breakdown of the ARN
- ***Service***: elasticloadbalancing (indicates an ALB or Network Load Balancer resource).
- ***Region***: ap-southeast-1 (Asia Pacific - Singapore region).
- ***Account ID***: 117572456155 (your AWS account ID).
- ***Resource Type***: targetgroup (specifies a target group).
- ***Resource Name***: websocket-tg-20250608033102 (the name of the target group, with a timestamp).
- ***Unique ID***: 3fd710574e8e29b7 (an internal identifier for the target group).

2. **Add a health check endpoint to monitor server status**:

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

## 📊 Monitoring

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
   ssh -i <path-to-private-key> ec2-user@13.250.101.179  # Server 1
   ssh -i <path-to-private-key> ec2-user@54.255.186.165  # Server 2
   
   # Check server logs
   docker logs websocket-app
```

2. **Test Through ALB**:
```bash
   # Connect to ALB
   websocat ws://<alb-dns-name>:8000/ws
```

4. **Monitor Connections**:
```bash
   # Check health endpoint
   curl http://<alb-dns-name>:8000/health
```


By implementing these monitoring techniques, you can:
- Track message flow between clients and servers
- Identify connection issues
- Monitor server performance
- Debug communication problems
- Ensure proper load balancing
- Verify session stickiness

### Troubleshooting

1. **Connection Issues**:
```bash
   # Check ALB DNS resolution
   nslookup <alb-dns-name>
   
   # Test WebSocket connection
   websocat ws://<alb-dns-name>:8000/ws
```

2. **Server Issues**:
```bash
   # Check server status
   curl http://13.250.101.179:8000/health
   curl http://54.255.186.165:8000/health
```

3. **Security Group Issues**:
```bash
   # Verify security group rules
   aws ec2 describe-security-groups \
     --filters Name=group-name,Values=websocket-sg-*
```

### Cleanup

1. **Close Browser Windows**:
```bash
   # Windows PowerShell
   Stop-Process -Name "chrome" -Force
```

2. **Destroy Infrastructure**:
```bash
   cd terraform
   terraform destroy
```

## 🎯 Conclusion

Session stickiness is crucial for WebSocket applications because:

1. **Reliability**: Ensures consistent message delivery and connection state
2. **Performance**: Optimizes resource usage and reduces overhead
3. **User Experience**: Provides seamless real-time communication
4. **Scalability**: Enables proper load balancing while maintaining connection integrity

### Best Practices
1. Always enable stickiness for WebSocket applications
2. Monitor connection distribution
3. Implement proper error handling
4. Use health checks for connection management
5. Consider failover scenarios

## 📚 Related Chapters

1. **WebSocket Connection and Sticky Sessions** ([Learn more](/DOC/Stickiness.md))
2. **Shared Session Management** ([Learn more](/DOC/Shared-sessions.md))
3. **Scaling WebSocket Applications** ([Learn more](/DOC/websocket-scaling.md))
4. **Terraform Deployment for WebSocket Infrastructure** ([Learn more](/DOC/Terraform-deployment.md))
