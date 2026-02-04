"""
Example script demonstrating how to use the chat endpoints.

This script shows both streaming and non-streaming usage.
"""

import requests
import json


# API base URL (update if running on different host/port)
BASE_URL = "http://localhost:8000"


def test_non_streaming_chat():
    """Test the non-streaming chat endpoint"""
    print("=" * 60)
    print("Testing Non-Streaming Chat Endpoint")
    print("=" * 60)
    
    # Prepare request
    request_data = {
        "messages": [
            {"role": "user", "content": "Hello, can you help me with Python?"}
        ],
        "agent_id": "python-helper",
        "max_tokens": 1000,
        "temperature": 0.7
    }
    
    # Send request
    response = requests.post(f"{BASE_URL}/chat", json=request_data)
    
    # Print response
    if response.status_code == 200:
        result = response.json()
        print(f"\nAgent: {result['agent_id']}")
        print(f"Timestamp: {result['timestamp']}")
        print(f"Tokens Used: {result['tokens_used']}")
        print(f"\nResponse:\n{result['message']['content']}")
    else:
        print(f"Error: {response.status_code}")
        print(response.text)
    
    print("\n")


def test_streaming_chat():
    """Test the streaming chat endpoint"""
    print("=" * 60)
    print("Testing Streaming Chat Endpoint")
    print("=" * 60)
    
    # Prepare request
    request_data = {
        "messages": [
            {"role": "user", "content": "Tell me about streaming responses"}
        ],
        "agent_id": "streaming-agent",
        "max_tokens": 1000,
        "temperature": 0.7
    }
    
    # Send request with streaming
    response = requests.post(
        f"{BASE_URL}/chat/stream",
        json=request_data,
        stream=True
    )
    
    print("\nStreaming Response:")
    print("-" * 40)
    
    # Process streaming response
    if response.status_code == 200:
        for line in response.iter_lines():
            if line:
                # Decode line
                line_str = line.decode('utf-8')
                
                # Parse SSE format (lines start with "data: ")
                if line_str.startswith("data: "):
                    data_json = line_str[6:]  # Remove "data: " prefix
                    chunk = json.loads(data_json)
                    
                    if chunk.get('done'):
                        print("\n[Stream completed]")
                        break
                    else:
                        # Print chunk content without newline
                        print(chunk['content'], end='', flush=True)
    else:
        print(f"Error: {response.status_code}")
        print(response.text)
    
    print("\n")


def main():
    """Run all tests"""
    print("\n" + "=" * 60)
    print("HackNation AI Chat API - Example Usage")
    print("=" * 60 + "\n")
    
    # Test health endpoint first
    print("Checking API health...")
    try:
        health_response = requests.get(f"{BASE_URL}/health")
        if health_response.status_code == 200:
            print("✓ API is healthy\n")
        else:
            print("✗ API health check failed")
            return
    except requests.exceptions.ConnectionError:
        print("✗ Cannot connect to API. Make sure the server is running on", BASE_URL)
        print("  Start the server with: python main.py")
        return
    
    # Run tests
    test_non_streaming_chat()
    test_streaming_chat()
    
    print("=" * 60)
    print("All tests completed!")
    print("=" * 60)


if __name__ == "__main__":
    main()
