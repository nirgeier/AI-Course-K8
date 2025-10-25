# Lab 3: Foundational Metrics Collection Implementation

**Duration**: 2.5 hours  
**Difficulty**: Intermediate

## Overview

In this lab, you will implement comprehensive metrics collection for your MCP server using Prometheus and Grafana. You'll design custom metrics, create exporters, configure scraping, and build visualization dashboards.

## Learning Objectives

After completing this lab, you will be able to:

- Design custom Prometheus metrics for MCP servers
- Implement metric exporters with proper labels and cardinality
- Configure Prometheus scraping and service discovery
- Create Grafana dashboards for MCP server monitoring
- Set up alerting rules for operational metrics
- Implement metric aggregation and retention policies

## Prerequisites

- Completed Lab 1 (Environment Setup)
- Completed Lab 2 (First MCP Server)
- Understanding of Prometheus metric types
- Basic Grafana knowledge

## Architecture

```
┌─────────────────────────────────────────────────┐
│         MCP Server with Metrics                  │
│  ┌────────────────────────────────────────┐     │
│  │  Application Code                      │     │
│  │  ┌──────────┐  ┌──────────┐           │     │
│  │  │  Tools   │  │ Business │           │     │
│  │  │          │  │  Logic   │           │     │
│  │  └─────┬────┘  └────┬─────┘           │     │
│  │        │            │                  │     │
│  │  ┌─────▼────────────▼─────┐           │     │
│  │  │   Metrics Registry      │           │     │
│  │  │  - Counters             │           │     │
│  │  │  - Gauges               │           │     │
│  │  │  - Histograms           │           │     │
│  │  └─────────────┬───────────┘           │     │
│  └────────────────┼───────────────────────┘     │
│                   │                              │
│  ┌────────────────▼───────────────────────┐     │
│  │   Metrics HTTP Endpoint (/metrics)     │     │
│  └────────────────┬───────────────────────┘     │
└───────────────────┼──────────────────────────────┘
                    │
                    │ HTTP Scrape (every 15s)
                    │
┌───────────────────▼──────────────────────────────┐
│              Prometheus                          │
│  - Scrapes metrics                               │
│  - Stores time series data                       │
│  - Evaluates alert rules                         │
└───────────────────┬──────────────────────────────┘
                    │
                    │ PromQL Queries
                    │
┌───────────────────▼──────────────────────────────┐
│              Grafana                             │
│  - Visualizes metrics                            │
│  - Creates dashboards                            │
│  - Sends alerts                                  │
└──────────────────────────────────────────────────┘
```

## Part 1: Design Metrics (30 minutes)

### Step 1: Identify Key Metrics

For an MCP server, we need to track:

**Request Metrics**:
- Total tool calls
- Tool call duration
- Tool call errors
- Active requests

**System Metrics**:
- CPU usage
- Memory usage
- Open connections
- Queue depth

**Business Metrics**:
- Kubernetes operations performed
- Pods diagnosed
- Issues detected
- Remediation actions taken

### Step 2: Choose Metric Types

```python
# Counter - Always increasing
tool_calls_total = Counter(
    'mcp_tool_calls_total',
    'Total number of tool calls',
    ['tool_name', 'status']  # Labels
)

# Gauge - Can go up or down
active_requests = Gauge(
    'mcp_active_requests',
    'Number of currently active requests',
    ['tool_name']
)

# Histogram - Distribution of values
tool_duration_seconds = Histogram(
    'mcp_tool_duration_seconds',
    'Time spent executing tools',
    ['tool_name'],
    buckets=[0.1, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0]
)

# Summary - Similar to histogram, calculates quantiles
response_size_bytes = Summary(
    'mcp_response_size_bytes',
    'Size of tool responses',
    ['tool_name']
)
```

### Step 3: Plan Label Strategy

**Good Labels** (low cardinality):
```python
['tool_name', 'status', 'namespace', 'cluster']
# ~10 tools × 2 statuses × 5 namespaces × 2 clusters = 200 series
```

