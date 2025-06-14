# 🔄 Shared Sessions and Stickiness in WebSocket Applications

## 📋 Table of Contents
1. [Overview](#overview)
2. [What is a Shared Session?](#what-is-a-shared-session)
3. [Relationship with Stickiness](#relationship-with-stickiness)
4. [Key Components](#key-components)
5. [Implementation Considerations](#implementation-considerations)
6. [Demo Setup](#demo-setup)
7. [Testing](#testing)
8. [Best Practices](#best-practices)
9. [Conclusion](#conclusion)

## 🎯 Overview

Shared sessions and stickiness are critical concepts in WebSocket applications, especially in distributed systems. This document explores their importance, implementation strategies, and best practices.

## 💡 What is a Shared Session?

A shared session allows session data to be maintained and accessed across multiple server instances in a distributed system. This ensures consistent user experiences by centralizing session information such as user state, connection details, and application-specific data.

### Why Are Shared Sessions Important?

1. **Consistent User Experience**: Users can switch between servers without losing session state.
2. **Scalability**: New server instances integrate seamlessly without additional session management logic.
3. **High Availability**: Users can reconnect to another server without losing session data during server failures.

## 🔗 Relationship with Stickiness

### With Stickiness Only
![With Stickiness](/DOC/diagrams/stickiness.drawio.svg)

- **Pros**: Simpler session management, reduced synchronization overhead, lower latency.
- **Cons**: Uneven server load, single point of failure, limited scalability.

### With Shared Session
![With Stickiness](/DOC/diagrams/redis.drawio.svg)

### With Stickiness and Shared Session

- **Pros**: Combines the simplicity of stickiness with the resilience of shared sessions
- **Cons**: Increases complexity due to hybrid session management

## 🏗️ Key Components

1. **Session Data Storage**  
   - Centralized storage solutions (Redis, Memcached)
   - Distributed databases
   - In-memory data stores

2. **Session Synchronization**  
   - Real-time updates to propagate changes across servers.
   - Conflict resolution to handle concurrent modifications.
   - Data consistency to ensure a unified session state.

3. **Session Management Strategies**  
   - Pub/Sub mechanisms for real-time updates.
   - Eventual consistency for applications tolerating slight delays.
   - Atomic transactions for strict consistency.

4. **Security Considerations**  
   - Encrypt session data in transit and at rest.
   - Implement session expiration to prevent stale sessions.
   - Enforce access control for authorized server access.

## 🚀 Demo Setup

## When Do You Need Shared Sessions?

1. **Horizontal Scaling**: For load balancing and high availability.
2. **Stateful Applications**: Real-time apps, multi-user systems, or apps requiring session persistence.
3. **High Availability Requirements**: For server failover and disaster recovery.

---

## Implementation Considerations


### 1. Without Shared Sessions (Using Stickiness)
![With Stickiness](/DOC/diagrams/dia3.drawio.svg)

- Store session data locally on each server.
- Rely on load balancer stickiness for routing.

### 2. With Shared Sessions

![With Stickiness](/DOC/diagrams/dia4.drawio.svg)

- Use centralized storage like Redis for session data.
- Implement real-time synchronization and conflict resolution.
---


## Real-Life Scenarios

### Scenario 1: Real-Time Chat Application

#### With Stickiness
- Suitable for small to medium chat apps with minimal cross-server communication.

#### Without Stickiness (Shared Sessions)
- Ideal for large-scale platforms requiring real-time presence and room switching.

### Scenario 2: Multiplayer Game

#### With Stickiness
- Works for turn-based or single-player games with isolated game states.

#### Without Stickiness (Shared Sessions)
- Necessary for real-time multiplayer games with global state synchronization.


# Shared Session Demo Setup 🛠️

This demo demonstrates a shared session concept using Nginx load balancer, two Flask application servers, and Redis for session storage.

## Architecturef

![With Stickiness](/DOC/diagrams/dia5.drawio.svg)

### Components

#### Nginx Load Balancer
- Acts as a reverse proxy and load balancer
- Uses `ip_hash` for sticky sessions, ensuring the same client always hits the same backend server
- Handles WebSocket connections
- Configuration features:
  - Load balancing between two application servers
  - Sticky session based on client IP
  - WebSocket support
  - HTTP/1.1 protocol support
  - Header forwarding for proper client identification

#### 🗄️ Redis Server
- Centralized session storage
- In-memory data store with persistence options
- Features used in this demo:
  - Session data storage
  - Key-value storage for session information
  - Automatic key expiration
  - High availability and scalability
  - Real-time session synchronization

#### 🖥️ Application Servers
- Identical Flask applications
- Share session data through Redis
- Features:
  - Session management using Flask-Session
  - Redis backend for session storage
  - Visit counter demonstration
  - Server identification

### Code Configuration

#### Nginx Configuration
The `nginx.conf` file in the `demo-setup` folder configures the load balancer for sticky sessions and WebSocket support:

```nginx
events {
    worker_connections 1024;
}

http {
    upstream backend {
        ip_hash;  # This enables sticky sessions based on client IP
        server app1:5000;
        server app2:5000;
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
```

#### Flask Application Code
The `app.py` file in the `demo-setup` folder demonstrates session management using Flask and Redis:

```python
from flask import Flask, session, jsonify
from flask_session import Session
import redis
import os
import socket

app = Flask(__name__)

# Configure Redis for session storage
app.config['SESSION_TYPE'] = 'redis'
app.config['SESSION_REDIS'] = redis.Redis(
    host='redis',
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
```

### Docker Compose Configuration
The `docker-compose.yml` file sets up the environment with Nginx, Redis, and two Flask application servers:

```yaml
version: '3'

services:
  nginx:
    image: nginx:latest
    ports:
      - "8080:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - app1
      - app2

  app1:
    build: ./app1
    environment:
      - FLASK_ENV=production
    depends_on:
      - redis

  app2:
    build: ./app1  # Reusing the same app code
    environment:
      - FLASK_ENV=production
    depends_on:
      - redis

  redis:
    image: redis:latest
    ports:
      - "6379:6379" 
```

### Dockerfile
The `Dockerfile` builds the Flask application image:

```dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

CMD ["python", "app.py"] 
```

### Requirements File
The `requirements.txt` file lists the dependencies:

```
flask==2.0.1
flask-session==0.4.0
redis==4.0.2
werkzeug==2.0.3 
```
The `test_requirements.txt` file lists the dependencies:

```
requests==2.31.0 
```

### Testing File
The `test_session.py` file sets up 
```
#!/usr/bin/env python3

import sys
import time
from collections import defaultdict

def check_dependencies():
    try:
        import requests
        return requests
    except ImportError:
        print("Error: requests module not found. Please install it using:")
        print("pip install requests==2.31.0")
        sys.exit(1)

def test_session_sharing():
    requests = check_dependencies()
    base_url = "http://localhost:8080"
    session_data = defaultdict(list)
    
    print("Testing session sharing between servers...")
    print("=" * 50)
    
    # Make multiple requests to simulate different users
    for user_id in range(3):
        print(f"\nTesting User {user_id + 1}:")
        print("-" * 30)
        
        # Create a session for this user
        with requests.Session() as session:
            # Make 5 requests for each user
            for i in range(5):
                try:
                    response = session.get(base_url)
                    data = response.json()
                    
                    print(f"Request {i + 1}:")
                    print(f"  Server: {data['message']}")
                    print(f"  Session ID: {data['session_id']}")
                    print(f"  Visit Count: {data['visits']}")
                    
                    # Store the data for analysis
                    session_data[user_id].append({
                        'server': data['message'],
                        'session_id': data['session_id'],
                        'visits': data['visits']
                    })
                    
                    # Small delay between requests
                    time.sleep(1)
                except requests.exceptions.ConnectionError:
                    print("Error: Could not connect to the server. Make sure the application is running.")
                    return
                except Exception as e:
                    print(f"Error during request: {str(e)}")
                    break
    
    # Analyze the results
    print("\nAnalysis:")
    print("=" * 50)
    
    for user_id, requests in session_data.items():
        print(f"\nUser {user_id + 1} Analysis:")
        print("-" * 30)
        
        # Check if session ID remained consistent
        session_ids = set(req['session_id'] for req in requests)
        print(f"Session IDs: {session_ids}")
        print(f"Session ID consistent: {len(session_ids) == 1}")
        
        # Check if visit count increased correctly
        visits = [req['visits'] for req in requests]
        print(f"Visit counts: {visits}")
        print(f"Visit count increased correctly: {visits == list(range(1, len(visits) + 1))}")
        
        # Check which servers handled the requests
        servers = set(req['server'] for req in requests)
        print(f"Servers used: {servers}")
        print(f"Sticky session working: {len(servers) == 1}")

if __name__ == "__main__":
    test_session_sharing() 
```

## Setup Instructions

1. Make sure you have Docker and Docker Compose installed on your system.

2. Navigate to the demo-setup directory:
   ```bash
   cd demo-setup
   ```

3. Start the services:
   ```bash
   docker-compose up --build
   ```

4. The application will be available at `http://localhost:8080`

## 🧪 Testing

### Manual Testing
1. Open your browser and navigate to `http://localhost:8080`
2. Refresh the page multiple times
3. You should see:
   - The same session ID being maintained
   - The visit counter incrementing
   - The hostname alternating between app1 and app2 (due to sticky sessions if you disconnect)

![With Stickiness](/DOC/images/demo3.png)

### Automated Testing
To run the automated session test:

1. Create and activate a virtual environment:
   ```bash
   python -m venv venv
   .\venv\Scripts\activate  # On Windows
   source venv/bin/activate  # On Unix/MacOS
   ```

2. Install the test requirements:
   ```bash
   pip install -r test_requirements.txt
   ```

3. Run the test script:
   ```bash
   python test_session.py
   ```

The test script will:
- Simulate 3 different users making requests
- Each user makes 5 requests
- Verify that:
  - Session IDs remain consistent for each user
  - Visit counters increment correctly
  - Sticky sessions are working (each user stays on the same server)

![With Stickiness](/DOC/images/demo1.png)
![With Stickiness](/DOC/images/demo2.png)

## How it Works

### Session Flow
![With Stickiness](/DOC/diagrams/dia8.drawio.svg)

### Key Features

1. **Sticky Sessions**
   - Nginx uses `ip_hash` to ensure consistent server assignment
   - Same client IP always routes to the same application server
   - Maintains session consistency even with multiple servers

2. **Shared Session Storage**
   - Redis stores session data centrally
   - Both application servers can access the same session data
   - Enables session persistence across server restarts

3. **Load Balancing**
   - Nginx distributes traffic between two application servers
   - Automatic failover if one server goes down
   - Maintains session consistency during load balancing

## Cleanup

To stop and remove all containers:
```bash
docker-compose down
```

## Monitoring

You can monitor the system using:
1. Docker logs:
   ```bash
   docker-compose logs -f
   ```

2. Redis CLI:
   ```bash
   docker-compose exec redis redis-cli
   ```

3. Nginx status:
   ```bash
   curl http://localhost:8080/nginx_status
   ``` 

---
## 📋 Best Practices

1. **Choose Based on Requirements**  
   - Use stickiness for simpler applications.  
   - Use shared sessions for distributed systems.  
   - Consider hybrid approaches for specific use cases.

2. **Performance Considerations**  
   - Monitor synchronization overhead.  
   - Use caching strategies.  
   - Select appropriate storage solutions.

3. **Security Considerations**  
   - Encrypt session data.  
   - Implement session expiration.  
   - Use secure session identifiers.

4. **Scalability Planning**  
   - Design for horizontal scaling.  
   - Implement session cleanup.  
   - Plan for future growth.
   
## 🎯 Conclusion

- **Use stickiness** for simpler applications with minimal session data and performance-critical requirements.
- **Use shared sessions** for high availability, even load distribution, and real-time synchronization.

The hybrid approach (stickiness + shared sessions) combines the best of both worlds, offering efficient routing, reliable communication, and scalability for WebSocket applications.

## 📚 Related Chapters

1. **WebSocket Connection and Sticky Sessions** ([Learn more](/DOC/Stickiness.md))
2. **Shared Session Management** ([Learn more](/DOC/Shared-sessions.md))
3. **Scaling WebSocket Applications** ([Learn more](/DOC/websocket-scaling.md))
4. **Terraform Deployment for WebSocket Infrastructure** ([Learn more](/DOC/Deployment_terraform.md))