# Kagent Architecture Deep Dive

**Module 1 - Lecture 2**  
**Duration**: 45 minutes

---

## What is Kagent?

### Kagent Framework

> A comprehensive framework for building, deploying, and managing MCP servers in Kubernetes environments

**Key Features**:
- **Agent Management**: Lifecycle management for MCP servers
- **Tool Registry**: Centralized tool discovery and execution
- **Security**: Built-in RBAC and authentication
- **Scalability**: Production-ready deployment patterns
- **Observability**: Integrated monitoring and metrics

---

## Why Kagent?

### Challenges Without Kagent

- **Manual Deployment**: No standardized deployment process
- **No Discovery**: Hard to find available tools
- **Security Gaps**: Each server implements auth differently
- **Monitoring Chaos**: No unified observability
- **Scaling Issues**: Difficult to scale MCP servers

### Kagent Solutions

- **Kubernetes Native**: Deploy as K8s resources
- **Service Discovery**: Automatic tool registration
- **Built-in Security**: OAuth 2.0, RBAC, mTLS
- **Unified Monitoring**: Prometheus integration
- **Horizontal Scaling**: Standard K8s autoscaling

---

## Kagent Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│              Kubernetes Cluster                          │
│                                                          │
│  ┌────────────────────────────────────────────────┐     │
│  │         Kagent Controller (Operator)           │     │
│  │  - Watch MCP CRDs                              │     │
│  │  - Reconcile desired state                     │     │
│  │  - Manage agent lifecycle                      │     │
│  └─────────────────┬──────────────────────────────┘     │
│                    │                                     │
│  ┌─────────────────▼──────────────────────────────┐     │
│  │           Agent Gateway (Proxy)                │     │
│  │  - Route requests to agents                    │     │
│  │  - Authentication & Authorization              │     │
│  │  - Rate limiting                               │     │
│  │  - Load balancing                              │     │
│  └─────────────────┬──────────────────────────────┘     │
│                    │                                     │
│       ┌────────────┼────────────┐                       │
│       │            │            │                       │
│  ┌────▼─────┐ ┌───▼──────┐ ┌──▼───────┐               │
│  │ MCP      │ │ MCP      │ │ MCP      │               │
│  │ Server 1 │ │ Server 2 │ │ Server 3 │               │
│  │ (Pod)    │ │ (Pod)    │ │ (Pod)    │               │
│  └──────────┘ └──────────┘ └──────────┘               │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. Kagent Controller

**Role**: Kubernetes Operator that manages MCP server lifecycle

**Responsibilities**:
- Watch for MCPAgent custom resources
- Create/update/delete MCP server pods
- Manage service discovery
- Handle scaling
- Monitor health

**Implementation**:
```python
# Simplified controller logic
async def reconcile(agent: MCPAgent):
    desired_state = agent.spec
    current_state = get_current_state(agent)
    
    if current_state != desired_state:
        apply_changes(agent, desired_state)
```

---

### 2. Agent Gateway

**Role**: Central entry point for all MCP requests

**Capabilities**:
- **Routing**: Direct requests to appropriate MCP servers
- **Authentication**: Validate client credentials
- **Authorization**: Check permissions
- **Rate Limiting**: Prevent abuse
- **Metrics**: Track usage
- **Caching**: Improve performance

---

### 3. MCP Servers (Agents)

**Role**: Individual MCP server instances running in pods

**Characteristics**:
- **Stateless**: Can be scaled horizontally
- **Specialized**: Each can focus on specific domains
- **Isolated**: Run in separate containers
- **Discoverable**: Register with controller

---

## Tool Registry

### How Tool Discovery Works

```
1. MCP Server starts
   │
   ├──> Registers with Kagent Controller
   │    - Tool definitions
   │    - Capabilities
   │    - Health endpoint
   │
2. Controller updates registry
   │
   ├──> Makes tools available in gateway
   │
3. Client requests available tools
   │
   ├──> Gateway returns aggregated list
   │
4. Client calls specific tool
   │
   └──> Gateway routes to correct server
```