**Bad Labels** (high cardinality):
```python
['pod_name', 'timestamp', 'user_id', 'request_id']
# Could create millions of time series!
```

## Part 2: Implement Metrics Collection (45 minutes)

### Step 1: Install Prometheus Client

```bash
cd ~/mcp-servers/mcp-hello-server
source venv/bin/activate

# Add to requirements.txt
echo "prometheus-client>=0.19.0" >> requirements.txt

pip install prometheus-client
```

### Step 2: Create Metrics Module

```bash
cat > src/utils/metrics.py << 'EOF'
"""Prometheus metrics for MCP server."""

from prometheus_client import Counter, Histogram, Gauge, Info, generate_latest
from prometheus_client import REGISTRY, CONTENT_TYPE_LATEST
from functools import wraps
import time
from typing import Callable, Any

# Define metrics
tool_calls_total = Counter(
    'mcp_tool_calls_total',
    'Total number of tool calls',
    ['tool_name', 'status']
)

tool_duration_seconds = Histogram(
    'mcp_tool_duration_seconds',
    'Time spent executing tools in seconds',
    ['tool_name'],
    buckets=[0.1, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0]
)

tool_errors_total = Counter(
    'mcp_tool_errors_total',
    'Total number of tool errors',
    ['tool_name', 'error_type']
)

active_requests = Gauge(
    'mcp_active_requests',
    'Number of currently active requests',
    ['tool_name']
)

kubernetes_operations_total = Counter(
    'mcp_kubernetes_operations_total',
    'Total Kubernetes API operations',
    ['operation', 'resource', 'status']
)

pods_diagnosed_total = Counter(
    'mcp_pods_diagnosed_total',
    'Total number of pods diagnosed',
    ['namespace', 'issue_type']
)

server_info = Info(
    'mcp_server',
    'MCP server information'
)

# Set server info
server_info.info({
    'version': '0.1.0',
    'python_version': '3.11',
    'server_name': 'mcp-hello-server'
})


def track_tool_metrics(func: Callable) -> Callable:
    """
    Decorator to automatically track metrics for tool execution.
    
    Usage:
        @track_tool_metrics
        async def my_tool(arguments):
            ...
    """
    @wraps(func)
    async def wrapper(*args, **kwargs) -> Any:
        tool_name = func.__name__
        
        # Track active requests
        active_requests.labels(tool_name=tool_name).inc()
        
        start_time = time.time()
        status = 'success'
        error_type = None
        
        try:
            result = await func(*args, **kwargs)
            
            # Determine status from result
            if isinstance(result, dict):
                status = 'success' if result.get('success', True) else 'error'
                error_type = result.get('error_type', 'unknown')
            
            return result
            
        except Exception as e:
            status = 'error'
            error_type = type(e).__name__
            raise
            
        finally:
            # Record duration
            duration = time.time() - start_time
            tool_duration_seconds.labels(tool_name=tool_name).observe(duration)
            
            # Record call count
            tool_calls_total.labels(tool_name=tool_name, status=status).inc()
            
            # Record errors
            if status == 'error' and error_type:
                tool_errors_total.labels(
                    tool_name=tool_name,
                    error_type=error_type
                ).inc()
            
            # Decrement active requests
            active_requests.labels(tool_name=tool_name).dec()
    
    return wrapper


def track_k8s_operation(operation: str, resource: str, status: str):
    """Track Kubernetes API operations."""
    kubernetes_operations_total.labels(
        operation=operation,
        resource=resource,
        status=status
    ).inc()


def track_pod_diagnosis(namespace: str, issue_type: str):
    """Track pod diagnosis operations."""
    pods_diagnosed_total.labels(
        namespace=namespace,
        issue_type=issue_type
    ).inc()


def get_metrics() -> tuple[bytes, str]:
    """
    Get current metrics in Prometheus format.
    
    Returns:
        Tuple of (metrics_data, content_type)
    """
    return generate_latest(REGISTRY), CONTENT_TYPE_LATEST
EOF
```

