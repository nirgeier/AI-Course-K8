# Example: Simple MCP Server Template

This is a starter template for creating MCP servers with basic functionality.

## Quick Start

```bash
# Clone template
cp -r resources/templates/simple-mcp-server my-mcp-server
cd my-mcp-server

# Install dependencies
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Run server
python -m src.server
```

## Project Structure

```
simple-mcp-server/
├── requirements.txt
├── Dockerfile
├── src/
│   ├── __init__.py
│   ├── server.py
│   └── tools/
│       ├── __init__.py
│       └── example.py
└── k8s/
    └── deployment.yaml
```

## Files

### requirements.txt

```txt
mcp>=0.1.0
kubernetes>=28.0.0
pydantic>=2.0.0
structlog>=23.0.0
prometheus-client>=0.19.0
```

### src/server.py

```python
"""Simple MCP Server."""

import asyncio
from typing import Any, Dict, List
from mcp.server import Server
from mcp.server.stdio import stdio_server

from .tools.example import example_tool, get_example_tool_definition

server = Server("simple-mcp-server")

@server.list_tools()
async def list_tools() -> List[Dict[str, Any]]:
    """List available tools."""
    return [get_example_tool_definition()]

@server.call_tool()
async def call_tool(name: str, arguments: Dict[str, Any]) -> Any:
    """Handle tool calls."""
    if name == "example_tool":
        return await example_tool(arguments)
    return {"success": False, "error": f"Unknown tool: {name}"}

async def main():
    """Run the server."""
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            server.create_initialization_options(),
        )

if __name__ == "__main__":
    asyncio.run(main())
```

### src/tools/example.py

```python
"""Example MCP tool."""

from typing import Dict, Any

async def example_tool(arguments: Dict[str, Any]) -> Dict[str, Any]:
    """
    Example tool that echoes back the input.
    
    Args:
        arguments: Input arguments
    
    Returns:
        Echo response
    """
    message = arguments.get("message", "Hello, World!")
    
    return {
        "success": True,
        "echo": message,
        "length": len(message),
    }

def get_example_tool_definition() -> Dict[str, Any]:
    """Get tool definition."""
    return {
        "name": "example_tool",
        "description": "Example tool that echoes back your message",
        "inputSchema": {
            "type": "object",
            "properties": {
                "message": {
                    "type": "string",
                    "description": "Message to echo back",
                }
            },
        },
    }
```

### Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/

CMD ["python", "-m", "src.server"]
```

### k8s/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: simple-mcp-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: simple-mcp-server
  template:
    metadata:
      labels:
        app: simple-mcp-server
    spec:
      containers:
        - name: server
          image: simple-mcp-server:latest
          imagePullPolicy: Never
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "200m"
```

## Usage

### Build and Deploy

```bash
# Build Docker image
docker build -t simple-mcp-server:latest .

# Load into kind
kind load docker-image simple-mcp-server:latest --name mcp-dev-cluster

# Deploy to Kubernetes
kubectl apply -f k8s/deployment.yaml

# Check status
kubectl get pods -l app=simple-mcp-server
```

### Test the Tool

```bash
# Get pod name
POD=$(kubectl get pod -l app=simple-mcp-server -o jsonpath='{.items[0].metadata.name}')

# Test example tool
kubectl exec -it $POD -- python -c "
import asyncio
from src.tools.example import example_tool

async def test():
    result = await example_tool({'message': 'Hello from Kubernetes!'})
    print(result)

asyncio.run(test())
"
```

## Next Steps

1. Add more tools in `src/tools/`
2. Implement proper error handling
3. Add input validation with Pydantic
4. Add metrics and logging
5. Create comprehensive tests

## Resources

- [MCP Documentation](https://mcp.run/docs)
- [Course Materials](../../README.md)
- [Best Practices](../../docs/best-practices.md)
