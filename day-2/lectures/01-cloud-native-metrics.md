# Cloud-Native Metrics Collection Patterns

**Module 2 - Lecture 1**  
**Duration**: 30 minutes

---

## Agenda

1. Introduction to Cloud-Native Monitoring
2. The Four Golden Signals
3. RED vs USE Method
4. Metric Types and When to Use Them
5. Pull vs Push Models
6. OpenMetrics Standard
7. Best Practices

---

## Cloud-Native Monitoring Landscape

### Evolution of Monitoring

```
Traditional Monitoring       →      Cloud-Native Monitoring
├── Server-centric          →      Container-centric
├── Static infrastructure    →      Dynamic infrastructure
├── Manual configuration     →      Auto-discovery
├── Siloed metrics          →      Unified observability
└── Reactive alerts         →      Proactive SLOs
```

### Key Characteristics

**Cloud-Native Monitoring is**:

- **Distributed**: Spans multiple services and nodes
- **Dynamic**: Adapts to auto-scaling
- **Label-based**: Multi-dimensional data
- **Service-oriented**: Focuses on service health
- **API-driven**: Programmable configuration

---

## The Four Golden Signals

### 1. Latency

> Time it takes to service a request

**Why it matters**: Directly impacts user experience

**What to measure**:
- Request duration (p50, p90, p99)
- Queue wait time
- Database query time
- External API call latency

```python
# Measure latency
from prometheus_client import Histogram

request_latency = Histogram(
    'http_request_duration_seconds',
    'HTTP request latency',
    ['method', 'endpoint'],
    buckets=[0.01, 0.05, 0.1, 0.5, 1.0, 2.5, 5.0]
)

@app.route('/api/data')
@request_latency.labels(method='GET', endpoint='/api/data').time()
def get_data():
    return fetch_data()
```

---

### 2. Traffic

> Demand on your system

**Why it matters**: Understand usage patterns and capacity needs

**What to measure**:
- Requests per second
- Concurrent connections
- Transactions per second
- Data transfer volume

```python
# Measure traffic
from prometheus_client import Counter

requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

@app.route('/api/data')
def get_data():
    requests_total.labels(
        method='GET',
        endpoint='/api/data',
        status='200'
    ).inc()
    return fetch_data()
```

---

### 3. Errors

> Rate of requests that fail

**Why it matters**: Critical for reliability and user satisfaction

**What to measure**:
- HTTP 5xx errors
- HTTP 4xx errors (client errors)
- Application exceptions
- Failed health checks

```python
# Measure errors
from prometheus_client import Counter

errors_total = Counter(
    'http_errors_total',
    'Total HTTP errors',
    ['method', 'endpoint', 'error_type']
)

@app.route('/api/data')
def get_data():
    try:
        return fetch_data()
    except DatabaseError as e:
        errors_total.labels(
            method='GET',
            endpoint='/api/data',
            error_type='database_error'
        ).inc()
        raise
```

---

### 4. Saturation

> How "full" your service is

**Why it matters**: Predicts when you'll need to scale

**What to measure**:
- CPU utilization
- Memory usage
- Disk I/O
- Network bandwidth
- Queue depth

```python
# Measure saturation
from prometheus_client import Gauge
import psutil

cpu_usage = Gauge('process_cpu_usage_percent', 'CPU usage percentage')
memory_usage = Gauge('process_memory_bytes', 'Memory usage in bytes')

def update_resource_metrics():
    cpu_usage.set(psutil.cpu_percent())
    memory_usage.set(psutil.Process().memory_info().rss)
```

---

## RED Method

### For Request-Driven Services

**RED** = Rate, Errors, Duration

**Best for**: Web services, APIs, microservices

```
┌─────────────────────────────────────┐
│         RED Method                  │
├─────────────────────────────────────┤
│ Rate:     Requests per second       │
│ Errors:   Failed requests per sec   │
│ Duration: Request latency           │
└─────────────────────────────────────┘
```

### Implementation

```python
from prometheus_client import Counter, Histogram
import time

# Rate
request_count = Counter(
    'service_requests_total',
    'Total service requests',
    ['service', 'method', 'endpoint']
)

# Errors
error_count = Counter(
    'service_errors_total',
    'Total service errors',
    ['service', 'method', 'endpoint', 'error_code']
)

# Duration
request_duration = Histogram(
    'service_request_duration_seconds',
    'Service request duration',
    ['service', 'method', 'endpoint']
)

# Decorator for automatic RED metrics
def track_red_metrics(service_name: str):
    def decorator(func):
        @functools.wraps(func)
        async def wrapper(*args, **kwargs):
            # Increment rate
            request_count.labels(
                service=service_name,
                method=func.__name__,
                endpoint=request.path
            ).inc()
            
            # Track duration
            start_time = time.time()
            try:
                result = await func(*args, **kwargs)
                return result
            except Exception as e:
                # Track errors
                error_count.labels(
                    service=service_name,
                    method=func.__name__,
                    endpoint=request.path,
                    error_code=type(e).__name__
                ).inc()
                raise
            finally:
                duration = time.time() - start_time
                request_duration.labels(
                    service=service_name,
                    method=func.__name__,
                    endpoint=request.path
                ).observe(duration)
        
        return wrapper
    return decorator
```

