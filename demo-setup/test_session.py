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