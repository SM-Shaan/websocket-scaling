import asyncio
import websockets
import json
import logging
import argparse
from datetime import datetime
import socket
import sys
import dns.resolver # pip install dnspython aiodns
import aiodns

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class WebSocketTester:
    def __init__(self, url, client_id):
        self.url = url
        self.client_id = client_id
        self.connected = False
        self.messages_received = 0
        self.room = "general"
        self.websocket = None

    async def connect(self):
        try:
            # Validate URL format
            if not self.url.startswith(('ws://', 'wss://')):
                self.url = f"ws://{self.url}"
            
            # Add /ws if not present
            if not self.url.endswith('/ws'):
                self.url = f"{self.url}/ws"

            logger.info(f"Attempting to connect {self.client_id} to {self.url}")
            
            # Set a timeout for the connection
            self.websocket = await asyncio.wait_for(
                websockets.connect(self.url, ping_interval=None),
                timeout=10
            )
            
            self.connected = True
            logger.info(f"Client {self.client_id} connected to {self.url}")
                
            # Send initial join message
            await self.join_room(self.room)
            return True
        except asyncio.TimeoutError:
            logger.error(f"Connection timeout for client {self.client_id} to {self.url}")
            return False
        except websockets.exceptions.InvalidStatusCode as e:
            logger.error(f"Invalid status code for client {self.client_id}: {str(e)}")
            return False
        except websockets.exceptions.InvalidMessage as e:
            logger.error(f"Invalid message for client {self.client_id}: {str(e)}")
            return False
        except Exception as e:
            logger.error(f"Connection error for client {self.client_id} to {self.url}: {str(e)}")
            return False

    async def join_room(self, room):
        if self.connected:
            try:
                message = {
                    "type": "join",
                    "room": room,
                    "userId": self.client_id
                }
                await self.websocket.send(json.dumps(message))
                logger.info(f"Client {self.client_id} joined room: {room}")
            except Exception as e:
                logger.error(f"Error joining room for client {self.client_id}: {str(e)}")
                self.connected = False

    async def send_message(self, content):
        if self.connected:
            try:
                message = {
                    "type": "message",
                    "content": content,
                    "room": self.room,
                    "sender": self.client_id
                }
                await self.websocket.send(json.dumps(message))
                logger.info(f"Client {self.client_id} sent message: {content}")
            except Exception as e:
                logger.error(f"Error sending message for client {self.client_id}: {str(e)}")
                self.connected = False

    async def receive_messages(self, timeout=5):
        try:
            while self.connected:
                try:
                    message = await asyncio.wait_for(self.websocket.recv(), timeout=timeout)
                    data = json.loads(message)
                    self.messages_received += 1
                    
                    if data.get("type") == "connection":
                        logger.info(f"Client {self.client_id} received connection info: {data}")
                    elif data.get("type") == "message":
                        logger.info(f"Client {self.client_id} received message from {data.get('sender')}: {data.get('content')}")
                    elif data.get("type") == "user_joined":
                        logger.info(f"Client {self.client_id} received user joined: {data.get('username')}")
                    elif data.get("type") == "user_left":
                        logger.info(f"Client {self.client_id} received user left: {data.get('username')}")
                except asyncio.TimeoutError:
                    logger.warning(f"Timeout waiting for messages for client {self.client_id}")
                    break
                except websockets.exceptions.ConnectionClosed:
                    logger.info(f"Connection closed for client {self.client_id}")
                    self.connected = False
        except Exception as e:
            logger.error(f"Error receiving messages for client {self.client_id}: {str(e)}")
            self.connected = False

    async def close(self):
        if self.connected and self.websocket:
            try:
                await self.websocket.close()
                self.connected = False
                logger.info(f"Client {self.client_id} disconnected")
            except Exception as e:
                logger.error(f"Error closing connection for client {self.client_id}: {str(e)}")

async def resolve_hostname(hostname):
    """Resolve hostname to IP address"""
    try:
        resolver = aiodns.DNSResolver()
        result = await resolver.query(hostname, 'A')
        return result[0].host
    except Exception as e:
        logger.error(f"DNS resolution failed for {hostname}: {str(e)}")
        return None