### Step 3: Add Metrics to Tools

Update `src/tools/hello.py`:

```python
cat > src/tools/hello.py << 'EOF'
"""Hello World MCP tool implementation."""

from typing import Dict, Any
from ..utils.logging import get_logger
from ..utils.validation import HelloWorldInput, validate_input
from ..utils.metrics import track_tool_metrics

logger = get_logger(__name__)

GREETINGS = {
    "en": "Hello",
    "es": "Hola",
    "fr": "Bonjour",
    "de": "Guten Tag",
    "ja": "こんにちは",
}


@track_tool_metrics
async def hello_world(arguments: Dict[str, Any]) -> Dict[str, Any]:
    """A simple greeting tool that demonstrates MCP tool implementation."""
    logger.info("hello_world tool called", arguments=arguments)
    
    try:
        validated = validate_input(HelloWorldInput, arguments)
        greeting = GREETINGS.get(validated.language, GREETINGS["en"])
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

### Step 4: Add Metrics HTTP Endpoint

Create a metrics server:

```python
cat > src/metrics_server.py << 'EOF'
"""HTTP server for Prometheus metrics."""

import asyncio
from aiohttp import web
from .utils.metrics import get_metrics
from .utils.logging import get_logger

logger = get_logger(__name__)


async def metrics_handler(request):
    """Handle /metrics requests."""
    metrics_data, content_type = get_metrics()
    return web.Response(body=metrics_data, content_type=content_type)


async def health_handler(request):
    """Handle /health requests."""
    return web.json_response({"status": "healthy"})


def create_app() -> web.Application:
    """Create aiohttp application."""
    app = web.Application()
    app.router.add_get('/metrics', metrics_handler)
    app.router.add_get('/health', health_handler)
    return app


async def run_metrics_server(host: str = '0.0.0.0', port: int = 9090):
    """Run the metrics server."""
    app = create_app()
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, host, port)
    await site.start()
    logger.info(f"Metrics server started on {host}:{port}")
    
    # Keep running
    try:
        await asyncio.Event().wait()
    finally:
        await runner.cleanup()


if __name__ == '__main__':
    asyncio.run(run_metrics_server())
EOF
```

Update `requirements.txt`:

```bash
echo "aiohttp>=3.9.0" >> requirements.txt
pip install aiohttp
```

### Step 5: Update Main Server

Modify `src/server.py` to run metrics server:

```python
# Add near the top
from .metrics_server import run_metrics_server

# In main():
async def main():
    # Start metrics server in background
    metrics_task = asyncio.create_task(run_metrics_server())
    
    try:
        server = MCPHelloServer()
        await server.run()
    finally:
        metrics_task.cancel()
```

## Part 3: Configure Prometheus Scraping (30 minutes)

### Step 1: Create ServiceMonitor

```bash
cat > k8s/servicemonitor.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: mcp-hello-server-metrics
  namespace: default
  labels:
    app: mcp-hello-server
spec:
  selector:
    app: mcp-hello-server
  ports:
    - name: metrics
      port: 9090
      targetPort: 9090
      protocol: TCP
  type: ClusterIP
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: mcp-hello-server
  namespace: default
  labels:
    app: mcp-hello-server
spec:
  selector:
    matchLabels:
      app: mcp-hello-server
  endpoints:
    - port: metrics
      interval: 15s
      path: /metrics
EOF
```

### Step 2: Update Deployment

Add metrics port to deployment:

```yaml
# Add to k8s/deployment.yaml under container ports
ports:
  - name: metrics
    containerPort: 9090
    protocol: TCP
```

### Step 3: Deploy and Verify

```bash
# Rebuild image
docker build -t mcp-hello-server:v0.2.0 .

# Load into kind
kind load docker-image mcp-hello-server:v0.2.0 --name mcp-dev-cluster

