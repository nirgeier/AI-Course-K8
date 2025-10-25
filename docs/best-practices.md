# Best Practices for MCP Server Development

## Overview

This document outlines best practices for developing, deploying, and maintaining MCP servers in production environments.

## Code Organization

### Project Structure

```
mcp-server/
├── README.md                 # Project documentation
├── pyproject.toml           # Python project metadata
├── requirements.txt         # Dependencies
├── .gitignore              # Git ignore rules
├── .dockerignore           # Docker ignore rules
├── Dockerfile              # Container definition
├── Makefile                # Common commands
├── src/
│   ├── __init__.py
│   ├── server.py           # Main server
│   ├── config.py           # Configuration management
│   ├── tools/              # MCP tools
│   │   ├── __init__.py
│   │   ├── base.py         # Base tool class
│   │   └── *.py            # Individual tools
│   ├── engines/            # Business logic
│   │   ├── __init__.py
│   │   └── *.py
│   └── utils/              # Utilities
│       ├── __init__.py
│       ├── logging.py
│       ├── metrics.py
│       └── validation.py
├── tests/
│   ├── __init__.py
│   ├── conftest.py         # Pytest fixtures
│   ├── unit/               # Unit tests
│   ├── integration/        # Integration tests
│   └── e2e/                # End-to-end tests
├── k8s/                    # Kubernetes manifests
│   ├── base/               # Base resources
│   ├── overlays/           # Kustomize overlays
│   └── helm/               # Helm chart
├── docs/                   # Documentation
│   ├── architecture.md
│   ├── api.md
│   └── deployment.md
└── scripts/                # Utility scripts
    ├── build.sh
    ├── deploy.sh
    └── test.sh
```

### Module Organization

```python
# Good: Organized by feature
src/
  tools/
    diagnostic/
      __init__.py
      pod_checker.py
      log_analyzer.py
    healing/
      __init__.py
      restart.py
      scale.py

# Avoid: Flat structure
src/
  tools/
    pod_checker.py
    log_analyzer.py
    restart.py
    scale.py
    # ... 20 more files
```

## Tool Development

### Tool Definition Pattern

```python
# src/tools/base.py
from abc import ABC, abstractmethod
from typing import Dict, Any
from pydantic import BaseModel

class ToolInput(BaseModel):
    """Base class for tool inputs."""
    class Config:
        extra = "forbid"

class Tool(ABC):
    """Base class for all MCP tools."""
    
    @property
    @abstractmethod
    def name(self) -> str:
        """Tool name."""
        pass
    
    @property
    @abstractmethod
    def description(self) -> str:
        """Tool description."""
        pass
    
    @property
    @abstractmethod
    def input_schema(self) -> Dict[str, Any]:
        """JSON schema for inputs."""
        pass
    
    @abstractmethod
    async def execute(self, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Execute the tool."""
        pass
    
    def to_mcp_definition(self) -> Dict[str, Any]:
        """Convert to MCP tool definition."""
        return {
            "name": self.name,
            "description": self.description,
            "inputSchema": self.input_schema,
        }
```

### Example Tool Implementation

