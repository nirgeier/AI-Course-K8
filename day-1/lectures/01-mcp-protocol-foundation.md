nirgeier: Create git hub repo locallly, then create Github repo under nirgeir account usign GITHUB mcp, push the code to the remote repo

GitHub Copilot: # MCP Protocol Foundation

**Module 1 - Lecture 1**  
**Duration**: 45 minutes

---

## What is MCP?

### Model Context Protocol (MCP)

> An open protocol that standardizes how applications provide context to Large Language Models (LLMs)

**Key Purpose**: Enable AI models to securely access data and tools from various sources

---

## Why MCP Matters

### The Problem

- **Data Silos**: AI models can't easily access external data
- **Custom Integrations**: Each tool requires unique integration
- **Security Concerns**: No standard for safe data access
- **Scalability Issues**: Hard to maintain many integrations

### The Solution: MCP

- **Standardized Protocol**: One way to connect everything
- **Security First**: Built-in authentication and permissions
- **Extensible**: Easy to add new data sources and tools
- **Interoperable**: Works across different AI platforms

---

## MCP Architecture

```
┌─────────────────────────────────────────────────┐
│                 AI Application                   │
│            (ChatGPT, Claude, etc.)              │
└───────────────────┬─────────────────────────────┘
                    │
                    │ MCP Protocol
                    │ (JSON-RPC 2.0)
                    │
┌───────────────────▼─────────────────────────────┐
│              MCP Server (Host)                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │Resources │  │  Tools   │  │ Prompts  │      │
│  └──────────┘  └──────────┘  └──────────┘      │
└───────────────────┬─────────────────────────────┘
                    │
          ┌─────────┼─────────┐
          │         │         │
┌─────────▼──┐ ┌───▼────┐ ┌─▼────────┐
│ Database   │ │  API   │ │  Files   │
└────────────┘ └────────┘ └──────────┘
```

---

## Core Concepts

### 1. Resources

**Definition**: Data or content that can be read by AI models

**Examples**:
- Database records
- File contents
- API responses
- Log entries

**Characteristics**:
- Read-only access
- Identified by URI
- Can be text or binary
- Supports templating

---

### 2. Tools

**Definition**: Functions that AI models can execute to perform actions

**Examples**:
- Query a database
- Send an email
- Restart a pod
- Create a file

**Characteristics**:
- Executable actions
- Defined input schema
- Return structured output
- Can modify state

---

### 3. Prompts

**Definition**: Pre-defined templates that guide AI model interactions

**Examples**:
- "Analyze this log file"
- "Troubleshoot pod issues"
- "Generate deployment YAML"

**Characteristics**:
- Reusable templates
- Can include resources
- Guide AI behavior
- Improve consistency

---

## JSON-RPC 2.0 Foundation

### What is JSON-RPC?

A lightweight remote procedure call protocol using JSON

### Message Format

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "get_pod_status",
    "arguments": {
      "namespace": "default",
      "pod_name": "nginx-123"
    }
  }
}
```

### Response Format

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "status": "Running",
    "ready": true,
    "restarts": 0
  }
}
```

---

## Transport Layers

### 1. Standard I/O (stdio)

**Use Case**: Local development, CLI tools

```python
# Server reads from stdin, writes to stdout
async with stdio_server() as (read_stream, write_stream):
    await server.run(read_stream, write_stream)
```

**Advantages**:
- Simple to implement
- No network configuration
- Good for testing

---

### 2. HTTP/SSE

**Use Case**: Production deployments, web applications

```python
# Server listens on HTTP endpoint
app = FastAPI()

@app.post("/mcp")
async def handle_mcp_request(request: Request):
    return await mcp_handler(request)
```

**Advantages**:
- Standard web protocols
- Works through firewalls
- Scalable

---

## Client-Server Architecture

### Server Role

1. **Expose Capabilities**: Advertise available resources, tools, prompts
2. **Handle Requests**: Process calls from clients
3. **Manage State**: Track sessions and connections
4. **Ensure Security**: Validate permissions

### Client Role

