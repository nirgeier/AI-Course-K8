# Lab 2: Building Your First MCP Server

**Duration**: 3 hours  
**Difficulty**: Intermediate

## Overview

In this lab, you will build a complete MCP server from scratch using Python. You'll implement a "Hello World" tool, add error handling and logging, test the server locally, and package it as a container image.

## Learning Objectives

After completing this lab, you will be able to:

- Initialize a new MCP server project
- Implement MCP tools with proper input schemas
- Add error handling and structured logging
- Write unit tests for MCP tools
- Package MCP servers as container images
- Deploy and test MCP servers locally

## Prerequisites

- Completed Lab 1: Environment Setup
- Python 3.10+ installed
- Basic understanding of Python programming
- Familiarity with JSON-RPC concepts

## Architecture

```
┌─────────────────────────────────────────┐
│         MCP Server Architecture         │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │        MCP Protocol Layer         │ │
│  │  (JSON-RPC 2.0 over stdio/HTTP)  │ │
│  └───────────┬───────────────────────┘ │
│              │                          │
│  ┌───────────▼───────────────────────┐ │
│  │         Tool Registry             │ │
│  │  - Register tools                 │ │
│  │  - Validate inputs                │ │
│  │  - Route requests                 │ │
│  └───────────┬───────────────────────┘ │
│              │                          │
│  ┌───────────▼───────────────────────┐ │
│  │         Tool Handlers             │ │
│  │  - hello_world()                  │ │
│  │  - get_cluster_info()             │ │
│  │  - list_pods()                    │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

## Project Structure

```
mcp-hello-server/
├── README.md
├── pyproject.toml
├── requirements.txt
├── Dockerfile
├── .dockerignore
├── .gitignore
├── src/
│   ├── __init__.py
│   ├── server.py           # Main MCP server
│   ├── tools/
│   │   ├── __init__.py
│   │   ├── hello.py        # Hello World tool
│   │   └── k8s.py          # Kubernetes tools
│   └── utils/
│       ├── __init__.py
│       ├── logging.py
│       └── validation.py
├── tests/
│   ├── __init__.py
│   ├── test_hello.py
│   └── test_k8s.py
└── scripts/
    ├── run-dev.sh
    └── test.sh
```

## Part 1: Project Initialization (30 minutes)

### Step 1: Create project structure

```bash
# Create project directory
mkdir -p ~/mcp-servers/mcp-hello-server
cd ~/mcp-servers/mcp-hello-server

# Create directory structure
mkdir -p src/tools src/utils tests scripts

# Create __init__.py files
touch src/__init__.py src/tools/__init__.py src/utils/__init__.py tests/__init__.py
```

### Step 2: Create pyproject.toml

```bash
cat > pyproject.toml << 'EOF'
[build-system]
requires = ["setuptools>=68.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "mcp-hello-server"
version = "0.1.0"
description = "A simple MCP server for Kubernetes operations"
requires-python = ">=3.10"
dependencies = [
    "mcp>=0.1.0",
    "kubernetes>=28.0.0",
    "pydantic>=2.0.0",
    "structlog>=23.0.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "pytest-asyncio>=0.21.0",
    "pytest-cov>=4.0.0",
    "black>=23.0.0",
    "ruff>=0.1.0",
    "mypy>=1.0.0",
]

[tool.black]
line-length = 100
target-version = ['py310']

[tool.ruff]
line-length = 100
select = ["E", "F", "I", "N", "W"]

[tool.mypy]
python_version = "3.10"
strict = true
warn_return_any = true
warn_unused_configs = true
EOF
```

### Step 3: Create requirements.txt

```bash
cat > requirements.txt << 'EOF'
# Core MCP dependencies
mcp>=0.1.0
pydantic>=2.0.0
structlog>=23.0.0

# Kubernetes client
kubernetes>=28.0.0

# Development dependencies
pytest>=7.0.0
pytest-asyncio>=0.21.0
pytest-cov>=4.0.0
black>=23.0.0
ruff>=0.1.0
mypy>=1.0.0
EOF
```

### Step 4: Create virtual environment and install dependencies

```bash
# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install dependencies
pip install -r requirements.txt
```

## Part 2: Implement Core MCP Server (45 minutes)

### Step 1: Create logging utility

```python
cat > src/utils/logging.py << 'EOF'
"""Structured logging configuration for MCP server."""

import logging
import sys
from typing import Any

import structlog


def configure_logging(log_level: str = "INFO") -> None:
    """Configure structured logging for the application."""
    
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=getattr(logging, log_level.upper()),
    )

    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.StackInfoRenderer(),
            structlog.dev.set_exc_info,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.dev.ConsoleRenderer(),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(
            getattr(logging, log_level.upper())
        ),
        context_class=dict,
        logger_factory=structlog.PrintLoggerFactory(),
        cache_logger_on_first_use=True,
    )