```python
# src/tools/diagnostic/pod_checker.py
from typing import Dict, Any
from pydantic import Field
from ..base import Tool, ToolInput
from ...utils.logging import get_logger
from ...utils.k8s import KubernetesClient

logger = get_logger(__name__)

class PodCheckerInput(ToolInput):
    """Input for pod checker tool."""
    namespace: str = Field(..., description="Kubernetes namespace")
    pod_name: str = Field(..., description="Pod name")
    check_logs: bool = Field(True, description="Check pod logs")

class PodChecker(Tool):
    """Check pod health and diagnose issues."""
    
    def __init__(self, k8s_client: KubernetesClient):
        self._k8s = k8s_client
    
    @property
    def name(self) -> str:
        return "check_pod_health"
    
    @property
    def description(self) -> str:
        return "Check pod health and diagnose common issues"
    
    @property
    def input_schema(self) -> Dict[str, Any]:
        return PodCheckerInput.schema()
    
    async def execute(self, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Execute pod health check."""
        logger.info("Checking pod health", arguments=arguments)
        
        try:
            # Validate input
            validated = PodCheckerInput(**arguments)
            
            # Get pod information
            pod = await self._k8s.get_pod(
                validated.namespace,
                validated.pod_name
            )
            
            # Analyze pod health
            issues = await self._analyze_pod(pod)
            
            # Get logs if requested
            logs = None
            if validated.check_logs and issues:
                logs = await self._k8s.get_pod_logs(
                    validated.namespace,
                    validated.pod_name,
                    tail_lines=100
                )
            
            return {
                "success": True,
                "pod_name": validated.pod_name,
                "namespace": validated.namespace,
                "status": pod.status.phase,
                "issues": issues,
                "logs": logs,
            }
            
        except Exception as e:
            logger.exception("Failed to check pod health")
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__,
            }
    
    async def _analyze_pod(self, pod) -> list:
        """Analyze pod for issues."""
        issues = []
        
        # Check container statuses
        for status in pod.status.container_statuses or []:
            if status.state.waiting:
                issues.append({
                    "severity": "high",
                    "type": status.state.waiting.reason,
                    "container": status.name,
                    "message": status.state.waiting.message,
                })
            elif status.restart_count > 3:
                issues.append({
                    "severity": "medium",
                    "type": "frequent_restarts",
                    "container": status.name,
                    "restart_count": status.restart_count,
                })
        
        return issues
```

## Configuration Management

### Use Environment Variables

```python
# src/config.py
from pydantic import BaseSettings, Field

class Settings(BaseSettings):
    """Application settings."""
    
    # Logging
    log_level: str = Field("INFO", env="LOG_LEVEL")
    log_format: str = Field("json", env="LOG_FORMAT")
    
    # Kubernetes
    k8s_namespace: str = Field("default", env="K8S_NAMESPACE")
    k8s_in_cluster: bool = Field(True, env="K8S_IN_CLUSTER")
    
    # Metrics
    metrics_port: int = Field(9090, env="METRICS_PORT")
    metrics_path: str = Field("/metrics", env="METRICS_PATH")
    
    # Rate limiting
    rate_limit_enabled: bool = Field(True, env="RATE_LIMIT_ENABLED")
    rate_limit_requests: int = Field(100, env="RATE_LIMIT_REQUESTS")
    rate_limit_window: int = Field(60, env="RATE_LIMIT_WINDOW")
    
    class Config:
        env_file = ".env"
        case_sensitive = False

# Global settings instance
settings = Settings()
```

### Configuration in Kubernetes

```yaml
# k8s/base/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mcp-server-config
data:
  LOG_LEVEL: "INFO"
  LOG_FORMAT: "json"
  K8S_NAMESPACE: "default"
  METRICS_PORT: "9090"
  RATE_LIMIT_REQUESTS: "100"
  RATE_LIMIT_WINDOW: "60"

---
# k8s/overlays/production/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mcp-server-config
data:
  LOG_LEVEL: "WARNING"
  RATE_LIMIT_REQUESTS: "1000"
```

## Error Handling

### Comprehensive Error Handling

```python
from typing import Dict, Any
from enum import Enum

class ErrorType(str, Enum):
    """Standard error types."""
    VALIDATION_ERROR = "validation_error"
    NOT_FOUND = "not_found"
    PERMISSION_DENIED = "permission_denied"
    TIMEOUT = "timeout"
    API_ERROR = "api_error"
    INTERNAL_ERROR = "internal_error"

class ToolError(Exception):
    """Base exception for tool errors."""
    
    def __init__(
        self,
        message: str,
        error_type: ErrorType,
        details: Dict[str, Any] = None
    ):
        self.message = message
        self.error_type = error_type
        self.details = details or {}
        super().__init__(message)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "success": False,
            "error": self.message,
            "error_type": self.error_type.value,
            "details": self.details,
        }

# Usage in tools
async def execute(self, arguments: Dict[str, Any]) -> Dict[str, Any]:
    try:
        # Validate input
        validated = MyInput(**arguments)
    except ValidationError as e:
        raise ToolError(
            "Invalid input",
            ErrorType.VALIDATION_ERROR,
            {"validation_errors": e.errors()}
        )
    
    try:
        # Execute tool logic
        result = await self._do_something(validated)
        return {"success": True, "result": result}
    except ApiException as e:
        if e.status == 404:
            raise ToolError(
                f"Pod {validated.pod_name} not found",
                ErrorType.NOT_FOUND,
                {"namespace": validated.namespace}
            )
        elif e.status == 403:
            raise ToolError(
                "Permission denied",
                ErrorType.PERMISSION_DENIED,
                {"required_permission": "get pods"}
            )
        else:
            raise ToolError(
                f"Kubernetes API error: {e.reason}",
                ErrorType.API_ERROR,
                {"status": e.status}
            )
    except Exception as e:
        logger.exception("Unexpected error")
        raise ToolError(
            "Internal error occurred",
            ErrorType.INTERNAL_ERROR,
            {"exception_type": type(e).__name__}
        )
```

