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

### Step 3: Test the Health Endpoint
1. Open your web browser
2. Go to: `http://localhost:8000/health`
3. You should see a JSON response like:
```json
{
    "status": "healthy",
    "connections": 0
}
```

### Step 4: Test WebSocket Connection
1. Open the `test.html` file in your web browser
2. You should see:
   - A message box
   - A "Connected to WebSocket server" message
   - An input field to type messages

### Step 5: Test Message Exchange
1. Type a message in the input field
2. Click "Send" or press Enter
3. You should see:
   - "Sent: [your message]" in the message box
   - "Received: [your message]" as an echo response

### Step 6: Test Multiple Connections
1. Open `test.html` in multiple browser windows
2. Each window should:
   - Connect successfully
   - Show its own connection status
   - Be able to send/receive messages independently

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



## Deployment

2. Deploy infrastructure:

After setup, if want to restart the project:
destroy the existing infrastructure:
```bash
cd terraform; terraform destroy -auto-approve
```

Now, let's initialize and apply the Terraform configuration:
```bash
cd terraform; 
terraform init
terraform apply -auto-approve
```
Note: You'll need to provide an SSL certificate ARN for HTTPS support.

After deployment:
I'll help you check the WebSocket connection after deployment. There are several ways to test it:

1. First, let's get the ALB DNS name to connect to:

```bash
terraform output alb_dns_name
```
You can test the WebSocket connection in several ways:

1. Using a WebSocket client in your browser:
```javascript
// Open your browser's developer console and run:
const ws = new WebSocket('ws://websocket-alb-1942287967.ap-southeast-1.elb.amazonaws.com:8000');
ws.onopen = () => console.log('Connected!');
ws.onmessage = (event) => console.log('Received:', event.data);
ws.onerror = (error) => console.log('Error:', error);
ws.onclose = () => console.log('Disconnected!');
```

2. Using `wscat` (a command-line WebSocket client):
```bash
# Install wscat
npm install -g wscat

# Connect to WebSocket
wscat -c ws://websocket-alb-412984565.ap-southeast-1.elb.amazonaws.com:8000
```

3. Using Python with `websockets`:
```python
import asyncio
import websockets

async def test_connection():
    uri = "ws://websocket-alb-412984565.ap-southeast-1.elb.amazonaws.com.com:8000"
    async with websockets.connect(uri) as websocket:
        print("Connected!")
        # Send a test message
        await websocket.send("Hello!")
        # Receive response
        response = await websocket.recv()
        print(f"Received: {response}")

asyncio.get_event_loop().run_until_complete(test_connection())
```

4. Check the health endpoint:
```bash
curl http://websocket-alb-412984565.ap-southeast-1.elb.amazonaws.com/health
```

Important notes:
1. Make sure your WebSocket application is actually running on the EC2 instance. You can check this by:
   ```bash
   # SSH into the EC2 instance
   ssh ec2-user@<EC2_PUBLIC_IP>
   
   # Check if Docker container is running
   docker ps
   
   # Check container logs
   docker logs <container_id>
   ```

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

-----------------------------------


How to Test Communication
1. Test via the Application Load Balancer (ALB)
Open your test-client.html in two browser windows or tabs.
Set the WebSocket URL to:
```text
  ws://websocket-alb-20250606023454-943737327.ap-southeast-1.elb.amazonaws.com:8000/ws
```
Click "Connect" in both clients.
Send messages from each client.
Observe the hostname field in the server's response. If the hostnames are different, your connections are handled by different EC2 instances.

2. Test Directly to Each EC2 Instance
Change the WebSocket URL in your test client to:
ws://52.221.232.163:8000/ws (Instance 1)
ws://47.129.30.18:8000/ws (Instance 2)
Connect to each instance in separate browser windows/tabs.
Send messages and observe the responses.

3. Test Instance-to-Instance Communication (from inside EC2)
If you want to test communication between the two EC2 instances themselves (not via ALB), you can SSH into one instance and use curl or websocat to connect to the other:
SSH into Instance 1:
```bash
  ssh -i <private your-key> ec2-user@52.221.232.163
```
Install websocat (if not already installed):

```bash
  sudo yum install -y epel-release
  sudo yum install -y websocat
```

Connect to Instance 2's WebSocket server
```bash
  websocat ws://47.129.30.18:8000/ws
```
-------------------------------
For Script:

pip install websockets asyncio
python test_websocket.py
---------------------------------


You can test these URLs in several ways:
1. Using the test client HTML:
- Open test-client.html in your browser
- Enter one of the URLs above in the connection field
- Click "Connect"
2. Try connecting again with the test script:
```bash
cd ..
python test_websocket.py --alb <new-alb-dns>:8000 --instance1 <new-instance1-ip>:8000 --instance2 <new-instance2-ip>:8000
```
2.1 You can verify the server status separately by:
2.1.1. Checking the ALB health endpoint:
```bash
curl http://websocket-alb-20250606023454-943737327.ap-southeast-1.elb.amazonaws.com:8000/health
```
2.1.2. Checking direct instance health:
```bash
curl http://54.251.10.12:8000/health
curl http://54.255.76.86:8000/health
```

3. Using browser console:
```javascript
const ws = new WebSocket('ws://websocket-alb-20250606023454-943737327.ap-southeast-1.elb.amazonaws.com:8000/ws');
ws.onopen = () => console.log('Connected!');
ws.onmessage = (event) => console.log('Received:', event.data);
ws.onerror = (error) => console.log('Error:', error);
ws.onclose = () => console.log('Disconnected!');
```

4. Using wscat (command-line WebSocket client)
```bash
wscat -c ws://websocket-alb-20250606023454-943737327.ap-southeast-1.elb.amazonaws.com:8000/ws
```

Recommendation:
For basic testing and development: Use test-client.html
For quick testing: Use test.html
For production monitoring and debugging: Use websocket_monitor.html