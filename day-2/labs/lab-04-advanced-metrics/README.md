# Lab 4: Advanced Metrics and Monitoring

**Duration**: 3 hours  
**Difficulty**: Intermediate  
**Prerequisites**: Completed Labs 1-3

## Overview

In this lab, you'll implement advanced monitoring capabilities for your MCP server:

- Custom metrics with labels and aggregations
- Distributed tracing with OpenTelemetry
- Performance profiling and optimization
- Alert rules and notification channels
- SLO/SLI implementation

## Learning Objectives

By the end of this lab, you will be able to:

1. Design and implement custom metrics with proper cardinality
2. Instrument code with distributed tracing
3. Create meaningful SLIs and SLOs
4. Build comprehensive dashboards
5. Configure alert routing and escalation

## Prerequisites

### Required Knowledge

- Understanding of Prometheus metrics types
- Basic Grafana dashboard creation
- Familiarity with your MCP server code

### Required Tools

- Working Kubernetes cluster (from Lab 1)
- MCP server from previous labs
- Prometheus and Grafana installed

### Verify Setup

```bash
# Check Prometheus
kubectl get pods -n monitoring | grep prometheus

# Check Grafana
kubectl get pods -n monitoring | grep grafana

# Verify your MCP server
kubectl get pods -n mcp-servers
```

## Lab Structure

```
lab-04-advanced-metrics/
├── README.md (this file)
├── examples/
│   ├── metrics_advanced.py
│   ├── tracing_config.py
│   └── slo_calculator.py
├── manifests/
│   ├── servicemonitor.yaml
│   ├── prometheusrule.yaml
│   └── alertmanagerconfig.yaml
└── solutions/
    └── complete_implementation/
```

## Part 1: Advanced Custom Metrics (45 min)

### 1.1: Multi-Dimensional Metrics

Create metrics with multiple labels for better analysis:

```python
# advanced_metrics.py
from prometheus_client import Counter, Histogram, Gauge, Info
import functools
import time

# Request metrics with multiple dimensions
tool_requests = Counter(
    'mcp_tool_requests_total',
    'Total tool requests',
    ['tool_name', 'client_id', 'result', 'error_type']
)

tool_duration = Histogram(
    'mcp_tool_duration_seconds',
    'Tool execution duration',
    ['tool_name', 'complexity'],
    buckets=[0.01, 0.05, 0.1, 0.5, 1.0, 2.5, 5.0, 10.0]
)

# Resource metrics
active_connections = Gauge(
    'mcp_active_connections',
    'Number of active client connections',
    ['client_type']
)

cache_operations = Counter(
    'mcp_cache_operations_total',
    'Cache operations',
    ['operation', 'result']  # operation: hit/miss/evict, result: success/failure
)

# Business metrics
data_processed = Counter(
    'mcp_data_processed_bytes_total',
    'Total data processed',
    ['tool_name', 'data_type']
)

# Server info
server_info = Info(
    'mcp_server',
    'MCP server information'
)
server_info.info({
    'version': '1.0.0',
    'environment': 'production',
    'region': 'us-west-2'
})
```

### 1.2: Metric Decorators

Create reusable decorators for automatic instrumentation:

```python
# metrics_decorators.py
import functools
import time
from typing import Callable, Any
from prometheus_client import Counter, Histogram

def track_tool_execution(
    tool_name: str = None,
    track_args: bool = False
):
    """Decorator to track tool execution metrics"""
    
    def decorator(func: Callable) -> Callable:
        nonlocal tool_name
        if tool_name is None:
            tool_name = func.__name__
        
        requests_total = Counter(
            f'tool_{tool_name}_requests_total',
            f'Total requests to {tool_name}',
            ['status']
        )
        
        duration_seconds = Histogram(
            f'tool_{tool_name}_duration_seconds',
            f'Execution time for {tool_name}',
            buckets=[0.01, 0.05, 0.1, 0.5, 1.0, 2.5, 5.0]
        )
        
        @functools.wraps(func)
        async def wrapper(*args, **kwargs):
            start_time = time.time()
            status = 'success'
            
            try:
                result = await func(*args, **kwargs)
                return result
            except Exception as e:
                status = 'error'
                raise
            finally:
                duration = time.time() - start_time
                requests_total.labels(status=status).inc()
                duration_seconds.observe(duration)
        
        return wrapper
    return decorator


def track_cache_metrics(cache_name: str):
    """Decorator to track cache operations"""
    
    cache_hits = Counter(
        f'cache_{cache_name}_hits_total',
        f'Cache hits for {cache_name}'
    )
    
    cache_misses = Counter(
        f'cache_{cache_name}_misses_total',
        f'Cache misses for {cache_name}'
    )
    
    def decorator(func: Callable) -> Callable:
        @functools.wraps(func)
        async def wrapper(key: str, *args, **kwargs):
            result = await func(key, *args, **kwargs)
            
            if result is not None:
                cache_hits.inc()
            else:
                cache_misses.inc()
            
            return result
        
        return wrapper
    return decorator


# Usage example
@track_tool_execution(tool_name='diagnose_pod', track_args=True)
async def diagnose_pod(namespace: str, pod_name: str):
    # Implementation
    pass

@track_cache_metrics(cache_name='pod_status')
async def get_cached_pod_status(key: str):
    # Check cache
    return cache.get(key)
```

### 1.3: Aggregation Metrics

Implement metrics that aggregate over time:

```python
# aggregation_metrics.py
from prometheus_client import Summary, Histogram
import asyncio
from collections import deque
from typing import Deque
import time

class MetricsAggregator:
    """Aggregate metrics over sliding windows"""
    
    def __init__(self, window_size: int = 60):
        self.window_size = window_size  # seconds
        self.data_points: Deque[tuple[float, float]] = deque()
        
        # Summary for percentile calculation
        self.response_time = Summary(
            'tool_response_time_seconds',
            'Tool response time with percentiles',
            ['tool_name']
        )
        
        # Histogram for distribution
        self.response_distribution = Histogram(
            'tool_response_distribution_seconds',
            'Distribution of response times',
            ['tool_name'],
            buckets=[0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0]
        )
    
    def record(self, tool_name: str, duration: float):
        """Record a data point"""
        now = time.time()
        
        # Add to sliding window
        self.data_points.append((now, duration))
        
        # Remove old data points
        cutoff = now - self.window_size
        while self.data_points and self.data_points[0][0] < cutoff:
            self.data_points.popleft()
        
        # Update Prometheus metrics
        self.response_time.labels(tool_name=tool_name).observe(duration)
        self.response_distribution.labels(tool_name=tool_name).observe(duration)
    
    def get_percentile(self, percentile: float) -> float:
        """Calculate percentile from sliding window"""
        if not self.data_points:
            return 0.0
        
        values = sorted([v for _, v in self.data_points])
        index = int(len(values) * percentile / 100)
        return values[index]
    
    def get_avg(self) -> float:
        """Calculate average from sliding window"""
        if not self.data_points:
            return 0.0
        
        values = [v for _, v in self.data_points]
        return sum(values) / len(values)


# Global aggregator instance
metrics_agg = MetricsAggregator(window_size=300)  # 5-minute window

# Usage
async def execute_tool(tool_name: str):
    start = time.time()
    try:
        # Execute tool
        result = await do_work()
        return result
    finally:
        duration = time.time() - start
        metrics_agg.record(tool_name, duration)
```

**Task 1.1**: Implement multi-dimensional metrics for your MCP server
**Task 1.2**: Create metric decorators for common patterns
**Task 1.3**: Add aggregation metrics for sliding windows

**Checkpoint**: Run your server and verify metrics are exposed with multiple labels

---

## Part 2: Distributed Tracing (60 min)

### 2.1: OpenTelemetry Setup

Configure OpenTelemetry for distributed tracing:

```python
# tracing_config.py
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.aiohttp_client import AioHttpClientInstrumentor
import os

def setup_tracing(service_name: str = "mcp-server"):
    """Initialize OpenTelemetry tracing"""
    
    # Create resource with service information
    resource = Resource.create({
        "service.name": service_name,
        "service.version": os.getenv("SERVICE_VERSION", "1.0.0"),
        "deployment.environment": os.getenv("ENVIRONMENT", "development"),
        "k8s.namespace.name": os.getenv("K8S_NAMESPACE", "default"),
        "k8s.pod.name": os.getenv("POD_NAME", "unknown"),
    })
    
    # Create tracer provider
    provider = TracerProvider(resource=resource)
    
    # Configure OTLP exporter (to Jaeger/Tempo)
    otlp_exporter = OTLPSpanExporter(
        endpoint=os.getenv("OTLP_ENDPOINT", "http://tempo:4317"),
        insecure=True  # Use TLS in production
    )
    
    # Add span processor
    provider.add_span_processor(BatchSpanProcessor(otlp_exporter))
    
    # Set as global tracer provider
    trace.set_tracer_provider(provider)
    
    return trace.get_tracer(__name__)


# Initialize tracer
tracer = setup_tracing("mcp-diagnostics-server")
```

### 2.2: Instrument MCP Server

Add tracing to your MCP server:

```python
# traced_mcp_server.py
from opentelemetry import trace
from opentelemetry.trace import Status, StatusCode
from typing import Any, Dict
import asyncio

tracer = trace.get_tracer(__name__)

class TracedMCPServer:
    """MCP Server with distributed tracing"""
    
    async def handle_request(self, request: Dict[str, Any]) -> Dict[str, Any]:
        """Handle incoming MCP request with tracing"""
        
        # Extract trace context from request headers if available
        # (for cross-service tracing)
        
        with tracer.start_as_current_span(
            "mcp.handle_request",
            kind=trace.SpanKind.SERVER
        ) as span:
            # Add request attributes
            span.set_attribute("mcp.method", request.get("method"))
            span.set_attribute("mcp.request_id", request.get("id"))
            
            try:
                # Route to appropriate handler
                method = request.get("method")
                
                if method == "tools/call":
                    result = await self._handle_tool_call(request, span)
                elif method == "tools/list":
                    result = await self._handle_tool_list(request, span)
                else:
                    raise ValueError(f"Unknown method: {method}")
                
                span.set_status(Status(StatusCode.OK))
                return result
                
            except Exception as e:
                # Record exception
                span.set_status(Status(StatusCode.ERROR, str(e)))
                span.record_exception(e)
                raise
    
    async def _handle_tool_call(
        self,
        request: Dict[str, Any],
        parent_span: trace.Span
    ) -> Dict[str, Any]:
        """Handle tool call with child span"""
        
        tool_name = request["params"]["name"]
        arguments = request["params"].get("arguments", {})
        
        with tracer.start_as_current_span(
            f"tool.{tool_name}",
            kind=trace.SpanKind.INTERNAL
        ) as span:
            span.set_attribute("tool.name", tool_name)
            span.set_attribute("tool.arguments", str(arguments))
            
            # Validate input
            with tracer.start_as_current_span("validate_input"):
                self._validate_arguments(tool_name, arguments)
            
            # Execute tool
            with tracer.start_as_current_span("execute_tool") as exec_span:
                result = await self._execute_tool(tool_name, arguments)
                exec_span.set_attribute("result.size", len(str(result)))
            
            # Format response
            with tracer.start_as_current_span("format_response"):
                response = self._format_response(request["id"], result)
            
            return response
    
    async def _execute_tool(self, tool_name: str, arguments: Dict) -> Any:
        """Execute tool with detailed tracing"""
        
        with tracer.start_as_current_span(
            f"execute.{tool_name}",
            attributes={
                "tool.name": tool_name,
                "tool.input.namespace": arguments.get("namespace"),
                "tool.input.pod_name": arguments.get("pod_name"),
            }
        ) as span:
            # Example: Kubernetes API calls
            if tool_name == "diagnose_pod":
                return await self._diagnose_pod_traced(
                    arguments["namespace"],
                    arguments["pod_name"]
                )
            
            # Other tools...
    
    async def _diagnose_pod_traced(
        self,
        namespace: str,
        pod_name: str
    ) -> Dict[str, Any]:
        """Diagnose pod with detailed tracing"""
        
        diagnosis = {}
        
        # Get pod status
        with tracer.start_as_current_span("k8s.get_pod") as span:
            span.set_attribute("k8s.namespace", namespace)
            span.set_attribute("k8s.pod_name", pod_name)
            
            pod = await self.k8s_client.get_pod(namespace, pod_name)
            diagnosis["status"] = pod.status.phase
        
        # Get pod logs
        with tracer.start_as_current_span("k8s.get_logs") as span:
            logs = await self.k8s_client.get_pod_logs(
                namespace,
                pod_name,
                tail_lines=100
            )
            diagnosis["recent_logs"] = logs
        
        # Analyze events
        with tracer.start_as_current_span("k8s.get_events") as span:
            events = await self.k8s_client.get_pod_events(namespace, pod_name)
            diagnosis["events"] = events
        
        # Run health checks
        with tracer.start_as_current_span("health_checks") as span:
            health = await self._run_health_checks(pod)
            diagnosis["health_checks"] = health
            span.set_attribute("health.overall", health.get("overall"))
        
        return diagnosis
```