## Logging

### Structured Logging

```python
# src/utils/logging.py
import structlog
import logging
import sys

def configure_logging(
    log_level: str = "INFO",
    log_format: str = "json"
):
    """Configure structured logging."""
    
    # Set up stdlib logging
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=getattr(logging, log_level.upper()),
    )
    
    # Configure structlog processors
    processors = [
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.dev.set_exc_info,
    ]
    
    # Add appropriate renderer
    if log_format == "json":
        processors.append(structlog.processors.JSONRenderer())
    else:
        processors.append(structlog.dev.ConsoleRenderer())
    
    structlog.configure(
        processors=processors,
        wrapper_class=structlog.make_filtering_bound_logger(
            getattr(logging, log_level.upper())
        ),
        context_class=dict,
        logger_factory=structlog.PrintLoggerFactory(),
        cache_logger_on_first_use=True,
    )

# Usage
from utils.logging import get_logger

logger = get_logger(__name__)

logger.info(
    "Tool executed successfully",
    tool_name="check_pod",
    namespace="default",
    pod_name="my-pod",
    duration_ms=125
)

logger.error(
    "Tool execution failed",
    tool_name="check_pod",
    error="Pod not found",
    namespace="default",
    pod_name="missing-pod"
)
```

### Correlation IDs

```python
import uuid
import structlog
from contextvars import ContextVar

# Context variable for request ID
request_id_var: ContextVar[str] = ContextVar("request_id", default="")

def get_request_id() -> str:
    """Get or create request ID."""
    request_id = request_id_var.get()
    if not request_id:
        request_id = str(uuid.uuid4())
        request_id_var.set(request_id)
    return request_id

# Middleware to set request ID
async def handle_request(request):
    request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
    request_id_var.set(request_id)
    
    logger = structlog.get_logger()
    logger = logger.bind(request_id=request_id)
    
    # Process request
    response = await process(request)
    
    # Add request ID to response
    response.headers["X-Request-ID"] = request_id
    return response
```

## Testing

### Test Structure

```python
# tests/conftest.py
import pytest
from kubernetes import client
from unittest.mock import MagicMock

@pytest.fixture
def mock_k8s_client():
    """Mock Kubernetes client."""
    mock = MagicMock()
    mock.list_namespaced_pod.return_value = client.V1PodList(items=[])
    return mock

@pytest.fixture
async def pod_checker(mock_k8s_client):
    """Create pod checker tool with mocked client."""
    from src.tools.diagnostic.pod_checker import PodChecker
    return PodChecker(mock_k8s_client)

# tests/unit/test_pod_checker.py
import pytest

@pytest.mark.asyncio
async def test_pod_checker_success(pod_checker, mock_k8s_client):
    """Test successful pod check."""
    # Setup mock
    mock_pod = create_mock_pod("test-pod", "Running")
    mock_k8s_client.get_pod.return_value = mock_pod
    
    # Execute
    result = await pod_checker.execute({
        "namespace": "default",
        "pod_name": "test-pod",
    })
    
    # Assert
    assert result["success"] is True
    assert result["pod_name"] == "test-pod"
    assert result["status"] == "Running"

@pytest.mark.asyncio
async def test_pod_checker_validation_error(pod_checker):
    """Test input validation."""
    result = await pod_checker.execute({})  # Missing required fields
    
    assert result["success"] is False
    assert result["error_type"] == "validation_error"
```

### Integration Tests

