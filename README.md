# WebSocket Server with ALB Setup

This project implements a WebSocket server using FastAPI and deploys it behind an AWS Application Load Balancer (ALB) with WebSocket support.

## Table of Contents
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Local Development](#local-development)
- [Testing](#testing)
- [Deployment](#deployment)
- [Infrastructure Components](#infrastructure-components)
- [Security](#security)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)

## Features

- FastAPI WebSocket server with proper upgrade headers
- AWS ALB with WebSocket listeners (HTTP 80 / HTTPS 443)
- ALB target group stickiness enabled
- Containerized application using Docker
- Infrastructure as Code using Terraform

## Prerequisites

- Python 3.11+
- Docker
- AWS CLI configured with appropriate credentials
- Terraform installed
- SSL certificate for HTTPS (if using HTTPS)

## Local Development

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Run the server locally:
```bash
python app.py
```
You should see output like:
```
INFO:     Will watch for changes in these directories: ['E:\\websocket']
INFO:     Uvicorn running on http://localhost:8000 (Press CTRL+C to quit)
INFO:     Started reloader process [...]
INFO:     Application startup complete.
```

### Step 3: Test WebSocket Connection
1. Open the `test.html` file in your web browser
2. You should see:
   - A message box
   - A "Connected to WebSocket server" message
   - An input field to type messages

### Step 4: Test Message Exchange
1. Type a message in the input field
2. Click "Send" or press Enter
3. You should see:
   - "Sent: [your message]" in the message box
   - "Received: [your message]" as an echo response

### Step 5: Test Multiple Connections
1. Open `test.html` in multiple browser windows
2. Each window should:
   - Connect successfully
   - Show its own connection status
   - Be able to send/receive messages independently
![Health_check](images/diagram.svg)
![Health_check](images/diagram.svg)

### Step 6: Test the Health Endpoint
1. Open your web browser
2. Go to: `http://localhost:8000/health`
3. You should see a JSON response like:
```json
{
    "status": "healthy",
    "connections": 0
}
```
![Health_check](images/diagram.svg)

### Step 7: Test Error Handling
1. Stop the server (Ctrl+C)
2. You should see:
   - "Disconnected from WebSocket server" in the test.html window
3. Restart the server
4. The connection should automatically reconnect

### Step 8: Monitor Server Logs
While testing, watch the server console for:
- Connection events
- Message receipts
- Disconnection events
- Any errors

![Health_check](images/diagram.svg)

## Deployment

2. Deploy infrastructure:

Now, let's initialize and apply the Terraform configuration:
```bash
cd terraform; 

# Generate key pair
ssh-keygen -t rsa -b 2048 -f websocket-key -N '""'

terraform init
terraform apply -auto-approve
```
![Health_check](images/diagram.svg)

Note: You'll need to provide an SSL certificate ARN for HTTPS support.

After deployment:
I'll help you check the WebSocket connection after deployment. There are several ways to test it:

1. First, let's get the ALB DNS name to connect to:

```bash
terraform output alb_dns_name
```
You can test the WebSocket connection in several ways:

1. Check the health endpoint:
```bash
curl http://websocket-alb-20250609042220-945251384.ap-southeast-1.elb.amazonaws.com/health
```
![Health_check](images/diagram.svg)

2. Test the WebSocket connection:
```bash
wscat -c ws://websocket-alb-20250609042220-945251384.ap-southeast-1.elb.amazonaws.com/ws
```
![Health_check](images/diagram.svg)

3. Open Google Chrome. Right-click anywhere on the page and select Inspect. Go to the Console tab. Using a WebSocket client in your browser:
```javascript
// Open your browser's developer console and run:
const ws2 = new WebSocket('ws://websocket-alb-20250609025907-1638792794.ap-southeast-1.elb.amazonaws.com/ws');
ws2.onopen = () => { 
  console.log('Connected!');
  ws2.send('Hello from browser!');
};
ws2.onmessage = (event) => console.log('Received:', event.data);
ws2.onerror = (error) => console.log('Error:', error);
ws2.onclose = () => console.log('Disconnected!');
```
<!-- 
2. Test direct connection to EC2
SSH into any of EC2 instances: ssh -i <private your-key> ec2-user@52.221.232.163
Using `wscat` (a command-line WebSocket client):
```bash
# Install wscat
sudo npm install -g wscat

# wscat -c ws://18.141.164.235:8000/ws
# Connect to WebSocket
wscat -c ws://websocket-alb-20250609060951-486339179.ap-southeast-1.elb.amazonaws.com:8000
``` -->

4. Using Python with `websockets`:
```python
import asyncio
import websockets

async def test_connection():
    uri = "ws://websocket-alb-20250609052437-259866380.ap-southeast-1.elb.amazonaws.com:8000"
    async with websockets.connect(uri) as websocket:
        print("Connected!")
        # Send a test message
        await websocket.send("Hello!")
        # Receive response
        response = await websocket.recv()
        print(f"Received: {response}")

asyncio.get_event_loop().run_until_complete(test_connection())
```

## How to Test Communication
1. Test via the Application Load Balancer (ALB)
Open your test-client.html in two browser windows or tabs.
Set the WebSocket URL to:
```text
  ws = new WebSocket('ws://websocket-alb-20250609060951-486339179.ap-southeast-1.elb.amazonaws.com/ws');
```
Click "Connect" in both clients.
Send messages from each client.

![Health_check](images/diagram.svg)

Observe the hostname field in the server's response. If the hostnames are different, your connections are handled by different EC2 instances.

Important notes:
1. Make sure your WebSocket application is actually running on the EC2 instance. You can check this by:
```bash
   # SSH into the EC2 instance
   ssh -i <websocket-private-key> ec2-user@18.141.164.235
   
   # Check if Docker container is running
   docker ps
   ![Health_check](images/diagram.svg)
   
   # Check container logs
   docker logs <container_id>
```
   ![Health_check](images/diagram.svg)

2. Verify the security groups allow traffic:
   - ALB security group should allow inbound traffic on port 80
   - EC2 security group should allow inbound traffic on port 8000 from the ALB

3. Check the target group health:
   - Go to AWS Console → EC2 → Target Groups
   - Select your target group
   - Check if the EC2 instance is healthy


## Infrastructure Components

- VPC with public subnets
- Application Load Balancer
- Target Group with stickiness enabled
- Security Groups for ALB and ECS tasks
- HTTP (80) and HTTPS (443) listeners

## Health Check

The application includes a health check endpoint at `/health` that returns the current number of active WebSocket connections.

## Security

- CORS is enabled for development (should be restricted in production)
- Security groups are configured to allow only necessary traffic
- HTTPS support with SSL/TLS termination at the ALB

## Monitoring

The application logs WebSocket connections, disconnections, and messages. You can monitor these logs in CloudWatch when deployed to AWS. 

After setup, if want to restart the project:
destroy the existing infrastructure:
```bash
cd terraform; terraform destroy -auto-approve
```
---
## Recommendation:
- For basic testing and development: Use test-client.html
- For quick testing: Use test.html
- For production monitoring and debugging: Use websocket_monitor.html

<!-- 2. Test Directly to Each EC2 Instance
Change the WebSocket URL in your test client to:
ws://52.221.232.163:8000/ws (Instance 1)
ws://47.129.30.18:8000/ws (Instance 2)
Connect to each instance in separate browser windows/tabs.
Send messages and observe the responses. -->

<!-- 3. Test Instance-to-Instance Communication (from inside EC2)
If you want to test communication between the two EC2 instances themselves (not via ALB), you can SSH into one instance and use curl or websocat to connect to the other:
SSH into Instance 1:
```bash
  ssh -i <websocket-private-key> ec2-user@18.141.164.235
```
Install websocat (if not already installed) or EC2 instance is missing the cc compiler needed to install websocat:

```bash
  sudo yum groupinstall -y 'Development Tools'
  sudo yum install -y openssl-devel
```

Connect to Instance 2's WebSocket server
```bash
  websocat ws://18.141.164.235:8000/ws -->