### 2.3: Cross-Service Tracing

Propagate trace context across services:

```python
# cross_service_tracing.py
from opentelemetry import trace
from opentelemetry.propagate import inject, extract
import aiohttp

tracer = trace.get_tracer(__name__)

async def call_external_service(url: str, data: Dict) -> Dict:
    """Make HTTP request with trace context propagation"""
    
    with tracer.start_as_current_span(
        "http.request",
        kind=trace.SpanKind.CLIENT
    ) as span:
        span.set_attribute("http.url", url)
        span.set_attribute("http.method", "POST")
        
        # Inject trace context into headers
        headers = {}
        inject(headers)
        
        async with aiohttp.ClientSession() as session:
            async with session.post(url, json=data, headers=headers) as response:
                span.set_attribute("http.status_code", response.status)
                
                result = await response.json()
                return result


# On receiving side
async def handle_request(request):
    """Extract trace context from incoming request"""
    
    # Extract trace context from headers
    ctx = extract(request.headers)
    
    # Use extracted context
    with tracer.start_as_current_span(
        "process_request",
        context=ctx,
        kind=trace.SpanKind.SERVER
    ):
        # Process request
        pass
```

**Task 2.1**: Set up OpenTelemetry in your MCP server
**Task 2.2**: Instrument key operations with spans
**Task 2.3**: Deploy Jaeger/Tempo for trace visualization

**Checkpoint**: Generate traces and view them in Jaeger UI

---

## Part 3: SLI/SLO Implementation (45 min)

### 3.1: Define SLIs (Service Level Indicators)

```python
# sli_calculator.py
from prometheus_client import Counter, Histogram, Gauge
from dataclasses import dataclass
from typing import List
import time

@dataclass
class SLI:
    """Service Level Indicator"""
    name: str
    description: str
    target: float  # Target percentage (e.g., 99.9)
    measurement_window: int  # seconds

class SLICalculator:
    """Calculate SLIs for MCP server"""
    
    def __init__(self):
        # Availability SLI
        self.requests_total = Counter(
            'sli_requests_total',
            'Total requests for SLI calculation',
            ['result']  # success, error, timeout
        )
        
        # Latency SLI
        self.request_duration = Histogram(
            'sli_request_duration_seconds',
            'Request duration for SLI',
            buckets=[0.1, 0.5, 1.0, 2.0, 5.0]  # SLO thresholds
        )
        
        # Quality SLI
        self.quality_score = Gauge(
            'sli_quality_score',
            'Quality score of responses',
            ['tool_name']
        )
        
        # Error budget
        self.error_budget_remaining = Gauge(
            'sli_error_budget_remaining_percent',
            'Remaining error budget percentage',
            ['sli_name']
        )
    
    def record_request(self, success: bool, duration: float):
        """Record request for SLI calculation"""
        result = 'success' if success else 'error'
        self.requests_total.labels(result=result).inc()
        self.request_duration.observe(duration)
    
    def calculate_availability_sli(self, window_seconds: int = 3600) -> float:
        """
        Calculate availability SLI
        
        SLI = (successful requests / total requests) * 100
        """
        # Query Prometheus for metrics over window
        # This is a simplified version - in production, query Prometheus API
        
        # Example calculation (pseudo-code)
        total = self._query_prometheus(
            f'sum(rate(sli_requests_total[{window_seconds}s]))'
        )
        errors = self._query_prometheus(
            f'sum(rate(sli_requests_total{{result="error"}}[{window_seconds}s]))'
        )
        
        if total == 0:
            return 100.0
        
        availability = ((total - errors) / total) * 100
        return availability
    
    def calculate_latency_sli(
        self,
        threshold_seconds: float = 1.0,
        window_seconds: int = 3600
    ) -> float:
        """
        Calculate latency SLI
        
        SLI = (requests under threshold / total requests) * 100
        """
        # Query histogram for requests under threshold
        under_threshold = self._query_prometheus(
            f'sum(rate(sli_request_duration_seconds_bucket{{le="{threshold_seconds}"}}[{window_seconds}s]))'
        )
        total = self._query_prometheus(
            f'sum(rate(sli_request_duration_seconds_count[{window_seconds}s]))'
        )
        
        if total == 0:
            return 100.0
        
        latency_sli = (under_threshold / total) * 100
        return latency_sli
    
    def calculate_error_budget(
        self,
        slo_target: float,
        current_sli: float,
        window_seconds: int = 86400  # 24 hours
    ) -> float:
        """
        Calculate remaining error budget
        
        Error Budget = 1 - SLO
        Remaining Budget = ((Error Budget - Errors Made) / Error Budget) * 100
        """
        error_budget = 100 - slo_target  # e.g., 100 - 99.9 = 0.1%
        errors_made = 100 - current_sli  # e.g., 100 - 99.95 = 0.05%
        
        if error_budget == 0:
            return 0.0
        
        remaining = ((error_budget - errors_made) / error_budget) * 100
        return max(0, remaining)  # Can't be negative


# Define SLOs
SLOS = {
    'availability': SLI(
        name='availability',
        description='Percentage of successful requests',
        target=99.9,  # 99.9% availability
        measurement_window=3600  # 1 hour
    ),
    'latency': SLI(
        name='latency',
        description='Percentage of requests under 1 second',
        target=95.0,  # 95% of requests under 1s
        measurement_window=3600
    ),
    'quality': SLI(
        name='quality',
        description='Quality score of responses',
        target=99.0,  # 99% quality score
        measurement_window=3600
    )
}
```