```python
# tests/integration/test_pod_checker_integration.py
import pytest
from kubernetes import client, config

@pytest.mark.integration
@pytest.mark.asyncio
async def test_pod_checker_real_cluster():
    """Test with real Kubernetes cluster."""
    # Load kube config
    config.load_kube_config()
    
    # Create test pod
    v1 = client.CoreV1Api()
    pod = client.V1Pod(
        metadata=client.V1ObjectMeta(name="test-pod"),
        spec=client.V1PodSpec(
            containers=[
                client.V1Container(
                    name="nginx",
                    image="nginx:latest"
                )
            ]
        )
    )
    v1.create_namespaced_pod("default", pod)
    
    try:
        # Test pod checker
        from src.tools.diagnostic.pod_checker import PodChecker
        from src.utils.k8s import KubernetesClient
        
        k8s_client = KubernetesClient()
        checker = PodChecker(k8s_client)
        
        result = await checker.execute({
            "namespace": "default",
            "pod_name": "test-pod",
        })
        
        assert result["success"] is True
        
    finally:
        # Cleanup
        v1.delete_namespaced_pod("test-pod", "default")
```

## Metrics

### Prometheus Metrics

```python
# src/utils/metrics.py
from prometheus_client import Counter, Histogram, Gauge, Info
from functools import wraps
import time

# Define metrics
tool_calls_total = Counter(
    "mcp_tool_calls_total",
    "Total number of tool calls",
    ["tool_name", "status"]
)

tool_duration_seconds = Histogram(
    "mcp_tool_duration_seconds",
    "Time spent executing tools",
    ["tool_name"],
    buckets=[0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0]
)

tool_errors_total = Counter(
    "mcp_tool_errors_total",
    "Total number of tool errors",
    ["tool_name", "error_type"]
)

mcp_server_info = Info(
    "mcp_server",
    "MCP server information"
)

# Set server info
mcp_server_info.info({
    "version": "1.0.0",
    "python_version": "3.11",
})

# Decorator for automatic metrics
def track_metrics(func):
    """Decorator to track tool execution metrics."""
    
    @wraps(func)
    async def wrapper(*args, **kwargs):
        tool_name = func.__name__
        start_time = time.time()
        
        try:
            result = await func(*args, **kwargs)
            status = "success" if result.get("success") else "failure"
            tool_calls_total.labels(tool_name=tool_name, status=status).inc()
            
            if not result.get("success"):
                error_type = result.get("error_type", "unknown")
                tool_errors_total.labels(
                    tool_name=tool_name,
                    error_type=error_type
                ).inc()
            
            return result
            
        finally:
            duration = time.time() - start_time
            tool_duration_seconds.labels(tool_name=tool_name).observe(duration)
    
    return wrapper

# Usage
@track_metrics
async def check_pod_health(arguments):
    # ... implementation
    pass
```

## Security

### RBAC Best Practices

```yaml
# Principle of Least Privilege
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: mcp-server-role
  namespace: default
rules:
  # Only what's needed
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]  # Not "delete" unless necessary
  
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get"]  # Read-only access to logs

---
# For cluster-wide read operations
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: mcp-server-reader
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "endpoints"]
    verbs: ["get", "list", "watch"]
  
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list"]
```

### Secret Management

```python
# Don't do this
api_key = "sk-1234567890abcdef"  # Hardcoded secret

# Do this
import os

api_key = os.getenv("API_KEY")
if not api_key:
    raise ValueError("API_KEY environment variable not set")
```

```yaml
# Use Kubernetes secrets
apiVersion: v1
kind: Secret
metadata:
  name: mcp-server-secrets
type: Opaque
data:
  api-key: c2stMTIzNDU2Nzg5MGFiY2RlZg==  # base64 encoded

---
# Reference in deployment
spec:
  containers:
    - name: mcp-server
      envFrom:
        - secretRef:
            name: mcp-server-secrets
```

### Input Validation

```python
# Always validate and sanitize inputs
from pydantic import validator, Field

class ToolInput(BaseModel):
    namespace: str = Field(..., regex=r"^[a-z0-9-]+$")
    pod_name: str = Field(..., regex=r"^[a-z0-9-]+$")
    
    @validator("namespace")
    def validate_namespace(cls, v):
        if v.startswith("kube-"):
            raise ValueError("Cannot access system namespaces")
        return v
```

## Performance

### Async Best Practices