---

### Tool Registration Example

```yaml
apiVersion: mcp.kagent.io/v1alpha1
kind: MCPAgent
metadata:
  name: k8s-diagnostics
spec:
  tools:
    - name: diagnose_pod
      description: "Diagnose pod health issues"
      inputSchema:
        type: object
        properties:
          namespace: {type: string}
          pod_name: {type: string}
    - name: get_pod_logs
      description: "Retrieve pod logs"
      inputSchema:
        type: object
        properties:
          namespace: {type: string}
          pod_name: {type: string}
          tail_lines: {type: integer}
  replicas: 3
  image: "mcp-k8s-diagnostics:v1.0.0"
```

---

## Agent Lifecycle

### 1. Registration Phase

```python
# Agent startup
async def register_agent():
    await controller.register(
        agent_id="k8s-diagnostics-abc123",
        tools=get_tool_definitions(),
        health_endpoint="http://pod-ip:8080/health"
    )
```

### 2. Active Phase

```python
# Handle requests
async def handle_request(request):
    tool = request.tool_name
    result = await execute_tool(tool, request.arguments)
    return result
```

### 3. Deregistration Phase

```python
# Graceful shutdown
async def shutdown():
    await controller.deregister(agent_id)
    await cleanup_resources()
```

---

## State Management

### Agent State

```python
@dataclass
class AgentState:
    agent_id: str
    status: str  # "pending", "running", "terminating"
    tools: List[ToolDefinition]
    replicas: int
    healthy_replicas: int
    last_heartbeat: datetime
    metadata: Dict[str, Any]
```

### State Persistence

- **etcd**: Kubernetes native storage
- **Custom Resources**: Declarative state
- **ConfigMaps/Secrets**: Configuration data

---

## Security Model

### Three Layers of Security

1. **Network Security**
   - Network policies
   - Service mesh (mTLS)
   - Ingress controllers

2. **Authentication**
   - OAuth 2.0 / OIDC
   - Service account tokens
   - API keys

3. **Authorization**
   - RBAC (Kubernetes native)
   - OPA policies
   - Custom authorization

---

### RBAC Example

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: mcp-agent-role
rules:
  # What the MCP server can do
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list"]
  
  # Cannot delete or create
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["delete", "create"]
    # NOT in this role
```

---

### Permission Scoping

```python
# Tool-level permissions
@tool(
    name="delete_pod",
    required_permissions=["pods:delete"]
)
async def delete_pod(namespace, pod_name):
    # Only users with pods:delete permission can call
    pass

# Namespace isolation
@tool(
    name="list_pods",
    allowed_namespaces=["team-a", "team-b"]
)
async def list_pods(namespace):
    # Can only access allowed namespaces
    pass
```

---

## Scalability Patterns

### Horizontal Scaling

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: mcp-agent-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: mcp-agent
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

---

### Load Balancing Strategies

1. **Round Robin** (default)
   ```
   Request 1 → Server 1
   Request 2 → Server 2
   Request 3 → Server 3
   Request 4 → Server 1
   ```

2. **Least Connections**
   ```
   Choose server with fewest active requests
   ```

3. **Weighted**
   ```
   Distribute based on server capacity
   Server 1 (4 cores): 40% traffic
   Server 2 (6 cores): 60% traffic
   ```

---

## Communication Patterns

### Request-Response

```
Client ──(request)──> Gateway ──> MCP Server
Client <─(response)── Gateway <── MCP Server
```

### Streaming

```
Client ──(request)──> Gateway ──> MCP Server
Client <─(chunk 1)─── Gateway <── MCP Server
Client <─(chunk 2)─── Gateway <── MCP Server
Client <─(chunk 3)─── Gateway <── MCP Server
Client <─(done)────── Gateway <── MCP Server
```

### Pub/Sub (Events)

```
MCP Server ──(event)──> Event Bus
Event Bus ──(notify)──> Subscribed Clients
```

---

## Tool Execution Flow

```
1. Client sends request
   ├─> Gateway receives
   │
