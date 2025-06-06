# WebSocket Server with ALB Setup

This project implements a WebSocket server using FastAPI and deploys it behind an AWS Application Load Balancer (ALB) with WebSocket support.

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
```bash
cd terraform
terraform init
terraform apply
```

Note: You'll need to provide an SSL certificate ARN for HTTPS support.

After setup, if want to restart the project:
destroy the existing infrastructure:
```bash
cd terraform; terraform destroy -auto-approve
```
First, let's make sure our FastAPI server is running. Open a new terminal and run
```bash
cd ..; python app.py
```
Now, let's initialize and apply the Terraform configuration:
```bash
cd terraform; terraform init
terraform apply -auto-approve
```

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
<!-- ```bash -->

I'll give you a step-by-step guide to test the WebSocket project workflow:

1. **First, let's make sure we're in the correct directory and have all files:**

Ran tool
Perfect! Here's the step-by-step testing workflow:

### Step 1: Install Dependencies
```bash
pip install -r requirements.txt
```

### Step 2: Start the WebSocket Server
```bash
python app.py
```

### Expected Behavior:
1. **Connection:**
   - Immediate connection when opening test.html
   - Connection status message appears

2. **Messaging:**
   - Messages sent appear in the message box
   - Server echoes back the same message
   - Messages are properly formatted

3. **Disconnection:**
   - Clean disconnection when closing the browser
   - Proper cleanup of connections

4. **Health Check:**
   - `/health` endpoint returns 200 OK
   - Shows correct number of active connections

### Troubleshooting:
If something doesn't work:

1. **Connection Issues:**
   - Check if server is running
   - Verify port 8000 is not in use
   - Check browser console for errors

2. **Message Issues:**
   - Check server logs for errors
   - Verify message format
   - Check browser console for errors

3. **Server Issues:**
   - Check Python version (should be 3.11+)
   - Verify all dependencies are installed
   - Check for any error messages in the console
------------------------------------------------