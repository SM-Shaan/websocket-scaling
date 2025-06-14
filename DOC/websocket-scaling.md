# 📈 Scaling WebSocket Applications with Session Stickiness

## 📋 Table of Contents
1. [Scaling Architecture](#scaling-architecture)
2. [Scaling Strategy](#scaling-strategy)
3. [Best Practices](#best-practices)
4. [Implementation Example](#implementation-example)
5. [Testing and Verification](#testing-and-verification)
6. [Monitoring](#monitoring)
7. [Conclusion](#conclusion)

## 🏗️ Scaling Architecture
Scaling is the process of adjusting the capacity of an application to handle varying levels of traffic and workload. There are two primary types of scaling:

1. **Vertical Scaling**: This involves increasing the resources (CPU, memory, etc.) of a single server to handle more load. While this approach is straightforward, it has limitations due to hardware constraints and can lead to a single point of failure.

2. **Horizontal Scaling**: This involves adding more servers to distribute the load across multiple instances. It is more resilient and scalable compared to vertical scaling, as it allows the application to handle higher traffic by simply adding more servers.

### Why Horizontal Scaling?

Horizontal scaling is preferred for WebSocket applications because:
- It provides better fault tolerance by distributing traffic across multiple servers.
- It allows for seamless scaling to handle spikes in traffic.
- It supports high availability and redundancy, ensuring minimal downtime.
- It enables the use of load balancers to manage traffic efficiently and implement session stickiness for consistent client-server communication.

By leveraging horizontal scaling, WebSocket applications can achieve robust performance, reliability, and scalability.

![With Stickiness](/DOC/diagrams/scaling.drawi.svg)

## 🎯 Scaling Strategy
### Horizontal Scaling with Sticky Sessions


### 1. Horizontal Scaling with Sticky Sessions

Horizontal scaling with sticky sessions ensures that a client consistently communicates with the same server during its session. This is achieved by configuring the load balancer to use session stickiness, typically through cookies or IP hashing. Sticky sessions are crucial for WebSocket applications to maintain stateful communication and reduce the overhead of state synchronization across servers.

By implementing sticky sessions, WebSocket applications can achieve:
- Consistent client-server communication.
- Reduced latency by avoiding frequent state migrations.
- Improved performance and reliability during scaling events.

Sticky sessions are particularly beneficial when combined with a robust state management strategy, such as using Redis for shared state storage.

![With Stickiness](/DOC/diagrams/dia6.drawio.svg)

<!-- ![With Stickiness](/DOC/diagrams/dia6.drawio.svg) -->


## Scaling Best Practices

### 1. Load Balancer Configuration
```hcl
resource "aws_lb_target_group" "websocket" {
  name     = "websocket-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/health"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 30
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }
}
```

### 2. Auto Scaling Configuration
```hcl
resource "aws_autoscaling_group" "websocket" {
  name                = "websocket-asg"
  desired_capacity    = 2
  max_size           = 10
  min_size           = 2
  target_group_arns  = [aws_lb_target_group.websocket.arn]
  
  launch_template {
    id      = aws_launch_template.websocket.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "websocket-server"
    propagate_at_launch = true
  }
}
```

### 3. Health Check Implementation
```python
@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "connections": len(active_connections),
        "memory_usage": psutil.Process().memory_info().rss,
        "cpu_usage": psutil.Process().cpu_percent()
    }
```

<!-- ## Scaling Considerations

### 1. Connection Distribution

### 2. State Synchronization

## Monitoring and Metrics

### 1. Key Metrics to Monitor
 -->

## Scaling Recommendations

1. **Connection Management**
   - Implement connection pooling
   - Monitor connection limits
   - Set appropriate timeouts

2. **State Management**
   - Use Redis for shared state
   - Implement state synchronization
   - Handle state migration during scaling

3. **Load Balancing**
   - Enable sticky sessions
   - Configure health checks
   - Monitor connection distribution

4. **Auto Scaling**
   - Set appropriate thresholds
   - Implement graceful shutdown
   - Handle connection draining

5. **Monitoring**
   - Track connection counts
   - Monitor resource usage
   - Set up alerts for anomalies

## 🚀 Implementation Example

```python
# WebSocket server with scaling support
import asyncio
import redis
import json
from fastapi import FastAPI, WebSocket
from typing import Dict

app = FastAPI()
redis_client = redis.Redis(host='redis', port=6379, db=0)
active_connections: Dict[str, WebSocket] = {}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    client_id = str(id(websocket))
    await websocket.accept()
    active_connections[client_id] = websocket
    
    try:
        while True:
            data = await websocket.receive_text()
            # Store state in Redis
            redis_client.set(f"state:{client_id}", data)
            # Broadcast to other clients if needed
            await broadcast_message(client_id, data)
    except Exception as e:
        print(f"Error: {e}")
    finally:
        del active_connections[client_id]
        redis_client.delete(f"state:{client_id}")

async def broadcast_message(sender_id: str, message: str):
    for client_id, connection in active_connections.items():
        if client_id != sender_id:
            try:
                await connection.send_text(message)
            except Exception as e:
                print(f"Error broadcasting to {client_id}: {e}")

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "connections": len(active_connections),
        "redis_connected": redis_client.ping()
    }
```

This implementation provides:
- Sticky session support
- State management with Redis
- Health check endpoint
- Connection tracking
- Error handling
- Broadcasting capabilities 

------------------------------------------
<!-- # Proving WebSocket Scaling with Session Stickiness -->
## 🧪 Testing and Verification
### 1. Connection Stickiness Test
```python
import asyncio
import websockets
import json
import time
from datetime import datetime

async def test_stickiness():
    uri = "ws://your-alb-dns:8000/ws"
    results = []
    
    # Test multiple connections
    for i in range(5):
        async with websockets.connect(uri) as websocket:
            # Send test message
            message = {
                "type": "test",
                "client_id": f"client_{i}",
                "timestamp": datetime.now().isoformat()
            }
            await websocket.send(json.dumps(message))
            
            # Receive response
            response = await websocket.recv()
            response_data = json.loads(response)
            
            results.append({
                "client_id": f"client_{i}",
                "server": response_data.get("hostname"),
                "timestamp": response_data.get("timestamp")
            })
            
            # Small delay between connections
            await asyncio.sleep(1)
    
    return results

# Run the test
results = asyncio.run(test_stickiness())
print(json.dumps(results, indent=2))
```

### 2. Load Testing Script

```python
import asyncio
import websockets
import json
import time
from datetime import datetime
import aiohttp
import asyncio
from typing import List, Dict

class WebSocketLoadTest:
    def __init__(self, url: str, num_clients: int):
        self.url = url
        self.num_clients = num_clients
        self.results: List[Dict] = []
        
    async def client(self, client_id: int):
        try:
            async with websockets.connect(self.url) as websocket:
                # Send initial message
                message = {
                    "type": "connect",
                    "client_id": f"client_{client_id}",
                    "timestamp": datetime.now().isoformat()
                }
                await websocket.send(json.dumps(message))
                
                # Receive response
                response = await websocket.recv()
                response_data = json.loads(response)
                
                self.results.append({
                    "client_id": f"client_{client_id}",
                    "server": response_data.get("hostname"),
                    "status": "connected",
                    "timestamp": response_data.get("timestamp")
                })
                
                # Send periodic messages
                for i in range(10):
                    message = {
                        "type": "message",
                        "client_id": f"client_{client_id}",
                        "message_id": i,
                        "timestamp": datetime.now().isoformat()
                    }
                    await websocket.send(json.dumps(message))
                    await asyncio.sleep(1)
                    
        except Exception as e:
            self.results.append({
                "client_id": f"client_{client_id}",
                "error": str(e),
                "status": "failed",
                "timestamp": datetime.now().isoformat()
            })
    
    async def run(self):
        tasks = [self.client(i) for i in range(self.num_clients)]
        await asyncio.gather(*tasks)
        return self.results

# Run load test
test = WebSocketLoadTest("ws://your-alb-dns:8000/ws", 50)
results = asyncio.run(test.run())
print(json.dumps(results, indent=2))
```

## 📊 Monitoring

### 1. Health Check Monitoring
```python
import aiohttp
import asyncio
from datetime import datetime
import json

async def monitor_health(url: str, interval: int = 30):
    while True:
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(f"{url}/health") as response:
                    data = await response.json()
                    print(json.dumps({
                        "timestamp": datetime.now().isoformat(),
                        "status": data.get("status"),
                        "connections": data.get("connections"),
                        "redis_connected": data.get("redis_connected")
                    }, indent=2))
        except Exception as e:
            print(f"Error: {e}")
        
        await asyncio.sleep(interval)

# Run health monitoring
asyncio.run(monitor_health("http://your-alb-dns:8000"))
```

## Verification Steps

### 1. Connection Distribution Test

```bash
# Run connection test
python test_stickiness.py

# Expected output format:
{
  "client_1": {
    "server": "server-1",
    "connections": 5,
    "messages_sent": 50,
    "messages_received": 50
  },
  "client_2": {
    "server": "server-2",
    "connections": 5,
    "messages_sent": 50,
    "messages_received": 50
  }
}
```

### 2. Load Test Verification

```bash
# Run load test
python load_test.py

# Check server logs
aws logs get-log-events --log-group-name /websocket/servers --log-stream-name server-1
aws logs get-log-events --log-group-name /websocket/servers --log-stream-name server-2
```

### 3. State Consistency Check

```python
import redis
import json

def verify_state_consistency():
    redis_client = redis.Redis(host='redis', port=6379, db=0)
    
    # Get all state keys
    state_keys = redis_client.keys("state:*")
    
    # Verify state consistency
    for key in state_keys:
        state = redis_client.get(key)
        print(f"Key: {key}, State: {state}")
        
    # Check connection mapping
    connection_keys = redis_client.keys("connection:*")
    for key in connection_keys:
        connection = redis_client.get(key)
        print(f"Connection: {key}, Server: {connection}")

verify_state_consistency()
```

## 🎯 Success Criteria

1. **Connection Stickiness**
   - Each client maintains connection to the same server
   - No connection drops during scaling events
   - Messages are delivered consistently

2. **State Management**
   - State is properly synchronized across servers
   - No data loss during scaling
   - Consistent state across all instances

3. **Performance**
   - Response time remains stable under load
   - No message loss during high traffic
   - Efficient resource utilization

4. **Scalability**
   - New servers can handle new connections
   - Existing connections remain stable
   - State is properly distributed

## Monitoring Metrics


## Test Results Analysis

1. **Connection Analysis**
   - Track connection distribution
   - Monitor connection stability
   - Verify sticky session behavior

2. **Performance Analysis**
   - Measure response times
   - Track message delivery rates
   - Monitor resource usage

3. **State Analysis**
   - Verify state consistency
   - Check data integrity
   - Monitor synchronization

4. **Scaling Analysis**
   - Track scaling events
   - Monitor connection redistribution
   - Verify state migration

## Conclusion

To prove WebSocket scaling with session stickiness:
1. Run comprehensive connection tests
2. Perform load testing
3. Monitor health metrics
4. Verify state consistency
5. Analyze performance data

The success of the scaling implementation is proven when:
- All connections maintain stickiness
- State remains consistent
- Performance meets requirements
- Scaling events are handled smoothly 

## 📚 Related Chapters

1. **WebSocket Connection and Sticky Sessions** ([Learn more](/DOC/Stickiness.md))
2. **Shared Session Management** ([Learn more](/DOC/Shared-sessions.md))
3. **Scaling WebSocket Applications** ([Learn more](/DOC/websocket-scaling.md))
4.  **Terraform Deployment for WebSocket Infrastructure** ([Learn more](/DOC/Terraform-deployment.md))