2. Gateway authenticates client
   ├─> Check credentials
   ├─> Validate permissions
   │
3. Gateway finds appropriate server
   ├─> Lookup in registry
   ├─> Check server health
   ├─> Apply load balancing
   │
4. Route request to server
   ├─> Execute tool
   ├─> Generate response
   │
5. Return response to client
   └─> Track metrics
```

---

## Error Handling

### Retry Logic

```python
async def call_tool_with_retry(
    tool_name: str,
    arguments: dict,
    max_retries: int = 3
):
    for attempt in range(max_retries):
        try:
            return await call_tool(tool_name, arguments)
        except TemporaryError as e:
            if attempt < max_retries - 1:
                await asyncio.sleep(2 ** attempt)  # Exponential backoff
                continue
            raise
        except PermanentError:
            raise  # Don't retry permanent errors
```

---

### Circuit Breaker

```python
class CircuitBreaker:
    def __init__(self, threshold=5, timeout=60):
        self.failures = 0
        self.threshold = threshold
        self.state = "closed"  # closed, open, half-open
    
    async def call(self, func):
        if self.state == "open":
            raise CircuitOpenError()
        
        try:
            result = await func()
            self.on_success()
            return result
        except Exception:
            self.on_failure()
            raise
    
    def on_failure(self):
        self.failures += 1
        if self.failures >= self.threshold:
            self.state = "open"
```

---

## Monitoring & Observability

### Key Metrics

```python
# Agent health
agent_healthy = Gauge('agent_healthy', 'Agent health status')

# Request metrics
requests_total = Counter('requests_total', 'Total requests', ['agent', 'tool'])
request_duration = Histogram('request_duration_seconds', 'Request duration')

# Resource usage
cpu_usage = Gauge('cpu_usage_percent', 'CPU usage percentage')
memory_usage = Gauge('memory_usage_bytes', 'Memory usage in bytes')

# Business metrics
tools_executed = Counter('tools_executed_total', 'Tools executed', ['tool'])
```

---

### Distributed Tracing

```python
from opentelemetry import trace

tracer = trace.get_tracer(__name__)

async def handle_request(request):
    with tracer.start_as_current_span("handle_request") as span:
        span.set_attribute("tool_name", request.tool_name)
        
        with tracer.start_as_current_span("validate_input"):
            validate_input(request.arguments)
        
        with tracer.start_as_current_span("execute_tool"):
            result = await execute_tool(request.tool_name, request.arguments)
        
        return result
```

---

## Multi-Agent Coordination

### Agent Specialization

```
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│  Diagnostics     │  │  Remediation     │  │  Monitoring      │
│  Agent           │  │  Agent           │  │  Agent           │
│                  │  │                  │  │                  │
│ - diagnose_pod   │  │ - restart_pod    │  │ - get_metrics    │
│ - check_logs     │  │ - scale_deploy   │  │ - create_alert   │
│ - analyze_events │  │ - rollback       │  │ - query_logs     │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

### Agent Collaboration

```python
# Diagnostics agent finds issue
diagnosis = await diagnostics_agent.diagnose_pod(namespace, pod)

# If issue found, call remediation agent
if diagnosis.has_issues:
    await remediation_agent.auto_heal(
        namespace=namespace,
        pod=pod,
        diagnosis=diagnosis
    )

# Notify monitoring agent
await monitoring_agent.create_alert(
    severity="warning",
    message=f"Auto-healed pod {pod}"
)
```

---

## Development vs Production

### Development Mode (kmcp CLI)

**Characteristics**:
- Local execution
- Quick iteration
- Debug friendly
- No Kubernetes required