### 3.2: SLO Monitoring Dashboard

Create a Grafana dashboard for SLO monitoring:

```json
{
  "dashboard": {
    "title": "MCP Server SLO Dashboard",
    "panels": [
      {
        "title": "Availability SLI",
        "targets": [
          {
            "expr": "(sum(rate(sli_requests_total{result=\"success\"}[1h])) / sum(rate(sli_requests_total[1h]))) * 100",
            "legendFormat": "Current SLI"
          },
          {
            "expr": "99.9",
            "legendFormat": "SLO Target"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Latency SLI (% under 1s)",
        "targets": [
          {
            "expr": "(sum(rate(sli_request_duration_seconds_bucket{le=\"1.0\"}[1h])) / sum(rate(sli_request_duration_seconds_count[1h]))) * 100",
            "legendFormat": "Current SLI"
          },
          {
            "expr": "95.0",
            "legendFormat": "SLO Target"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Error Budget Remaining",
        "targets": [
          {
            "expr": "sli_error_budget_remaining_percent",
            "legendFormat": "{{sli_name}}"
          }
        ],
        "type": "gauge",
        "thresholds": [
          {"value": 0, "color": "red"},
          {"value": 25, "color": "yellow"},
          {"value": 50, "color": "green"}
        ]
      }
    ]
  }
}
```

**Task 3.1**: Define SLIs for your MCP server
**Task 3.2**: Implement SLI calculation
**Task 3.3**: Create SLO monitoring dashboard

**Checkpoint**: View SLI metrics and error budget in Grafana

---

## Part 4: Advanced Alerting (30 min)

### 4.1: Multi-Window Alerts

Create alerts that use multiple time windows:

```yaml
# prometheusrule-advanced.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: mcp-advanced-alerts
  namespace: monitoring
spec:
  groups:
    - name: slo_alerts
      interval: 30s
      rules:
        # Multi-window alert for availability
        - alert: SLOAvailabilityBurnRateFast
          expr: |
            (
              sum(rate(sli_requests_total{result="error"}[1m]))
              /
              sum(rate(sli_requests_total[1m]))
            ) > (14.4 * (1 - 0.999))
          for: 2m
          labels:
            severity: critical
            slo: availability
          annotations:
            summary: "Fast burn rate detected on availability SLO"
            description: "Error rate is {{ $value | humanizePercentage }} over 1m window"
        
        - alert: SLOAvailabilityBurnRateSlow
          expr: |
            (
              sum(rate(sli_requests_total{result="error"}[1h]))
              /
              sum(rate(sli_requests_total[1h]))
            ) > (1 * (1 - 0.999))
          for: 1h
          labels:
            severity: warning
            slo: availability
          annotations:
            summary: "Slow burn rate detected on availability SLO"
            description: "Error rate is {{ $value | humanizePercentage }} over 1h window"
        
        # Error budget exhaustion
        - alert: ErrorBudgetExhausted
          expr: |
            sli_error_budget_remaining_percent < 10
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Error budget is running low"
            description: "Only {{ $value }}% of error budget remains for {{ $labels.sli_name }}"
        
        # Latency SLO violation
        - alert: LatencySLOViolation
          expr: |
            (
              sum(rate(sli_request_duration_seconds_bucket{le="1.0"}[5m]))
              /
              sum(rate(sli_request_duration_seconds_count[5m]))
            ) < 0.95
          for: 10m
          labels:
            severity: warning
            slo: latency
          annotations:
            summary: "Latency SLO is being violated"
            description: "Only {{ $value | humanizePercentage }} of requests are under 1s"
```

### 4.2: Alert Routing

Configure AlertManager for intelligent routing:

```yaml
# alertmanager-config.yaml
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-config
  namespace: monitoring
type: Opaque
stringData:
  alertmanager.yaml: |
    global:
      resolve_timeout: 5m
      slack_api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
    
    route:
      group_by: ['alertname', 'slo']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'default'
      
      routes:
        # Critical SLO alerts go to on-call
        - match:
            severity: critical
            slo: availability
          receiver: 'oncall'
          group_wait: 0s
          continue: true
        
        # Warning alerts to team channel
        - match:
            severity: warning
          receiver: 'team-channel'
        
        # Error budget alerts
        - match:
            alertname: ErrorBudgetExhausted
          receiver: 'engineering-leads'
    
    receivers:
      - name: 'default'
        slack_configs:
          - channel: '#alerts'
            title: 'MCP Server Alert'
            text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
      
      - name: 'oncall'
        pagerduty_configs:
          - service_key: 'YOUR_PAGERDUTY_KEY'
            description: '{{ .GroupLabels.alertname }}: {{ .CommonAnnotations.summary }}'
        slack_configs:
          - channel: '#oncall-alerts'
            title: 'CRITICAL: {{ .GroupLabels.alertname }}'
      
      - name: 'team-channel'
        slack_configs:
          - channel: '#mcp-team'
            title: 'Warning: {{ .GroupLabels.alertname }}'
      
      - name: 'engineering-leads'
        email_configs:
          - to: 'eng-leads@company.com'
            subject: 'Error Budget Alert: {{ .GroupLabels.slo }}'
```

**Task 4.1**: Create multi-window burn rate alerts
**Task 4.2**: Configure AlertManager routing
**Task 4.3**: Test alert delivery

**Checkpoint**: Trigger test alerts and verify routing

---

## Deliverables

### 1. Enhanced MCP Server

Your server should include:

- [ ] Multi-dimensional custom metrics
- [ ] Distributed tracing instrumentation
- [ ] SLI calculation logic
- [ ] Comprehensive error handling

### 2. Monitoring Configuration

- [ ] ServiceMonitor with advanced metrics
- [ ] PrometheusRule with SLO alerts
- [ ] AlertManager configuration

### 3. Dashboards

- [ ] SLO monitoring dashboard
- [ ] Distributed tracing dashboard
- [ ] Error budget dashboard

### 4. Documentation

- [ ] SLI/SLO definitions
- [ ] Alert runbooks
- [ ] Dashboard usage guide

## Testing

### Test Advanced Metrics

```bash
# Generate load
kubectl run load-test --image=busybox --restart=Never -- \
  sh -c "while true; do wget -q -O- http://mcp-server:8080/metrics; sleep 0.1; done"

# Check metric cardinality
curl http://mcp-server:8080/metrics | grep mcp_tool_requests_total | wc -l

# Verify labels
curl http://mcp-server:8080/metrics | grep mcp_tool_requests_total
```