1. **Discover Capabilities**: Query server for available features
2. **Make Requests**: Call tools, fetch resources
3. **Handle Responses**: Process results
4. **Manage Context**: Maintain conversation state

---

## Bidirectional Communication

### Server → Client

- **Progress Updates**: Long-running operations
- **Logging**: Debug information
- **Notifications**: State changes

### Client → Server

- **Tool Calls**: Execute functions
- **Resource Requests**: Fetch data
- **Capability Discovery**: List available features

---

## Message Types

### 1. Requests

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list"
}
```

**Characteristics**:
- Always has an `id`
- Expects a response
- Can timeout

---

### 2. Responses

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "tools": [...]
  }
}
```

**Characteristics**:
- Matches request `id`
- Contains `result` or `error`
- Completes the request cycle

---

### 3. Notifications

```json
{
  "jsonrpc": "2.0",
  "method": "notifications/progress",
  "params": {
    "progressToken": "abc123",
    "progress": 50,
    "total": 100
  }
}
```

**Characteristics**:
- No `id` field
- No response expected
- Fire-and-forget

---

## MCP Lifecycle

### 1. Initialization

```
Client                          Server
  │                               │
  ├──── initialize ──────────────>│
  │                               │
  │<──── capabilities ────────────┤
  │                               │
  ├──── initialized ─────────────>│
  │                               │
```

### 2. Operation

```
  │                               │
  ├──── tools/list ──────────────>│
  │<──── tool definitions ────────┤
  │                               │
  ├──── tools/call ──────────────>│
  │<──── result ──────────────────┤
  │                               │
```

### 3. Shutdown

```
  │                               │
  ├──── shutdown ────────────────>│
  │<──── acknowledged ────────────┤
  │                               │
```

---

## Tool Definition Example

```json
{
  "name": "get_pod_logs",
  "description": "Retrieve logs from a Kubernetes pod",
  "inputSchema": {
    "type": "object",
    "properties": {
      "namespace": {
        "type": "string",
        "description": "Kubernetes namespace"
      },
      "pod_name": {
        "type": "string",
        "description": "Name of the pod"
      },
      "tail_lines": {
        "type": "integer",
        "description": "Number of lines to retrieve",
        "default": 100
      }
    },
    "required": ["namespace", "pod_name"]
  }
}
```

---

## Resource Definition Example

```json
{
  "uri": "k8s://pods/default/nginx-123",
  "name": "Pod nginx-123",
  "description": "Status and details of nginx-123 pod",
  "mimeType": "application/json"
}
```

**Resource Content**:
```json
{
  "name": "nginx-123",
  "namespace": "default",
  "status": "Running",
  "ip": "10.244.0.5",
  "containers": [...]
}
```

---

## Security Considerations

### Authentication

- Server validates client identity
- Token-based auth recommended
- Support for OAuth 2.0

### Authorization

- Fine-grained permissions per tool
- Resource-level access control
- Audit logging

### Input Validation

- Schema validation for all inputs
- Sanitize user-provided data
- Rate limiting

---

## MCP in Kubernetes Context

### Use Cases

1. **Pod Management**
   - List, create, delete pods
   - Get pod logs and status
   - Execute commands in pods

2. **Cluster Operations**
   - Scale deployments
   - Roll out updates
   - Monitor resources

3. **Troubleshooting**
   - Diagnose failures
   - Analyze logs
   - Check resource usage

---

## Example: Pod Status Tool

### Tool Definition

```python
@server.list_tools()
async def list_tools():
    return [{
        "name": "get_pod_status",
        "description": "Get the status of a Kubernetes pod",
        "inputSchema": {
            "type": "object",
            "properties": {
                "namespace": {"type": "string"},
                "pod_name": {"type": "string"}
            },
            "required": ["namespace", "pod_name"]
        }
    }]
```

---

### Tool Implementation

```python
@server.call_tool()
async def call_tool(name: str, arguments: dict):
    if name == "get_pod_status":
        namespace = arguments["namespace"]
        pod_name = arguments["pod_name"]
        
        # Get pod from Kubernetes API
        v1 = client.CoreV1Api()
        pod = v1.read_namespaced_pod(pod_name, namespace)
        
        return {
            "status": pod.status.phase,
            "ready": all(c.ready for c in pod.status.container_statuses),
            "restarts": sum(c.restart_count for c in pod.status.container_statuses)
        }
```