async def verify_connection(url):
    """Verify if the WebSocket server is reachable"""
    try:
        # Extract host and port from URL
        if url.startswith(('ws://', 'wss://')):
            url = url[6:] if url.startswith('ws://') else url[7:]
        
        host = url.split(':')[0]
        port = int(url.split(':')[1]) if ':' in url else 8000

        # Check if host is an IP address
        try:
            socket.inet_aton(host)
            ip_address = host
            logger.info(f"Using IP address directly: {ip_address}")
        except socket.error:
            # Not an IP address, try DNS resolution
            logger.info(f"Resolving hostname: {host}")
            ip_address = await resolve_hostname(host)
            if not ip_address:
                logger.error(f"Could not resolve hostname: {host}")
                return False
            logger.info(f"Resolved {host} to {ip_address}")
        
        # Try to establish a TCP connection with a shorter timeout
        try:
            logger.info(f"Attempting TCP connection to {ip_address}:{port}")
            reader, writer = await asyncio.wait_for(
                asyncio.open_connection(ip_address, port),
                timeout=5
            )
            writer.close()
            await writer.wait_closed()
            logger.info(f"Successfully connected to {ip_address}:{port}")
            return True
        except asyncio.TimeoutError:
            logger.error(f"Connection timeout for {ip_address}:{port}")
            return False
        except ConnectionRefusedError:
            logger.error(f"Connection refused for {ip_address}:{port}")
            return False
        except Exception as e:
            logger.error(f"Connection error for {ip_address}:{port}: {str(e)}")
            return False
            
    except Exception as e:
        logger.error(f"Connection verification failed for {url}: {str(e)}")
        return False

async def check_server_health(url, resolved_ip=None):
    """Check server health endpoint"""
    try:
        if url.startswith(('ws://', 'wss://')):
            url = url[6:] if url.startswith('ws://') else url[7:]
        
        host = url.split(':')[0]
        port = int(url.split(':')[1]) if ':' in url else 8000
        
        # Use provided IP or resolve hostname
        ip_address = resolved_ip or await resolve_hostname(host)
        if not ip_address:
            return False
            
        logger.info(f"Attempting health check on {ip_address}:{port}")
        
        # Try to connect to health endpoint
        reader, writer = await asyncio.wait_for(
            asyncio.open_connection(ip_address, port),
            timeout=5
        )
        
        # Send HTTP GET request
        request = f"GET /health HTTP/1.1\r\nHost: {host}\r\nConnection: close\r\n\r\n"
        writer.write(request.encode())
        await writer.drain()
        
        # Read response
        response = await reader.read(1024)
        writer.close()
        await writer.wait_closed()
        
        # Log the raw response for debugging
        response_text = response.decode()
        logger.info(f"Health check response from {ip_address}: {response_text}")
        
        # Check for different response types
        if b"502 Bad Gateway" in response:
            logger.error("ALB returned 502 Bad Gateway. This usually means:")
            logger.error("1. EC2 instances are not running")
            logger.error("2. Security groups are blocking traffic")
            logger.error("3. WebSocket server is not running on EC2 instances")
            return False
        elif b"200 OK" in response:
            return True
        else:
            logger.error(f"Unexpected response from health check: {response_text}")
            return False
        
    except Exception as e:
        logger.error(f"Health check failed for {url}: {str(e)}")
        return False

async def test_alb_connection(alb_url):
    """Test connection through ALB"""
    logger.info(f"\nTesting ALB connection: {alb_url}")
    client1 = WebSocketTester(alb_url, "test_client_1")
    client2 = WebSocketTester(alb_url, "test_client_2")
    
    # Connect both clients
    if not await client1.connect() or not await client2.connect():
        logger.error("Failed to connect clients through ALB")
        return False
    
    # Send messages between clients
    await client1.send_message("Hello from client 1")
    await asyncio.sleep(1)
    await client2.send_message("Hello from client 2")
    
    # Wait for messages to be received
    await asyncio.sleep(2)
    
    # Close connections
    await client1.close()
    await client2.close()
    return True

async def test_direct_instance_connection(instance1_url, instance2_url):
    """Test direct connection to EC2 instances"""
    logger.info(f"\nTesting direct instance connections")
    
    # Test Instance 1
    client1 = WebSocketTester(instance1_url, "instance1_client")
    if not await client1.connect():
        logger.error(f"Failed to connect to instance 1: {instance1_url}")
        return False
    
    await client1.send_message("Testing direct connection to instance 1")
    await asyncio.sleep(1)
    await client1.close()
    
    # Test Instance 2
    client2 = WebSocketTester(instance2_url, "instance2_client")
    if not await client2.connect():
        logger.error(f"Failed to connect to instance 2: {instance2_url}")
        return False
    
    await client2.send_message("Testing direct connection to instance 2")
    await asyncio.sleep(1)
    await client2.close()
    return True

