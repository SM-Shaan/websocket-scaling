import asyncio
import websockets
import json
import time

async def test_stickiness():
    uri = "ws://websocket-alb-20250609042220-945251384.ap-southeast-1.elb.amazonaws.com/ws"
    
    # Test first connection
    print("\nTesting first connection...")
    async with websockets.connect(uri) as websocket:
        response = await websocket.recv()
        data = json.loads(response)
        print(f"First connection - Hostname: {data['hostname']}")
        await websocket.send("Test message 1")
        response = await websocket.recv()
        print(f"First connection response: {response}")
    
    # Wait a bit before second connection
    await asyncio.sleep(1)
    
    # Test second connection
    print("\nTesting second connection...")
    async with websockets.connect(uri) as websocket:
        response = await websocket.recv()
        data = json.loads(response)
        print(f"Second connection - Hostname: {data['hostname']}")
        await websocket.send("Test message 2")
        response = await websocket.recv()
        print(f"Second connection response: {response}")
    
    # Wait a bit before third connection
    await asyncio.sleep(1)
    
    # Test third connection
    print("\nTesting third connection...")
    async with websockets.connect(uri) as websocket:
        response = await websocket.recv()
        data = json.loads(response)
        print(f"Third connection - Hostname: {data['hostname']}")
        await websocket.send("Test message 3")
        response = await websocket.recv()
        print(f"Third connection response: {response}")

if __name__ == "__main__":
    asyncio.run(test_stickiness()) 