---

## USE Method

### For Resource-Oriented Services

**USE** = Utilization, Saturation, Errors

**Best for**: Infrastructure, databases, resource-constrained systems

```
┌─────────────────────────────────────┐
│         USE Method                  │
├─────────────────────────────────────┤
│ Utilization: % time resource busy  │
│ Saturation:  Amount of queued work  │
│ Errors:      Error events           │
└─────────────────────────────────────┘
```

### Implementation

```python
from prometheus_client import Gauge, Counter
import psutil

class ResourceMetrics:
    """Track USE metrics for system resources"""
    
    def __init__(self):
        # Utilization
        self.cpu_utilization = Gauge(
            'resource_cpu_utilization_percent',
            'CPU utilization percentage',
            ['core']
        )
        
        self.memory_utilization = Gauge(
            'resource_memory_utilization_percent',
            'Memory utilization percentage'
        )
        
        # Saturation
        self.cpu_queue_length = Gauge(
            'resource_cpu_queue_length',
            'CPU run queue length'
        )
        
        self.swap_usage = Gauge(
            'resource_swap_bytes',
            'Swap space usage in bytes'
        )
        
        # Errors
        self.disk_errors = Counter(
            'resource_disk_errors_total',
            'Total disk I/O errors',
            ['device']
        )
    
    def collect(self):
        """Collect USE metrics"""
        # CPU utilization per core
        for i, pct in enumerate(psutil.cpu_percent(percpu=True)):
            self.cpu_utilization.labels(core=str(i)).set(pct)
        
        # Memory utilization
        mem = psutil.virtual_memory()
        self.memory_utilization.set(mem.percent)
        
        # CPU queue (load average on Linux)
        load = psutil.getloadavg()[0]  # 1-minute load average
        self.cpu_queue_length.set(load)
        
        # Swap usage (saturation indicator)
        swap = psutil.swap_memory()
        self.swap_usage.set(swap.used)
```

---

## Metric Types Deep Dive

### Counter

> Monotonically increasing value

**Use cases**:
- Total requests
- Total errors
- Total bytes processed

**Anti-patterns**:
- Don't use for values that can decrease
- Don't reset counters (breaks rate calculations)

```python
from prometheus_client import Counter

page_views = Counter(
    'website_page_views_total',
    'Total page views',
    ['page', 'user_type']
)

# Increment
page_views.labels(page='/home', user_type='guest').inc()
page_views.labels(page='/home', user_type='guest').inc(5)  # Increment by 5
```

**Querying**:
```promql
# Rate of requests per second
rate(http_requests_total[5m])

# Total requests in last hour
increase(http_requests_total[1h])
```

---

### Gauge

> Point-in-time value that can go up or down

**Use cases**:
- Current memory usage
- Temperature
- Number of active connections
- Queue size

```python
from prometheus_client import Gauge

active_users = Gauge(
    'active_users',
    'Currently active users',
    ['session_type']
)

# Set value
active_users.labels(session_type='web').set(42)

# Increment/decrement
active_users.labels(session_type='web').inc()
active_users.labels(session_type='web').dec()
active_users.labels(session_type='web').inc(5)
active_users.labels(session_type='web').dec(2)
```

**Querying**:
```promql
# Current value
active_users

# Average over time
avg_over_time(active_users[5m])

# Max in last hour
max_over_time(active_users[1h])
```

---

### Histogram

> Samples observations and counts them in configurable buckets

**Use cases**:
- Request duration
- Response size
- Query execution time

**Advantages**:
- Pre-aggregated percentiles
- Efficient storage
- Aggregatable across instances

```python
from prometheus_client import Histogram

request_duration = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration',
    ['method', 'endpoint'],
    buckets=[0.01, 0.05, 0.1, 0.5, 1.0, 2.5, 5.0, 10.0]
)

# Observe value
request_duration.labels(method='GET', endpoint='/api').observe(0.35)

# Or use as timer
with request_duration.labels(method='POST', endpoint='/api').time():
    process_request()
```

**Generated metrics**:
```
http_request_duration_seconds_bucket{le="0.01"} 45
http_request_duration_seconds_bucket{le="0.05"} 124
http_request_duration_seconds_bucket{le="0.1"} 356
...
http_request_duration_seconds_sum 45.2
http_request_duration_seconds_count 500
```

---

### Summary