async def test_room_functionality(alb_url):
    """Test chat room functionality"""
    logger.info(f"\nTesting room functionality")
    
    # Create clients for different rooms
    general_client = WebSocketTester(alb_url, "general_client")
    support_client = WebSocketTester(alb_url, "support_client")
    
    # Connect and join different rooms
    if not await general_client.connect() or not await support_client.connect():
        logger.error("Failed to connect clients for room testing")
        return False
    
    await general_client.join_room("general")
    await support_client.join_room("support")
    
    # Send messages in different rooms
    await general_client.send_message("Message in general room")
    await support_client.send_message("Message in support room")
    
    # Wait for messages to be received
    await asyncio.sleep(2)
    
    # Close connections
    await general_client.close()
    await support_client.close()
    return True

async def check_ec2_instances(instance1, instance2):
    """Check EC2 instances directly"""
    logger.info("\nChecking EC2 instances directly...")
    
    # Check Instance 1
    logger.info(f"\nChecking Instance 1: {instance1}")
    try:
        host = instance1.split(':')[0]
        port = int(instance1.split(':')[1]) if ':' in instance1 else 8000
        
        # Try TCP connection
        reader, writer = await asyncio.wait_for(
            asyncio.open_connection(host, port),
            timeout=5
        )
        writer.close()
        await writer.wait_closed()
        logger.info(f"Successfully connected to Instance 1: {host}:{port}")
        
        # Try health check
        reader, writer = await asyncio.wait_for(
            asyncio.open_connection(host, port),
            timeout=5
        )
        request = f"GET /health HTTP/1.1\r\nHost: {host}\r\nConnection: close\r\n\r\n"
        writer.write(request.encode())
        await writer.drain()
        response = await reader.read(1024)
        writer.close()
        await writer.wait_closed()
        logger.info(f"Instance 1 health check response: {response.decode()}")
    except Exception as e:
        logger.error(f"Instance 1 check failed: {str(e)}")
    
    # Check Instance 2
    logger.info(f"\nChecking Instance 2: {instance2}")
    try:
        host = instance2.split(':')[0]
        port = int(instance2.split(':')[1]) if ':' in instance2 else 8000
        
        # Try TCP connection
        reader, writer = await asyncio.wait_for(
            asyncio.open_connection(host, port),
            timeout=5
        )
        writer.close()
        await writer.wait_closed()
        logger.info(f"Successfully connected to Instance 2: {host}:{port}")
        
        # Try health check
        reader, writer = await asyncio.wait_for(
            asyncio.open_connection(host, port),
            timeout=5
        )
        request = f"GET /health HTTP/1.1\r\nHost: {host}\r\nConnection: close\r\n\r\n"
        writer.write(request.encode())
        await writer.drain()
        response = await reader.read(1024)
        writer.close()
        await writer.wait_closed()
        logger.info(f"Instance 2 health check response: {response.decode()}")
    except Exception as e:
        logger.error(f"Instance 2 check failed: {str(e)}")

async def test_connection(uri):
    try:
        async with websockets.connect(uri) as websocket:
            print(f"Connected to {uri}!")
            # Send a test message
            await websocket.send("Hello from Python client!")
            # Receive response
            response = await websocket.recv()
            print(f"Received: {response}")
            # Parse the response to extract hostname and client_id
            response_data = json.loads(response)
            print(f"Hostname: {response_data.get('hostname')}")
            print(f"Client ID: {response_data.get('client_id')}")
    except Exception as e:
        print(f"Error connecting to {uri}: {str(e)}")

async def main():
    parser = argparse.ArgumentParser(description='Test WebSocket connections')
    parser.add_argument('--alb', help='ALB WebSocket URL')
    parser.add_argument('--instance1', help='Instance 1 WebSocket URL')
    parser.add_argument('--instance2', help='Instance 2 WebSocket URL')
    args = parser.parse_args()

    if args.alb:
        await test_connection(f"ws://{args.alb}/ws")
    if args.instance1:
        await test_connection(f"ws://{args.instance1}/ws")
    if args.instance2:
        await test_connection(f"ws://{args.instance2}/ws")

if __name__ == "__main__":
    asyncio.run(main()) 