```python
# Good: Concurrent execution
async def get_all_pod_info(namespace: str, pod_names: list[str]):
    tasks = [
        get_pod_info(namespace, name)
        for name in pod_names
    ]
    return await asyncio.gather(*tasks)

# Avoid: Sequential execution
async def get_all_pod_info(namespace: str, pod_names: list[str]):
    results = []
    for name in pod_names:
        result = await get_pod_info(namespace, name)
        results.append(result)
    return results
```

### Caching

```python
from functools import lru_cache
from datetime import datetime, timedelta

class CachedKubernetesClient:
    def __init__(self):
        self._cache = {}
        self._cache_ttl = timedelta(seconds=30)
    
    async def list_pods(self, namespace: str):
        cache_key = f"pods:{namespace}"
        
        # Check cache
        if cache_key in self._cache:
            cached_value, cached_time = self._cache[cache_key]
            if datetime.now() - cached_time < self._cache_ttl:
                return cached_value
        
        # Fetch and cache
        pods = await self._fetch_pods(namespace)
        self._cache[cache_key] = (pods, datetime.now())
        return pods
```

## Documentation

### Code Documentation

```python
def diagnose_pod(
    namespace: str,
    pod_name: str,
    check_logs: bool = True
) -> Dict[str, Any]:
    """
    Diagnose issues with a Kubernetes pod.
    
    This function performs a comprehensive health check on a pod,
    including status verification, event analysis, and optional
    log examination.
    
    Args:
        namespace: Kubernetes namespace containing the pod
        pod_name: Name of the pod to diagnose
        check_logs: Whether to analyze pod logs for errors
    
    Returns:
        Dictionary containing:
            - success: Whether the operation succeeded
            - issues: List of detected issues
            - recommendations: Suggested remediation steps
    
    Raises:
        ToolError: If pod cannot be accessed or analyzed
    
    Example:
        >>> result = diagnose_pod("default", "my-pod")
        >>> if result["issues"]:
        ...     print(f"Found {len(result['issues'])} issues")
    """
    pass
```

### API Documentation

Generate OpenAPI/Swagger documentation for your MCP server's tools.

## Deployment

### Health Checks

```python
# Add health check endpoint
from fastapi import FastAPI

app = FastAPI()

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
    }

@app.get("/ready")
async def readiness_check():
    """Readiness check endpoint."""
    # Check dependencies
    try:
        await check_kubernetes_connection()
        return {"status": "ready"}
    except Exception:
        return {"status": "not ready"}, 503
```

```yaml
# In Kubernetes deployment
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 30

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
```

### Resource Management

```yaml
# Set appropriate resource requests and limits
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"

# Configure autoscaling
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: mcp-server-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: mcp-server
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

## Monitoring

### Key Metrics to Track

1. **Availability**: Uptime, error rates
2. **Performance**: Latency, throughput
3. **Saturation**: Resource usage
4. **Errors**: Error rates by type

### Alerting Rules

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: mcp-server-alerts
spec:
  groups:
    - name: mcp-server
      interval: 30s
      rules:
        - alert: HighErrorRate
          expr: |
            rate(mcp_tool_errors_total[5m]) > 0.1
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High tool error rate"
        
        - alert: HighLatency
          expr: |
            histogram_quantile(0.95,
              rate(mcp_tool_duration_seconds_bucket[5m])
            ) > 5
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "High tool execution latency"
```

---

## Summary Checklist

✅ **Code Organization**
- [ ] Logical project structure
- [ ] Clear module boundaries
- [ ] Reusable components

✅ **Tool Development**
- [ ] Input validation
- [ ] Comprehensive error handling
- [ ] Proper logging
- [ ] Metrics tracking

✅ **Configuration**
- [ ] Environment-based config
- [ ] Secure secret management
- [ ] Configuration validation

✅ **Testing**
- [ ] Unit tests
- [ ] Integration tests
- [ ] >80% code coverage

✅ **Security**
- [ ] Least privilege RBAC
- [ ] Input sanitization
- [ ] Secure dependencies

✅ **Performance**
- [ ] Async operations
- [ ] Appropriate caching
- [ ] Resource optimization

✅ **Documentation**
- [ ] Code comments
- [ ] API documentation
- [ ] Deployment guide

✅ **Deployment**
- [ ] Health checks
- [ ] Resource limits
- [ ] Autoscaling

✅ **Monitoring**
- [ ] Metrics exposed
- [ ] Alerts configured
- [ ] Dashboards created