---

## Benefits of MCP

### For Developers

- **Standardized Interface**: Learn once, use everywhere
- **Reduced Complexity**: No custom integrations
- **Better Testing**: Clear contract between client and server
- **Improved Security**: Built-in best practices

### For AI Applications

- **Rich Context**: Access to diverse data sources
- **Actionable**: Can execute operations
- **Consistent**: Predictable behavior
- **Extensible**: Easy to add capabilities

---

## MCP vs. Other Protocols

| Feature | MCP | REST API | GraphQL |
|---------|-----|----------|---------|
| Purpose | AI context | Data access | Data query |
| Protocol | JSON-RPC 2.0 | HTTP | HTTP |
| Schema | Required | Optional | Required |
| Tools | Native | N/A | N/A |
| Bidirectional | Yes | No | Subscriptions |
| AI-Optimized | Yes | No | No |

---

## Best Practices

### Tool Design

1. **Single Responsibility**: One tool, one purpose
2. **Clear Naming**: Descriptive, consistent names
3. **Comprehensive Schema**: Document all parameters
4. **Idempotent**: Same input → same output
5. **Error Handling**: Return structured errors

### Resource Design

1. **Stable URIs**: Don't change resource identifiers
2. **Efficient**: Don't fetch unnecessary data
3. **Cacheable**: Support caching where appropriate
4. **Versioned**: Include version in URI if needed

---

## Common Patterns

### 1. CRUD Operations

- `create_*` - Create resources
- `get_*` - Read resources
- `update_*` - Update resources
- `delete_*` - Delete resources
- `list_*` - List resources

### 2. Batch Operations

```python
{
  "name": "batch_get_pods",
  "arguments": {
    "pod_names": ["pod-1", "pod-2", "pod-3"]
  }
}
```

### 3. Long-Running Operations

```python
# Return operation ID
{"operation_id": "op-123"}

# Poll for status
get_operation_status("op-123")
# Returns: {"status": "running", "progress": 50}
```

---

## Error Handling

### Standard Error Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32602,
    "message": "Invalid params",
    "data": {
      "field": "pod_name",
      "error": "Pod not found"
    }
  }
}
```

### Error Codes

- `-32700`: Parse error
- `-32600`: Invalid request
- `-32601`: Method not found
- `-32602`: Invalid params
- `-32603`: Internal error

---

## Demo: Simple MCP Server

```python
from mcp.server import Server
from mcp.server.stdio import stdio_server

server = Server("demo-server")

@server.list_tools()
async def list_tools():
    return [{
        "name": "hello",
        "description": "Say hello",
        "inputSchema": {
            "type": "object",
            "properties": {
                "name": {"type": "string"}
            }
        }
    }]

@server.call_tool()
async def call_tool(name: str, arguments: dict):
    if name == "hello":
        return {"message": f"Hello, {arguments['name']}!"}

# Run server
async def main():
    async with stdio_server() as (read, write):
        await server.run(read, write, server.create_initialization_options())
```

---

## Key Takeaways

1. **MCP is a standard protocol** for AI-context interaction
2. **Built on JSON-RPC 2.0** for simplicity and reliability
3. **Three core capabilities**: Resources, Tools, Prompts
4. **Bidirectional communication** enables rich interactions
5. **Security and validation** are built-in
6. **Perfect for Kubernetes** operations and automation

---

## Questions?

### Resources

- MCP Specification: [spec.modelcontextprotocol.io](https://spec.modelcontextprotocol.io)
- GitHub: [github.com/modelcontextprotocol](https://github.com/modelcontextprotocol)
- Examples: Course materials `/day-1/examples`

---

## Next: Kagent Architecture

In the next lecture, we'll explore:
- Kagent framework components
- Tool, Agent, and MCP relationships
- Lifecycle management
- Security and scalability

**Break**: 15 minutes

---

**End of Lecture 1**