def get_logger(name: str) -> Any:
    """Get a configured logger instance."""
    return structlog.get_logger(name)
EOF
```

### Step 2: Create validation utility

```python
cat > src/utils/validation.py << 'EOF'
"""Input validation utilities for MCP tools."""

from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field, ValidationError


class ToolInput(BaseModel):
    """Base class for tool input validation."""
    
    class Config:
        extra = "forbid"  # Forbid extra fields


class HelloWorldInput(ToolInput):
    """Input schema for hello_world tool."""
    
    name: str = Field(..., description="Name to greet", min_length=1, max_length=100)
    language: Optional[str] = Field("en", description="Language code (en, es, fr)")


class ListPodsInput(ToolInput):
    """Input schema for list_pods tool."""
    
    namespace: Optional[str] = Field("default", description="Kubernetes namespace")
    label_selector: Optional[str] = Field(None, description="Label selector for filtering")
    limit: int = Field(10, description="Maximum number of pods to return", gt=0, le=100)


def validate_input(input_class: type[ToolInput], data: Dict[str, Any]) -> ToolInput:
    """Validate input data against a schema."""
    try:
        return input_class(**data)
    except ValidationError as e:
        raise ValueError(f"Input validation failed: {e}")
EOF
```

### Step 3: Create Hello World tool

```python
cat > src/tools/hello.py << 'EOF'
"""Hello World MCP tool implementation."""

from typing import Dict, Any
from ..utils.logging import get_logger
from ..utils.validation import HelloWorldInput, validate_input

logger = get_logger(__name__)


GREETINGS = {
    "en": "Hello",
    "es": "Hola",
    "fr": "Bonjour",
    "de": "Guten Tag",
    "ja": "こんにちは",
}


async def hello_world(arguments: Dict[str, Any]) -> Dict[str, Any]:
    """
    A simple greeting tool that demonstrates MCP tool implementation.
    
    Args:
        arguments: Dictionary containing:
            - name: Name to greet
            - language: Language code for greeting (optional)
    
    Returns:
        Dictionary with greeting message and metadata
    """
    logger.info("hello_world tool called", arguments=arguments)
    
    try:
        # Validate input
        validated = validate_input(HelloWorldInput, arguments)
        
        # Get greeting in specified language
        greeting = GREETINGS.get(validated.language, GREETINGS["en"])
        
        # Generate response
        message = f"{greeting}, {validated.name}!"
        
        logger.info(
            "hello_world completed successfully",
            name=validated.name,
            language=validated.language,
        )
        
        return {
            "success": True,
            "message": message,
            "language": validated.language,
            "supported_languages": list(GREETINGS.keys()),
        }
        
    except ValueError as e:
        logger.error("Input validation failed", error=str(e))
        return {
            "success": False,
            "error": str(e),
            "error_type": "validation_error",
        }
    except Exception as e:
        logger.exception("Unexpected error in hello_world")
        return {
            "success": False,
            "error": f"Internal error: {str(e)}",
            "error_type": "internal_error",
        }


def get_tool_definition() -> Dict[str, Any]:
    """Return the MCP tool definition for hello_world."""
    return {
        "name": "hello_world",
        "description": "A simple greeting tool that says hello in different languages",
        "inputSchema": {
            "type": "object",
            "properties": {
                "name": {
                    "type": "string",
                    "description": "Name to greet",
                    "minLength": 1,
                    "maxLength": 100,
                },
                "language": {
                    "type": "string",
                    "description": "Language code (en, es, fr, de, ja)",
                    "enum": ["en", "es", "fr", "de", "ja"],
                    "default": "en",
                },
            },
            "required": ["name"],
        },
    }
EOF
```

### Step 4: Create Kubernetes tools

```python
cat > src/tools/k8s.py << 'EOF'
"""Kubernetes MCP tools implementation."""

from typing import Dict, Any, Optional
from kubernetes import client, config
from kubernetes.client.rest import ApiException

from ..utils.logging import get_logger
from ..utils.validation import ListPodsInput, validate_input

logger = get_logger(__name__)