**Usage**:
```bash
# Start local MCP server
kmcp dev run my-server.py

# Test tools
kmcp dev test --tool diagnose_pod --args '{"pod": "test"}'

# View logs
kmcp dev logs
```

---

### Production Mode (Kagent Controller)

**Characteristics**:
- Kubernetes native
- High availability
- Auto-scaling
- Production security

**Deployment**:
```yaml
# Deploy MCP Agent
kubectl apply -f mcp-agent.yaml

# Controller handles:
# - Pod creation
# - Service discovery
# - Health monitoring
# - Scaling
```

---

## Configuration Management

### Agent Configuration

```yaml
apiVersion: mcp.kagent.io/v1alpha1
kind: MCPAgentConfig
metadata:
  name: k8s-diagnostics-config
spec:
  # Runtime config
  logLevel: INFO
  metricsPort: 9090
  
  # Resource limits
  resources:
    requests:
      memory: "256Mi"
      cpu: "100m"
    limits:
      memory: "512Mi"
      cpu: "500m"
  
  # Environment variables
  env:
    - name: K8S_NAMESPACE
      value: "default"
    - name: CACHE_TTL
      value: "300"
  
  # Secrets
  secretRefs:
    - name: mcp-credentials
```

---

## Best Practices

### 1. Agent Design

- **Single Responsibility**: One domain per agent
- **Stateless**: Store state externally
- **Idempotent Tools**: Safe to retry
- **Fast Startup**: Quick initialization

### 2. Scalability

- **Horizontal Scaling**: Add more pods
- **Resource Limits**: Set appropriate limits
- **Connection Pooling**: Reuse connections
- **Caching**: Cache expensive operations

### 3. Security

- **Least Privilege**: Minimal RBAC permissions
- **Input Validation**: Always validate
- **Audit Logging**: Track all operations
- **Secret Management**: Use Kubernetes secrets

---

## Common Patterns

### Pattern 1: Command Pattern

```python
class Command:
    async def execute(self): pass
    async def undo(self): pass

class RestartPodCommand(Command):
    async def execute(self):
        await k8s.delete_pod(self.pod)
    
    async def undo(self):
        await k8s.create_pod(self.pod_spec)
```

### Pattern 2: Chain of Responsibility

```python
async def handle_request(request):
    handlers = [
        AuthenticationHandler(),
        AuthorizationHandler(),
        ValidationHandler(),
        ExecutionHandler()
    ]
    
    for handler in handlers:
        request = await handler.handle(request)
    
    return request
```

---

## Demo: Deploy Kagent Agent

```yaml
# 1. Create MCPAgent resource
apiVersion: mcp.kagent.io/v1alpha1
kind: MCPAgent
metadata:
  name: hello-agent
spec:
  image: mcp-hello-server:v1.0.0
  replicas: 2
  tools:
    - name: hello_world
      description: "Say hello"
  ports:
    - name: metrics
      port: 9090

---
# 2. Controller reconciles
# - Creates Deployment
# - Creates Service
# - Registers tools
# - Configures monitoring

---
# 3. Agent is ready
# kubectl get mcpagent hello-agent
# NAME          STATUS   REPLICAS   READY
# hello-agent   Ready    2          2
```

---

## Key Takeaways

1. **Kagent = MCP + Kubernetes** native integration
2. **Controller manages lifecycle** automatically
3. **Gateway provides central access** point
4. **Security is built-in** with RBAC and authentication
5. **Scalability** through standard K8s patterns
6. **Observability** with Prometheus and tracing
7. **Development and production** modes supported

---

## Questions?

### Resources

- Kagent Documentation: [kagent.io/docs](https://kagent.io/docs)
- GitHub: [github.com/kagent-io](https://github.com/kagent-io)
- Examples: Course materials `/day-1/examples`

---

## Next: Development vs Production

In the next lecture:
- kmcp CLI deep dive
- Local development workflow
- Production deployment patterns
- Configuration management

**Break**: 15 minutes

---

**End of Lecture 2**