> Similar to histogram but calculates quantiles on client side

**Use cases**:
- When you need exact quantiles
- When bucket boundaries are unknown

**Disadvantages**:
- Cannot be aggregated
- Higher CPU/memory usage

```python
from prometheus_client import Summary

request_latency = Summary(
    'request_latency_seconds',
    'Request latency',
    ['endpoint']
)

request_latency.labels(endpoint='/api').observe(0.25)
```

**Generated metrics**:
```
request_latency_seconds{endpoint="/api",quantile="0.5"} 0.25
request_latency_seconds{endpoint="/api",quantile="0.9"} 0.45
request_latency_seconds{endpoint="/api",quantile="0.99"} 0.95
request_latency_seconds_sum{endpoint="/api"} 124.5
request_latency_seconds_count{endpoint="/api"} 500
```

---

## Pull vs Push Models

### Pull Model (Prometheus)

**How it works**:
```
Prometheus ──(scrape HTTP /metrics)──> Application
           <───(metrics response)─────
```

**Advantages**:
- Simple to debug (curl /metrics)
- Applications don't need to know about Prometheus
- Automatic service discovery
- Prometheus controls scrape frequency

**When to use**:
- Kubernetes environments
- Long-running services
- When you have service discovery

---

### Push Model (Pushgateway, Remote Write)

**How it works**:
```
Application ──(push metrics)──> Pushgateway/Remote Write
Prometheus ──(scrape)──────────> Pushgateway
```

**Advantages**:
- Works for batch jobs
- Supports dynamic/ephemeral services
- No need to expose /metrics endpoint

**When to use**:
- Batch/cron jobs
- Serverless functions
- Behind firewalls/NAT

---

### Hybrid Approach

```python
# Support both pull and push
from prometheus_client import (
    CollectorRegistry,
    Counter,
    push_to_gateway,
    start_http_server
)

# Create registry
registry = CollectorRegistry()

# Create metrics
job_duration = Counter(
    'batch_job_duration_seconds',
    'Batch job duration',
    registry=registry
)

# Option 1: Pull model (long-running service)
def run_service():
    start_http_server(8000, registry=registry)  # Expose /metrics
    while True:
        process_requests()

# Option 2: Push model (batch job)
def run_batch_job():
    start_time = time.time()
    process_data()
    
    duration = time.time() - start_time
    job_duration.inc(duration)
    
    # Push to gateway when job completes
    push_to_gateway(
        'pushgateway:9091',
        job='batch-processor',
        registry=registry
    )
```

---

## OpenMetrics Standard

### What is OpenMetrics?

> A standardization of the Prometheus exposition format

**Key improvements**:
- Official IANA media type: `application/openmetrics-text`
- Better type safety
- Explicit EOF marker
- Support for exemplars
- Standardized metadata

### Example

```
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",path="/api"} 1234 1638360000
http_requests_total{method="POST",path="/api"} 567 1638360000
# EOF
```

### With Exemplars

```
# HELP http_request_duration_seconds Request duration
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{le="0.1"} 245 # {trace_id="abc123"} 0.05
http_request_duration_seconds_bucket{le="0.5"} 456
http_request_duration_seconds_sum 125.4
http_request_duration_seconds_count 500
# EOF
```

---

## Cardinality Management

### What is Cardinality?

> Number of unique time series

```
Cardinality = Metric Name × Label Combinations

http_requests_total{method, endpoint, status}

If:
- 3 methods (GET, POST, DELETE)
- 10 endpoints
- 5 status codes

Cardinality = 1 × 3 × 10 × 5 = 150 time series
```

---

### Cardinality Explosion

**Problem**: Unbounded label values

```python
# BAD: User ID as label (millions of unique values)
requests.labels(user_id=user_id).inc()

# Result: Millions of time series, out of memory
```

**Solution**: Limit label cardinality

```python
# GOOD: User tier as label (limited values)
user_tier = get_user_tier(user_id)  # "free", "pro", "enterprise"
requests.labels(user_tier=user_tier).inc()

# Result: Only 3 time series
```

---

### Best Practices for Labels

**DO**:
- Use labels with known, limited values
- Aggregate detailed data in logs/traces
- Use consistent naming

**DON'T**:
- Use user IDs as labels
- Use timestamps as labels
- Use unbounded strings (full URLs, email addresses)

```python
# Good label choices
good_labels = [
    'environment',    # dev, staging, prod
    'region',        # us-west, eu-central
    'tier',          # free, pro, enterprise
    'http_method',   # GET, POST, PUT, DELETE
    'status_class',  # 2xx, 4xx, 5xx
]

# Bad label choices (high cardinality)
bad_labels = [
    'user_id',       # Millions of unique values
    'request_id',    # Unique per request
    'full_url',      # Unbounded
    'email',         # Millions of unique values
    'timestamp',     # Infinite
]
```