class KubernetesClient:
    """Singleton Kubernetes client manager."""
    
    _instance: Optional["KubernetesClient"] = None
    _v1_api: Optional[client.CoreV1Api] = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    def get_api(self) -> client.CoreV1Api:
        """Get or create CoreV1Api client."""
        if self._v1_api is None:
            try:
                config.load_incluster_config()
                logger.info("Loaded in-cluster Kubernetes configuration")
            except config.ConfigException:
                config.load_kube_config()
                logger.info("Loaded kubeconfig from file")
            
            self._v1_api = client.CoreV1Api()
        
        return self._v1_api


async def list_pods(arguments: Dict[str, Any]) -> Dict[str, Any]:
    """
    List pods in a Kubernetes namespace.
    
    Args:
        arguments: Dictionary containing:
            - namespace: Kubernetes namespace (optional, default: "default")
            - label_selector: Label selector for filtering (optional)
            - limit: Maximum number of pods to return (optional, default: 10)
    
    Returns:
        Dictionary with pod information
    """
    logger.info("list_pods tool called", arguments=arguments)
    
    try:
        # Validate input
        validated = validate_input(ListPodsInput, arguments)
        
        # Get Kubernetes API client
        k8s_client = KubernetesClient()
        v1 = k8s_client.get_api()
        
        # List pods
        pods = v1.list_namespaced_pod(
            namespace=validated.namespace,
            label_selector=validated.label_selector,
            limit=validated.limit,
        )
        
        # Format pod information
        pod_list = []
        for pod in pods.items:
            pod_info = {
                "name": pod.metadata.name,
                "namespace": pod.metadata.namespace,
                "status": pod.status.phase,
                "pod_ip": pod.status.pod_ip,
                "node": pod.spec.node_name,
                "containers": [
                    {
                        "name": container.name,
                        "image": container.image,
                        "ready": any(
                            cs.name == container.name and cs.ready
                            for cs in (pod.status.container_statuses or [])
                        ),
                    }
                    for container in pod.spec.containers
                ],
            }
            pod_list.append(pod_info)
        
        logger.info(
            "list_pods completed successfully",
            namespace=validated.namespace,
            pod_count=len(pod_list),
        )
        
        return {
            "success": True,
            "namespace": validated.namespace,
            "pod_count": len(pod_list),
            "pods": pod_list,
        }
        
    except ApiException as e:
        logger.error("Kubernetes API error", status=e.status, reason=e.reason)
        return {
            "success": False,
            "error": f"Kubernetes API error: {e.reason}",
            "error_type": "api_error",
            "status_code": e.status,
        }
    except ValueError as e:
        logger.error("Input validation failed", error=str(e))
        return {
            "success": False,
            "error": str(e),
            "error_type": "validation_error",
        }
    except Exception as e:
        logger.exception("Unexpected error in list_pods")
        return {
            "success": False,
            "error": f"Internal error: {str(e)}",
            "error_type": "internal_error",
        }


def get_tool_definition() -> Dict[str, Any]:
    """Return the MCP tool definition for list_pods."""
    return {
        "name": "list_pods",
        "description": "List pods in a Kubernetes namespace with optional filtering",
        "inputSchema": {
            "type": "object",
            "properties": {
                "namespace": {
                    "type": "string",
                    "description": "Kubernetes namespace",
                    "default": "default",
                },
                "label_selector": {
                    "type": "string",
                    "description": "Label selector for filtering pods (e.g., 'app=nginx')",
                },
                "limit": {
                    "type": "integer",
                    "description": "Maximum number of pods to return",
                    "default": 10,
                    "minimum": 1,
                    "maximum": 100,
                },
            },
        },
    }
EOF
```

### Step 5: Create main MCP server

```python
cat > src/server.py << 'EOF'
"""Main MCP server implementation."""

import asyncio
import sys
from typing import Any, Dict, List

from mcp.server import Server
from mcp.server.stdio import stdio_server

from .utils.logging import configure_logging, get_logger
from .tools import hello, k8s

# Configure logging
configure_logging()
logger = get_logger(__name__)