### Test Distributed Tracing

```bash
# Make requests with trace context
curl -X POST http://mcp-server:8080/call-tool \
  -H "Content-Type: application/json" \
  -H "traceparent: 00-trace-id-span-id-01" \
  -d '{"tool": "diagnose_pod", "args": {"namespace": "default", "pod": "test"}}'

# View traces in Jaeger
open http://localhost:16686
```

### Verify SLO Calculations

```python
# test_slo.py
import asyncio
from sli_calculator import SLICalculator, SLOS

async def test_slo_calculation():
    calc = SLICalculator()
    
    # Simulate requests
    for i in range(1000):
        success = i % 100 != 0  # 1% error rate
        duration = 0.5 if success else 2.0
        calc.record_request(success, duration)
    
    # Calculate SLIs
    availability = calc.calculate_availability_sli()
    latency = calc.calculate_latency_sli(threshold_seconds=1.0)
    
    print(f"Availability SLI: {availability}%")
    print(f"Latency SLI: {latency}%")
    
    # Check against SLOs
    for slo_name, slo in SLOS.items():
        if slo_name == 'availability':
            current = availability
        elif slo_name == 'latency':
            current = latency
        
        budget = calc.calculate_error_budget(slo.target, current)
        print(f"{slo_name} error budget remaining: {budget}%")

if __name__ == "__main__":
    asyncio.run(test_slo_calculation())
```

## Common Issues

### High Metric Cardinality

**Problem**: Too many metric labels causing memory issues

**Solution**:
```python
# BAD: Unbounded cardinality
requests.labels(client_id=client_id, url=full_url).inc()

# GOOD: Limited cardinality
requests.labels(
    client_id=hash_client_id(client_id)[:8],  # Truncate
    endpoint=extract_endpoint(url)  # "/api/v1/pods" not "/api/v1/pods/abc123"
).inc()
```

### Missing Traces

**Problem**: Traces not appearing in Jaeger

**Solution**:
- Check OTLP exporter endpoint
- Verify trace sampling rate
- Check Jaeger collector logs
- Ensure trace context propagation

### SLO Drift

**Problem**: SLI values don't match reality

**Solution**:
- Verify measurement windows
- Check Prometheus retention
- Validate PromQL queries
- Review sampling methodology

## Bonus Challenges

### Challenge 1: Custom Trace Sampling

Implement intelligent trace sampling:

```python
# Only sample slow requests and errors
def should_sample(duration: float, has_error: bool) -> bool:
    if has_error:
        return True  # Always sample errors
    
    if duration > 2.0:
        return True  # Always sample slow requests
    
    # 10% sampling for normal requests
    import random
    return random.random() < 0.1
```

### Challenge 2: Anomaly Detection

Create alerts that detect anomalies:

```yaml
- alert: AnomalousLatency
  expr: |
    (
      rate(sli_request_duration_seconds_sum[5m])
      /
      rate(sli_request_duration_seconds_count[5m])
    )
    >
    (
      avg_over_time((rate(sli_request_duration_seconds_sum[5m]) / rate(sli_request_duration_seconds_count[5m]))[7d:5m])
      + (3 * stddev_over_time((rate(sli_request_duration_seconds_sum[5m]) / rate(sli_request_duration_seconds_count[5m]))[7d:5m]))
    )
  for: 10m
```

### Challenge 3: Cost Tracking

Add cost attribution metrics:

```python
cost_per_request = Gauge(
    'mcp_request_cost_usd',
    'Estimated cost per request',
    ['tool_name', 'resource_type']
)

# Track compute costs
compute_seconds = Counter(
    'mcp_compute_seconds_total',
    'Total compute seconds used',
    ['tool_name']
)
```

## Summary

You've learned:

✅ Multi-dimensional custom metrics  
✅ Distributed tracing with OpenTelemetry  
✅ SLI/SLO implementation and monitoring  
✅ Advanced alerting strategies  
✅ Error budget management

## Next Steps

- Complete Lab 5: Custom MCP Development
- Review best practices documentation
- Explore advanced Prometheus features

## Resources

- [OpenTelemetry Python SDK](https://opentelemetry.io/docs/instrumentation/python/)
- [SLO Implementation Guide](https://sre.google/workbook/implementing-slos/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