# Update deployment
kubectl set image deployment/mcp-hello-server mcp-server=mcp-hello-server:v0.2.0

# Apply ServiceMonitor
kubectl apply -f k8s/servicemonitor.yaml

# Wait for rollout
kubectl rollout status deployment/mcp-hello-server

# Check metrics endpoint
kubectl port-forward svc/mcp-hello-server-metrics 9090:9090 &
curl http://localhost:9090/metrics
```

You should see metrics output:

```
# HELP mcp_tool_calls_total Total number of tool calls
# TYPE mcp_tool_calls_total counter
mcp_tool_calls_total{status="success",tool_name="hello_world"} 5.0
...
```

### Step 4: Verify Prometheus Scraping

```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9091:9090

# Open in browser: http://localhost:9091
# Go to Status -> Targets
# Look for mcp-hello-server target
```

## Part 4: Create Grafana Dashboard (45 minutes)

### Step 1: Access Grafana

```bash
# Get Grafana password
kubectl get secret --namespace monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# Port-forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Open: http://localhost:3000
# Login: admin / <password from above>
```

### Step 2: Create Dashboard JSON

```bash
mkdir -p dashboards

cat > dashboards/mcp-server-dashboard.json << 'EOF'
{
  "dashboard": {
    "title": "MCP Server Metrics",
    "tags": ["mcp", "kubernetes"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Tool Call Rate",
        "type": "graph",
        "gridPos": {"x": 0, "y": 0, "w": 12, "h": 8},
        "targets": [
          {
            "expr": "rate(mcp_tool_calls_total[5m])",
            "legendFormat": "{{tool_name}} - {{status}}"
          }
        ]
      },
      {
        "id": 2,
        "title": "Active Requests",
        "type": "stat",
        "gridPos": {"x": 12, "y": 0, "w": 6, "h": 4},
        "targets": [
          {
            "expr": "sum(mcp_active_requests)"
          }
        ]
      },
      {
        "id": 3,
        "title": "Error Rate",
        "type": "stat",
        "gridPos": {"x": 18, "y": 0, "w": 6, "h": 4},
        "targets": [
          {
            "expr": "rate(mcp_tool_errors_total[5m])"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "thresholds": {
              "steps": [
                {"value": 0, "color": "green"},
                {"value": 0.1, "color": "yellow"},
                {"value": 1, "color": "red"}
              ]
            }
          }
        }
      },
      {
        "id": 4,
        "title": "Tool Duration (p95)",
        "type": "graph",
        "gridPos": {"x": 0, "y": 8, "w": 12, "h": 8},
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(mcp_tool_duration_seconds_bucket[5m]))",
            "legendFormat": "{{tool_name}} p95"
          }
        ]
      },
      {
        "id": 5,
        "title": "Tool Calls by Tool",
        "type": "piechart",
        "gridPos": {"x": 12, "y": 4, "w": 12, "h": 8},
        "targets": [
          {
            "expr": "sum by (tool_name) (mcp_tool_calls_total)",
            "legendFormat": "{{tool_name}}"
          }
        ]
      },
      {
        "id": 6,
        "title": "Kubernetes Operations",
        "type": "table",
        "gridPos": {"x": 0, "y": 16, "w": 24, "h": 8},
        "targets": [
          {
            "expr": "mcp_kubernetes_operations_total",
            "format": "table",
            "instant": true
          }
        ]
      }
    ],
    "refresh": "10s",
    "time": {
      "from": "now-1h",
      "to": "now"
    }
  }
}
EOF
```

### Step 3: Import Dashboard

1. In Grafana, click "+" → "Import"
2. Upload `dashboards/mcp-server-dashboard.json`
3. Select Prometheus data source
4. Click "Import"

### Step 4: Generate Test Traffic

```bash
# Get pod name
POD=$(kubectl get pod -l app=mcp-hello-server -o jsonpath='{.items[0].metadata.name}')

# Generate traffic
for i in {1..100}; do
  kubectl exec -it $POD -- python -c "