class MCPHelloServer:
    """MCP Server for Hello World and Kubernetes operations."""
    
    def __init__(self):
        self.server = Server("mcp-hello-server")
        self._register_tools()
    
    def _register_tools(self):
        """Register all available tools."""
        # Register hello_world tool
        @self.server.list_tools()
        async def list_tools() -> List[Dict[str, Any]]:
            return [
                hello.get_tool_definition(),
                k8s.get_tool_definition(),
            ]
        
        # Register call_tool handler
        @self.server.call_tool()
        async def call_tool(name: str, arguments: Dict[str, Any]) -> Any:
            logger.info("Tool called", tool_name=name, arguments=arguments)
            
            if name == "hello_world":
                return await hello.hello_world(arguments)
            elif name == "list_pods":
                return await k8s.list_pods(arguments)
            else:
                logger.error("Unknown tool requested", tool_name=name)
                return {
                    "success": False,
                    "error": f"Unknown tool: {name}",
                    "error_type": "unknown_tool",
                }
    
    async def run(self):
        """Run the MCP server."""
        logger.info("Starting MCP Hello Server")
        
        async with stdio_server() as (read_stream, write_stream):
            await self.server.run(
                read_stream,
                write_stream,
                self.server.create_initialization_options(),
            )


def main():
    """Main entry point."""
    try:
        server = MCPHelloServer()
        asyncio.run(server.run())
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
        sys.exit(0)
    except Exception as e:
        logger.exception("Fatal error in MCP server")
        sys.exit(1)


if __name__ == "__main__":
    main()
EOF
```

## Part 3: Write Tests (30 minutes)

### Step 1: Create test for hello_world tool

```python
cat > tests/test_hello.py << 'EOF'
"""Tests for hello_world tool."""

import pytest
from src.tools.hello import hello_world, get_tool_definition


@pytest.mark.asyncio
async def test_hello_world_default_language():
    """Test hello_world with default language."""
    result = await hello_world({"name": "Alice"})
    
    assert result["success"] is True
    assert result["message"] == "Hello, Alice!"
    assert result["language"] == "en"


@pytest.mark.asyncio
async def test_hello_world_spanish():
    """Test hello_world with Spanish language."""
    result = await hello_world({"name": "Bob", "language": "es"})
    
    assert result["success"] is True
    assert result["message"] == "Hola, Bob!"
    assert result["language"] == "es"


@pytest.mark.asyncio
async def test_hello_world_invalid_input():
    """Test hello_world with invalid input."""
    result = await hello_world({"language": "en"})  # Missing name
    
    assert result["success"] is False
    assert "error" in result
    assert result["error_type"] == "validation_error"


@pytest.mark.asyncio
async def test_hello_world_empty_name():
    """Test hello_world with empty name."""
    result = await hello_world({"name": ""})
    
    assert result["success"] is False
    assert result["error_type"] == "validation_error"


def test_get_tool_definition():
    """Test tool definition structure."""
    definition = get_tool_definition()
    
    assert definition["name"] == "hello_world"
    assert "description" in definition
    assert "inputSchema" in definition
    assert "properties" in definition["inputSchema"]
    assert "name" in definition["inputSchema"]["properties"]
EOF
```

### Step 2: Run tests

```bash
# Run all tests
pytest tests/ -v

# Run with coverage
pytest tests/ --cov=src --cov-report=html

# View coverage report
open htmlcov/index.html  # macOS
# or
xdg-open htmlcov/index.html  # Linux
```

## Part 4: Create Docker Container (30 minutes)

### Step 1: Create Dockerfile

```dockerfile
cat > Dockerfile << 'EOF'
# Multi-stage build for MCP server
FROM python:3.11-slim as builder

# Set working directory
WORKDIR /app

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --user -r requirements.txt

# Production stage
FROM python:3.11-slim

# Create non-root user
RUN useradd -m -u 1000 mcp && \
    mkdir -p /app && \
    chown -R mcp:mcp /app

# Set working directory
WORKDIR /app

# Copy Python dependencies from builder
COPY --from=builder /root/.local /home/mcp/.local

# Copy application code
COPY --chown=mcp:mcp src/ ./src/

# Switch to non-root user
USER mcp

# Set Python path
ENV PATH=/home/mcp/.local/bin:$PATH
ENV PYTHONPATH=/app

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import sys; sys.exit(0)"

# Run server
CMD ["python", "-m", "src.server"]
EOF
```

### Step 2: Create .dockerignore

```bash
cat > .dockerignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
env/
ENV/

# Testing
.pytest_cache/
.coverage
htmlcov/
*.cover

# IDE
.vscode/
.idea/
*.swp
*.swo

# Git
.git/
.gitignore

# Documentation
README.md
docs/

# CI/CD
.github/
EOF
```

### Step 3: Build Docker image

```bash
# Build image
docker build -t mcp-hello-server:v0.1.0 .

# Verify image
docker images | grep mcp-hello-server

# Inspect image
docker inspect mcp-hello-server:v0.1.0
```

## Part 5: Local Testing and Deployment (45 minutes)

### Step 1: Create development run script

```bash
cat > scripts/run-dev.sh << 'EOF'
#!/bin/bash