---

## Naming Conventions

### Metric Names

Follow Prometheus naming conventions:

```
<namespace>_<subsystem>_<name>_<unit>

Examples:
- http_requests_total
- process_cpu_seconds_total
- database_query_duration_seconds
- cache_hits_total
```

**Rules**:
- Use `_total` suffix for counters
- Use base units (seconds, bytes, not milliseconds or megabytes)
- Be consistent across your organization

---

### Label Names

```
<aspect>="<value>"

Examples:
- method="GET"
- status="200"
- region="us-west-2"
```

**Rules**:
- Use snake_case
- Keep names descriptive but concise
- Avoid redundant prefixes

---

## Multi-Tenant Metrics

### Tenant Isolation

```python
from prometheus_client import Counter

requests_by_tenant = Counter(
    'api_requests_total',
    'API requests by tenant',
    ['tenant_id', 'endpoint']
)

async def handle_request(tenant_id: str, endpoint: str):
    requests_by_tenant.labels(
        tenant_id=tenant_id,
        endpoint=endpoint
    ).inc()
    
    # Process request...
```

### Tenant-Aware Queries

```promql
# Requests per tenant
sum(rate(api_requests_total[5m])) by (tenant_id)

# Top 10 tenants by request volume
topk(10, sum(rate(api_requests_total[5m])) by (tenant_id))

# Requests for specific tenant
sum(rate(api_requests_total{tenant_id="tenant-123"}[5m]))
```

---

## Best Practices Summary

### 1. Start with the Four Golden Signals

✅ Latency, Traffic, Errors, Saturation

### 2. Choose the Right Metric Type

- **Counter**: Cumulative values (requests, errors)
- **Gauge**: Current values (memory, connections)
- **Histogram**: Distributions (latency, size)
- **Summary**: Exact quantiles (when needed)

### 3. Manage Cardinality

- Limit label values
- Use aggregation
- Monitor metric count

### 4. Follow Naming Conventions

- Consistent naming
- Use base units
- Descriptive labels

### 5. Plan for Scale

- Consider multi-tenancy
- Use federation if needed
- Archive old data

---

## Example: Complete Service Instrumentation

```python
from prometheus_client import Counter, Histogram, Gauge, Info
import time

class ServiceMetrics:
    """Complete metrics for a cloud-native service"""
    
    def __init__(self, service_name: str):
        # Service info
        self.info = Info(
            f'{service_name}_info',
            'Service information'
        )
        self.info.info({
            'version': '1.0.0',
            'environment': 'production'
        })
        
        # Golden Signals: Traffic
        self.requests_total = Counter(
            f'{service_name}_requests_total',
            'Total requests',
            ['method', 'endpoint', 'status']
        )
        
        # Golden Signals: Latency
        self.request_duration = Histogram(
            f'{service_name}_request_duration_seconds',
            'Request duration',
            ['method', 'endpoint'],
            buckets=[0.01, 0.05, 0.1, 0.5, 1.0, 2.5, 5.0]
        )
        
        # Golden Signals: Errors
        self.errors_total = Counter(
            f'{service_name}_errors_total',
            'Total errors',
            ['method', 'endpoint', 'error_type']
        )
        
        # Golden Signals: Saturation
        self.active_requests = Gauge(
            f'{service_name}_active_requests',
            'Currently active requests'
        )
        
        # Business metrics
        self.items_processed = Counter(
            f'{service_name}_items_processed_total',
            'Total items processed',
            ['item_type']
        )
    
    async def track_request(self, method: str, endpoint: str):
        """Track request with all metrics"""
        self.active_requests.inc()
        start_time = time.time()
        
        try:
            # Process request
            yield
            
            # Success
            status = '200'
            self.requests_total.labels(
                method=method,
                endpoint=endpoint,
                status=status
            ).inc()
            
        except Exception as e:
            # Error
            status = '500'
            self.requests_total.labels(
                method=method,
                endpoint=endpoint,
                status=status
            ).inc()
            
            self.errors_total.labels(
                method=method,
                endpoint=endpoint,
                error_type=type(e).__name__
            ).inc()
            
            raise
            
        finally:
            # Latency
            duration = time.time() - start_time
            self.request_duration.labels(
                method=method,
                endpoint=endpoint
            ).observe(duration)
            
            self.active_requests.dec()
```

---

## Key Takeaways

1. **Four Golden Signals** are foundation of monitoring
2. **RED** for services, **USE** for resources
3. Choose **metric types** carefully
4. **Manage cardinality** to avoid explosion
5. Follow **naming conventions**
6. Plan for **scale and multi-tenancy**

---

## Next: Advanced Data Collection

In the next lecture:
- Custom collectors
- Service discovery
- Federation patterns
- Long-term storage

---

**Questions?**

---

**End of Lecture**