import asyncio
from src.tools.hello import hello_world

async def test():
    await hello_world({'name': 'User$i', 'language': 'en'})

asyncio.run(test())
  " &
done

wait
```

View the dashboard - you should see metrics!

## Part 5: Set Up Alerting (30 minutes)

### Step 1: Create Alert Rules

```bash
cat > k8s/prometheus-rules.yaml << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: mcp-server-alerts
  namespace: monitoring
  labels:
    prometheus: kube-prometheus
spec:
  groups:
    - name: mcp_server
      interval: 30s
      rules:
        - alert: MCPServerDown
          expr: up{job="mcp-hello-server-metrics"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "MCP Server is down"
            description: "MCP Server has been down for more than 5 minutes"
        
        - alert: HighErrorRate
          expr: |
            rate(mcp_tool_errors_total[5m]) > 0.1
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "High error rate detected"
            description: "Tool error rate is {{ $value }} errors/second"
        
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
            description: "P95 latency is {{ $value }} seconds"
        
        - alert: TooManyActiveRequests
          expr: sum(mcp_active_requests) > 50
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Too many active requests"
            description: "{{ $value }} active requests (threshold: 50)"
EOF

kubectl apply -f k8s/prometheus-rules.yaml
```

### Step 2: Verify Alerts

```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9091:9090

# Open: http://localhost:9091/alerts
# You should see your alert rules
```

### Step 3: Test Alert

```bash
# Stop the MCP server to trigger alert
kubectl scale deployment/mcp-hello-server --replicas=0

# Wait 5+ minutes, check Prometheus alerts
# The MCPServerDown alert should fire

# Restore
kubectl scale deployment/mcp-hello-server --replicas=1
```

## Troubleshooting

### Metrics not appearing

```bash
# Check metrics endpoint directly
kubectl exec -it $POD -- curl localhost:9090/metrics

# Check ServiceMonitor
kubectl get servicemonitor -n default

# Check Prometheus targets
# Prometheus UI -> Status -> Targets
```

### Dashboard shows "No Data"

```bash
# Verify Prometheus is scraping
# Run a test query in Prometheus:
mcp_tool_calls_total

# Check time range in Grafana
# Ensure it covers when metrics were generated
```

### Alerts not firing

```bash
# Check PrometheusRule
kubectl get prometheusrule -n monitoring

# View in Prometheus UI
# Prometheus -> Alerts

# Check Alertmanager
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
```

## Deliverables

By the end of this lab, you should have:

- ✅ Prometheus client library integrated
- ✅ Custom metrics implemented and tracked
- ✅ Metrics HTTP endpoint exposed
- ✅ ServiceMonitor configured
- ✅ Prometheus successfully scraping metrics
- ✅ Grafana dashboard displaying metrics
- ✅ Alert rules configured and tested

## Bonus Challenges

1. **Add More Metrics**:
   - Request/response size
   - Memory usage per tool
   - Cache hit rates

2. **Advanced Dashboards**:
   - Create separate dashboards for different audiences
   - Add templating variables
   - Implement drill-down panels

3. **Custom Exporters**:
   - Create a sidecar exporter for Kubernetes metrics
   - Export custom application metrics

4. **Alerting Integration**:
   - Configure Slack notifications
   - Set up PagerDuty integration
   - Create runbooks for alerts

## Next Steps

1. Review your metrics in Grafana
2. Adjust alert thresholds based on actual traffic
3. Proceed to [Day 2: Advanced Features](../../day-2/README.md)

## Reference

```bash
# Quick commands
kubectl port-forward svc/mcp-hello-server-metrics 9090:9090    # Metrics
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9091:9090  # Prometheus
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80  # Grafana

# Generate test traffic
for i in {1..100}; do kubectl exec $POD -- python -c "..."; done
```

---

**Estimated Completion Time**: 2.5 hours  
**Difficulty**: Intermediate  
**Questions?** Check the [troubleshooting guide](../../docs/troubleshooting.md)