set -e

echo "Starting MCP Hello Server in development mode..."

# Activate virtual environment
source venv/bin/activate

# Set development environment variables
export LOG_LEVEL=DEBUG
export PYTHONPATH=$(pwd)

# Run server
python -m src.server
EOF

chmod +x scripts/run-dev.sh
```

### Step 2: Create Kubernetes deployment manifests

```bash
mkdir -p k8s

cat > k8s/deployment.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: mcp-hello-server-config
  namespace: default
data:
  LOG_LEVEL: "INFO"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mcp-hello-server
  namespace: default
  labels:
    app: mcp-hello-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mcp-hello-server
  template:
    metadata:
      labels:
        app: mcp-hello-server
    spec:
      serviceAccountName: mcp-server
      containers:
        - name: mcp-server
          image: mcp-hello-server:v0.1.0
          imagePullPolicy: Never
          envFrom:
            - configMapRef:
                name: mcp-hello-server-config
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "200m"
          livenessProbe:
            exec:
              command:
                - python
                - -c
                - "import sys; sys.exit(0)"
            initialDelaySeconds: 10
            periodSeconds: 30
          readinessProbe:
            exec:
              command:
                - python
                - -c
                - "import sys; sys.exit(0)"
            initialDelaySeconds: 5
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: mcp-hello-server
  namespace: default
spec:
  selector:
    app: mcp-hello-server
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
EOF
```

### Step 3: Deploy to kind cluster

```bash
# Load image into kind cluster
kind load docker-image mcp-hello-server:v0.1.0 --name mcp-dev-cluster

# Apply deployment
kubectl apply -f k8s/deployment.yaml

# Wait for deployment
kubectl wait --for=condition=available --timeout=60s deployment/mcp-hello-server

# Check status
kubectl get pods -l app=mcp-hello-server
kubectl logs -l app=mcp-hello-server
```

### Step 4: Test the deployed server

```bash
# Get pod name
POD_NAME=$(kubectl get pods -l app=mcp-hello-server -o jsonpath='{.items[0].metadata.name}')

# Execute hello_world tool
kubectl exec -it $POD_NAME -- python -c "
import asyncio
from src.tools.hello import hello_world

async def test():
    result = await hello_world({'name': 'Kubernetes', 'language': 'en'})
    print(result)

asyncio.run(test())
"

# Execute list_pods tool
kubectl exec -it $POD_NAME -- python -c "
import asyncio
from src.tools.k8s import list_pods

async def test():
    result = await list_pods({'namespace': 'default', 'limit': 5})
    print(result)

asyncio.run(test())
"
```

## Troubleshooting

### Import errors

**Issue**: Module not found errors

**Solution**:
```bash
# Ensure virtual environment is activated
source venv/bin/activate

# Reinstall dependencies
pip install -r requirements.txt

# Set PYTHONPATH
export PYTHONPATH=$(pwd)
```

### Kubernetes connection errors

**Issue**: Cannot connect to Kubernetes API

**Solution**:
```bash
# Verify cluster is running
kubectl cluster-info

# Check service account permissions
kubectl auth can-i get pods --as=system:serviceaccount:default:mcp-server

# View pod logs
kubectl logs -l app=mcp-hello-server
```

### Docker build errors

**Issue**: Image build fails

**Solution**:
```bash
# Clean Docker cache
docker system prune -a

# Build with no cache
docker build --no-cache -t mcp-hello-server:v0.1.0 .
```

## Deliverables

By the end of this lab, you should have:

- ✅ Complete MCP server project structure
- ✅ Working hello_world tool with multiple languages
- ✅ Working list_pods tool for Kubernetes
- ✅ Comprehensive unit tests
- ✅ Docker container image built
- ✅ Server deployed to kind cluster
- ✅ Successful tool execution tests

## Next Steps

1. Add more Kubernetes tools (get pod logs, describe pod)
2. Implement additional input validation
3. Add more comprehensive error handling
4. Proceed to [Lab 3: Foundational Metrics Collection](../lab-03-metrics-collection/README.md)

## Reference

```bash
# Quick commands
source venv/bin/activate
python -m src.server                    # Run server locally
pytest tests/ -v                        # Run tests
docker build -t mcp-hello-server:v0.1.0 .  # Build image
kubectl apply -f k8s/deployment.yaml    # Deploy to K8s
kubectl logs -l app=mcp-hello-server -f  # View logs
```

---

**Estimated Completion Time**: 3 hours  
**Difficulty**: Intermediate
