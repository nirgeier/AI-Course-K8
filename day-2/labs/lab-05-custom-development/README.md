# Lab 5: Custom MCP Server Development

**Duration**: 3.5 hours  
**Difficulty**: Advanced  
**Prerequisites**: Completed Labs 1-4

## Overview

Build a production-ready custom MCP server from scratch:

- Design and implement custom tools for Kubernetes operations
- Add resource management and caching
- Implement authentication and authorization
- Add comprehensive monitoring and tracing
- Package and deploy to Kubernetes

## Learning Objectives

By the end of this lab, you will be able to:

1. Design an MCP server architecture for complex use cases
2. Implement advanced tool patterns (async, streaming, batching)
3. Add production-grade error handling and resilience
4. Integrate authentication and RBAC
5. Deploy and scale MCP servers in Kubernetes

## Prerequisites

### Required Knowledge

- Python async programming
- Kubernetes API and kubectl
- MCP protocol fundamentals
- Prometheus metrics and tracing

### Required Tools

- Python 3.10+
- Kubernetes cluster
- Docker
- kubectl, Helm

## Lab Structure

```
lab-05-custom-development/
├── README.md
├── src/
│   ├── server.py
│   ├── tools/
│   │   ├── __init__.py
│   │   ├── diagnostics.py
│   │   ├── remediation.py
│   │   └── analysis.py
│   ├── auth/
│   │   ├── __init__.py
│   │   └── rbac.py
│   ├── cache.py
│   └── metrics.py
├── tests/
│   ├── test_tools.py
│   └── test_server.py
├── manifests/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── rbac.yaml
└── Dockerfile
```

## Part 1: Server Architecture (30 min)

### 1.1: Design the Server

We'll build a **Kubernetes Operations MCP Server** with three categories of tools:

1. **Diagnostics**: Analyze cluster and workload health
2. **Remediation**: Auto-heal common issues  
3. **Analysis**: Provide insights and recommendations

```python
# src/server.py
from typing import Any, Dict, List, Callable
from mcp.server import Server, NotificationOptions
from mcp.server.models import InitializationOptions
from mcp.types import (
    Tool,
    TextContent,
    ImageContent,
    EmbeddedResource,
)
import mcp.server.stdio
import logging
from kubernetes import client, config
from opentelemetry import trace

# Import custom tools
from tools.diagnostics import DiagnosticTools
from tools.remediation import RemediationTools
from tools.analysis import AnalysisTools
from cache import CacheManager
from metrics import ServerMetrics
from auth import RBACManager

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

tracer = trace.get_tracer(__name__)

class K8sOpsMCPServer:
    """Production MCP server for Kubernetes operations"""
    
    def __init__(self):
        self.server = Server("k8s-ops-mcp-server")
        self.metrics = ServerMetrics("k8s-ops")
        self.cache = CacheManager(ttl=300)
        self.rbac = RBACManager()
        
        # Initialize Kubernetes client
        try:
            config.load_incluster_config()
        except config.ConfigException:
            config.load_kube_config()
        
        self.k8s_core = client.CoreV1Api()
        self.k8s_apps = client.AppsV1Api()
        self.k8s_batch = client.BatchV1Api()
        
        # Initialize tool modules
        self.diagnostics = DiagnosticTools(
            self.k8s_core,
            self.k8s_apps,
            self.cache,
            self.metrics
        )
        self.remediation = RemediationTools(
            self.k8s_core,
            self.k8s_apps,
            self.cache,
            self.metrics
        )
        self.analysis = AnalysisTools(
            self.k8s_core,
            self.k8s_apps,
            self.k8s_batch,
            self.cache,
            self.metrics
        )
        
        self._register_handlers()
    
    def _register_handlers(self):
        """Register MCP handlers"""
        
        @self.server.list_tools()
        async def handle_list_tools() -> List[Tool]:
            """List all available tools"""
            with tracer.start_as_current_span("list_tools"):
                tools = []
                
                # Diagnostic tools
                tools.extend(self.diagnostics.get_tool_definitions())
                
                # Remediation tools
                tools.extend(self.remediation.get_tool_definitions())
                
                # Analysis tools
                tools.extend(self.analysis.get_tool_definitions())
                
                logger.info(f"Listing {len(tools)} tools")
                return tools
        
        @self.server.call_tool()
        async def handle_call_tool(
            name: str,
            arguments: Dict[str, Any]
        ) -> List[TextContent | ImageContent | EmbeddedResource]:
            """Execute a tool"""
            
            with tracer.start_as_current_span(
                "call_tool",
                attributes={"tool.name": name}
            ) as span:
                # Check authorization
                # In production, extract user from request context
                user = "admin"  # Placeholder
                
                if not self.rbac.is_authorized(user, name, arguments):
                    raise PermissionError(
                        f"User {user} not authorized for tool {name}"
                    )
                
                # Track metrics
                async with self.metrics.track_request(name):
                    # Route to appropriate tool module
                    if name.startswith("diagnose_"):
                        result = await self.diagnostics.execute(name, arguments)
                    elif name.startswith("remediate_"):
                        result = await self.remediation.execute(name, arguments)
                    elif name.startswith("analyze_"):
                        result = await self.analysis.execute(name, arguments)
                    else:
                        raise ValueError(f"Unknown tool: {name}")
                    
                    return [TextContent(
                        type="text",
                        text=str(result)
                    )]
    
    async def run(self):
        """Run the server"""
        async with mcp.server.stdio.stdio_server() as (read_stream, write_stream):
            await self.server.run(
                read_stream,
                write_stream,
                InitializationOptions(
                    server_name="k8s-ops-mcp-server",
                    server_version="1.0.0",
                    capabilities=self.server.get_capabilities(
                        notification_options=NotificationOptions(),
                        experimental_capabilities={}
                    )
                )
            )

if __name__ == "__main__":
    import asyncio
    server = K8sOpsMCPServer()
    asyncio.run(server.run())
```

### 1.2: Implement Diagnostic Tools

```python
# src/tools/diagnostics.py
from typing import Dict, Any, List
from mcp.types import Tool
from kubernetes import client
from opentelemetry import trace
import logging

logger = logging.getLogger(__name__)
tracer = trace.get_tracer(__name__)

class DiagnosticTools:
    """Diagnostic tools for Kubernetes"""
    
    def __init__(self, k8s_core, k8s_apps, cache, metrics):
        self.k8s_core = k8s_core
        self.k8s_apps = k8s_apps
        self.cache = cache
        self.metrics = metrics
    
    def get_tool_definitions(self) -> List[Tool]:
        """Return tool definitions"""
        return [
            Tool(
                name="diagnose_pod",
                description="Diagnose pod health and issues",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "namespace": {
                            "type": "string",
                            "description": "Namespace of the pod"
                        },
                        "pod_name": {
                            "type": "string",
                            "description": "Name of the pod"
                        },
                        "deep_analysis": {
                            "type": "boolean",
                            "description": "Perform deep analysis",
                            "default": False
                        }
                    },
                    "required": ["namespace", "pod_name"]
                }
            ),
            Tool(
                name="diagnose_deployment",
                description="Diagnose deployment issues",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "namespace": {"type": "string"},
                        "deployment_name": {"type": "string"}
                    },
                    "required": ["namespace", "deployment_name"]
                }
            ),
            Tool(
                name="diagnose_service",
                description="Diagnose service connectivity",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "namespace": {"type": "string"},
                        "service_name": {"type": "string"}
                    },
                    "required": ["namespace", "service_name"]
                }
            )
        ]
    
    async def execute(self, name: str, arguments: Dict[str, Any]) -> Dict:
        """Execute diagnostic tool"""
        
        if name == "diagnose_pod":
            return await self._diagnose_pod(
                arguments["namespace"],
                arguments["pod_name"],
                arguments.get("deep_analysis", False)
            )
        elif name == "diagnose_deployment":
            return await self._diagnose_deployment(
                arguments["namespace"],
                arguments["deployment_name"]
            )
        elif name == "diagnose_service":
            return await self._diagnose_service(
                arguments["namespace"],
                arguments["service_name"]
            )
        else:
            raise ValueError(f"Unknown diagnostic tool: {name}")
    
    async def _diagnose_pod(
        self,
        namespace: str,
        pod_name: str,
        deep_analysis: bool = False
    ) -> Dict:
        """Diagnose pod issues"""
        
        with tracer.start_as_current_span("diagnose_pod") as span:
            span.set_attribute("k8s.namespace", namespace)
            span.set_attribute("k8s.pod_name", pod_name)
            
            # Check cache first
            cache_key = f"pod_diagnosis:{namespace}:{pod_name}"
            cached = await self.cache.get(cache_key)
            if cached and not deep_analysis:
                self.metrics.cache_hits.inc()
                return cached
            
            self.metrics.cache_misses.inc()
            
            diagnosis = {
                "pod_name": pod_name,
                "namespace": namespace,
                "issues": [],
                "recommendations": [],
                "status": {}
            }
            
            try:
                # Get pod
                with tracer.start_as_current_span("k8s.get_pod"):
                    pod = self.k8s_core.read_namespaced_pod(
                        name=pod_name,
                        namespace=namespace
                    )
                
                # Basic status
                diagnosis["status"] = {
                    "phase": pod.status.phase,
                    "conditions": [
                        {
                            "type": c.type,
                            "status": c.status,
                            "reason": c.reason,
                            "message": c.message
                        }
                        for c in (pod.status.conditions or [])
                    ]
                }
                
                # Check for common issues
                await self._check_pod_issues(pod, diagnosis)
                
                # Get recent events
                with tracer.start_as_current_span("k8s.get_events"):
                    events = self.k8s_core.list_namespaced_event(
                        namespace=namespace,
                        field_selector=f"involvedObject.name={pod_name}"
                    )
                    
                    # Check for warning events
                    warnings = [
                        e for e in events.items
                        if e.type == "Warning"
                    ]
                    
                    if warnings:
                        diagnosis["issues"].append({
                            "type": "warning_events",
                            "severity": "medium",
                            "count": len(warnings),
                            "recent": [
                                {
                                    "reason": e.reason,
                                    "message": e.message,
                                    "count": e.count,
                                    "first_time": str(e.first_timestamp),
                                    "last_time": str(e.last_timestamp)
                                }
                                for e in warnings[:5]
                            ]
                        })
                
                # Deep analysis if requested
                if deep_analysis:
                    await self._deep_analysis(pod, diagnosis)
                
                # Cache result
                await self.cache.set(cache_key, diagnosis)
                
                return diagnosis
                
            except client.ApiException as e:
                logger.error(f"Kubernetes API error: {e}")
                raise
    
    async def _check_pod_issues(self, pod, diagnosis: Dict):
        """Check for common pod issues"""
        
        # Check container statuses
        if pod.status.container_statuses:
            for container in pod.status.container_statuses:
                if not container.ready:
                    issue = {
                        "type": "container_not_ready",
                        "severity": "high",
                        "container": container.name,
                        "ready": False
                    }
                    
                    # Check waiting state
                    if container.state.waiting:
                        issue["reason"] = container.state.waiting.reason
                        issue["message"] = container.state.waiting.message
                        
                        if container.state.waiting.reason == "ImagePullBackOff":
                            diagnosis["recommendations"].append(
                                "Check image name and registry credentials"
                            )
                        elif container.state.waiting.reason == "CrashLoopBackOff":
                            diagnosis["recommendations"].append(
                                "Check container logs for startup errors"
                            )
                    
                    # Check terminated state
                    if container.state.terminated:
                        issue["exit_code"] = container.state.terminated.exit_code
                        issue["reason"] = container.state.terminated.reason
                        
                        if container.state.terminated.exit_code != 0:
                            diagnosis["recommendations"].append(
                                f"Container exited with code {container.state.terminated.exit_code}. Check logs."
                            )
                    
                    diagnosis["issues"].append(issue)
                
                # Check restart count
                if container.restart_count > 5:
                    diagnosis["issues"].append({
                        "type": "high_restart_count",
                        "severity": "medium",
                        "container": container.name,
                        "restart_count": container.restart_count
                    })
                    diagnosis["recommendations"].append(
                        f"Container {container.name} has restarted {container.restart_count} times. Investigate cause."
                    )
        
        # Check resource limits
        for container in pod.spec.containers:
            if not container.resources or not container.resources.limits:
                diagnosis["issues"].append({
                    "type": "missing_resource_limits",
                    "severity": "low",
                    "container": container.name
                })
                diagnosis["recommendations"].append(
                    f"Set resource limits for container {container.name}"
                )
    
    async def _deep_analysis(self, pod, diagnosis: Dict):
        """Perform deep analysis"""
        
        with tracer.start_as_current_span("deep_analysis"):
            # Get logs
            try:
                logs = self.k8s_core.read_namespaced_pod_log(
                    name=pod.metadata.name,
                    namespace=pod.metadata.namespace,
                    tail_lines=100
                )
                
                # Analyze logs for common errors
                error_patterns = [
                    ("OutOfMemory", "Container may be OOMKilled"),
                    ("Connection refused", "Service connectivity issue"),
                    ("Permission denied", "RBAC or file permission issue"),
                    ("timeout", "Slow dependencies or network issues")
                ]
                
                for pattern, recommendation in error_patterns:
                    if pattern.lower() in logs.lower():
                        diagnosis["recommendations"].append(recommendation)
                
            except client.ApiException as e:
                logger.warning(f"Could not fetch logs: {e}")
    
    async def _diagnose_deployment(
        self,
        namespace: str,
        deployment_name: str
    ) -> Dict:
        """Diagnose deployment issues"""
        
        with tracer.start_as_current_span("diagnose_deployment"):
            diagnosis = {
                "deployment_name": deployment_name,
                "namespace": namespace,
                "issues": [],
                "recommendations": []
            }
            
            try:
                # Get deployment
                deployment = self.k8s_apps.read_namespaced_deployment(
                    name=deployment_name,
                    namespace=namespace
                )
                
                # Check replicas
                desired = deployment.spec.replicas
                ready = deployment.status.ready_replicas or 0
                
                diagnosis["replicas"] = {
                    "desired": desired,
                    "ready": ready,
                    "available": deployment.status.available_replicas or 0,
                    "updated": deployment.status.updated_replicas or 0
                }
                
                if ready < desired:
                    diagnosis["issues"].append({
                        "type": "insufficient_replicas",
                        "severity": "high",
                        "desired": desired,
                        "ready": ready
                    })
                    diagnosis["recommendations"].append(
                        "Check pod status to identify why replicas are not ready"
                    )
                
                # Check rollout status
                if deployment.status.conditions:
                    for condition in deployment.status.conditions:
                        if condition.type == "Progressing" and condition.status != "True":
                            diagnosis["issues"].append({
                                "type": "rollout_stalled",
                                "severity": "high",
                                "reason": condition.reason,
                                "message": condition.message
                            })
                
                return diagnosis
                
            except client.ApiException as e:
                logger.error(f"Kubernetes API error: {e}")
                raise
    
    async def _diagnose_service(
        self,
        namespace: str,
        service_name: str
    ) -> Dict:
        """Diagnose service connectivity"""
        
        with tracer.start_as_current_span("diagnose_service"):
            diagnosis = {
                "service_name": service_name,
                "namespace": namespace,
                "issues": [],
                "recommendations": []
            }
            
            try:
                # Get service
                service = self.k8s_core.read_namespaced_service(
                    name=service_name,
                    namespace=namespace
                )
                
                # Get endpoints
                try:
                    endpoints = self.k8s_core.read_namespaced_endpoints(
                        name=service_name,
                        namespace=namespace
                    )
                    
                    # Check if service has endpoints
                    if not endpoints.subsets or not any(
                        s.addresses for s in endpoints.subsets
                    ):
                        diagnosis["issues"].append({
                            "type": "no_endpoints",
                            "severity": "high"
                        })
                        diagnosis["recommendations"].append(
                            "No pods match the service selector. Check pod labels."
                        )
                    
                except client.ApiException:
                    diagnosis["issues"].append({
                        "type": "no_endpoints_object",
                        "severity": "high"
                    })
                
                # Check service type
                diagnosis["service_type"] = service.spec.type
                
                if service.spec.type == "LoadBalancer":
                    if not service.status.load_balancer.ingress:
                        diagnosis["issues"].append({
                            "type": "loadbalancer_pending",
                            "severity": "medium"
                        })
                        diagnosis["recommendations"].append(
                            "LoadBalancer is pending. Check cloud provider status."
                        )
                
                return diagnosis
                
            except client.ApiException as e:
                logger.error(f"Kubernetes API error: {e}")
                raise
```

**Task 1.1**: Review and understand the server architecture
**Task 1.2**: Implement the diagnostic tools module
**Task 1.3**: Test diagnostic tools locally

**Checkpoint**: Run server and test `diagnose_pod` tool

---

## Part 2: Remediation Tools (45 min)

### 2.1: Implement Auto-Remediation

```python
# src/tools/remediation.py
from typing import Dict, Any, List
from mcp.types import Tool
from kubernetes import client
from opentelemetry import trace
import logging
import asyncio

logger = logging.getLogger(__name__)
tracer = trace.get_tracer(__name__)

class RemediationTools:
    """Remediation tools for Kubernetes"""
    
    def __init__(self, k8s_core, k8s_apps, cache, metrics):
        self.k8s_core = k8s_core
        self.k8s_apps = k8s_apps
        self.cache = cache
        self.metrics = metrics
    
    def get_tool_definitions(self) -> List[Tool]:
        return [
            Tool(
                name="remediate_pod_restart",
                description="Restart a problematic pod",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "namespace": {"type": "string"},
                        "pod_name": {"type": "string"},
                        "reason": {"type": "string"},
                        "confirm": {
                            "type": "boolean",
                            "description": "Confirm action",
                            "default": False
                        }
                    },
                    "required": ["namespace", "pod_name", "confirm"]
                }
            ),
            Tool(
                name="remediate_scale_deployment",
                description="Scale deployment to fix replica issues",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "namespace": {"type": "string"},
                        "deployment_name": {"type": "string"},
                        "replicas": {
                            "type": "integer",
                            "minimum": 0
                        },
                        "confirm": {"type": "boolean"}
                    },
                    "required": ["namespace", "deployment_name", "replicas", "confirm"]
                }
            ),
            Tool(
                name="remediate_rollback_deployment",
                description="Rollback deployment to previous version",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "namespace": {"type": "string"},
                        "deployment_name": {"type": "string"},
                        "revision": {
                            "type": "integer",
                            "description": "Revision to rollback to (0 = previous)",
                            "default": 0
                        },
                        "confirm": {"type": "boolean"}
                    },
                    "required": ["namespace", "deployment_name", "confirm"]
                }
            )
        ]
    
    async def execute(self, name: str, arguments: Dict[str, Any]) -> Dict:
        """Execute remediation tool"""
        
        # Verify confirmation
        if not arguments.get("confirm", False):
            return {
                "status": "cancelled",
                "message": "Action requires confirmation. Set confirm=true"
            }
        
        if name == "remediate_pod_restart":
            return await self._restart_pod(
                arguments["namespace"],
                arguments["pod_name"],
                arguments.get("reason", "Manual restart")
            )
        elif name == "remediate_scale_deployment":
            return await self._scale_deployment(
                arguments["namespace"],
                arguments["deployment_name"],
                arguments["replicas"]
            )
        elif name == "remediate_rollback_deployment":
            return await self._rollback_deployment(
                arguments["namespace"],
                arguments["deployment_name"],
                arguments.get("revision", 0)
            )
        else:
            raise ValueError(f"Unknown remediation tool: {name}")
    
    async def _restart_pod(
        self,
        namespace: str,
        pod_name: str,
        reason: str
    ) -> Dict:
        """Restart a pod by deleting it"""
        
        with tracer.start_as_current_span("restart_pod") as span:
            span.set_attribute("k8s.namespace", namespace)
            span.set_attribute("k8s.pod_name", pod_name)
            
            try:
                # Delete pod (will be recreated by controller)
                self.k8s_core.delete_namespaced_pod(
                    name=pod_name,
                    namespace=namespace
                )
                
                logger.info(
                    f"Restarted pod {pod_name} in {namespace}. Reason: {reason}"
                )
                
                # Invalidate cache
                await self.cache.delete(f"pod_diagnosis:{namespace}:{pod_name}")
                
                # Track metric
                self.metrics.remediations.labels(
                    action="pod_restart",
                    namespace=namespace
                ).inc()
                
                return {
                    "status": "success",
                    "action": "pod_restart",
                    "pod_name": pod_name,
                    "namespace": namespace,
                    "reason": reason,
                    "message": f"Pod {pod_name} deleted. Controller will recreate it."
                }
                
            except client.ApiException as e:
                logger.error(f"Failed to restart pod: {e}")
                raise
    
    async def _scale_deployment(
        self,
        namespace: str,
        deployment_name: str,
        replicas: int
    ) -> Dict:
        """Scale deployment"""
        
        with tracer.start_as_current_span("scale_deployment"):
            try:
                # Get current deployment
                deployment = self.k8s_apps.read_namespaced_deployment(
                    name=deployment_name,
                    namespace=namespace
                )
                
                old_replicas = deployment.spec.replicas
                
                # Update replicas
                deployment.spec.replicas = replicas
                self.k8s_apps.patch_namespaced_deployment(
                    name=deployment_name,
                    namespace=namespace,
                    body=deployment
                )
                
                logger.info(
                    f"Scaled deployment {deployment_name} from {old_replicas} to {replicas}"
                )
                
                # Track metric
                self.metrics.remediations.labels(
                    action="scale_deployment",
                    namespace=namespace
                ).inc()
                
                return {
                    "status": "success",
                    "action": "scale_deployment",
                    "deployment_name": deployment_name,
                    "namespace": namespace,
                    "old_replicas": old_replicas,
                    "new_replicas": replicas
                }
                
            except client.ApiException as e:
                logger.error(f"Failed to scale deployment: {e}")
                raise
    
    async def _rollback_deployment(
        self,
        namespace: str,
        deployment_name: str,
        revision: int = 0
    ) -> Dict:
        """Rollback deployment"""
        
        with tracer.start_as_current_span("rollback_deployment"):
            try:
                # Create rollback body
                body = client.AppsV1DeploymentRollback(
                    name=deployment_name,
                    rollback_to=client.AppsV1RollbackConfig(revision=revision)
                )
                
                # Note: rollback API is deprecated, use kubectl rollout undo
                # This is a simplified version
                
                logger.info(
                    f"Rolled back deployment {deployment_name} to revision {revision}"
                )
                
                # Track metric
                self.metrics.remediations.labels(
                    action="rollback_deployment",
                    namespace=namespace
                ).inc()
                
                return {
                    "status": "success",
                    "action": "rollback_deployment",
                    "deployment_name": deployment_name,
                    "namespace": namespace,
                    "revision": revision
                }
                
            except client.ApiException as e:
                logger.error(f"Failed to rollback deployment: {e}")
                raise
```

**Task 2.1**: Implement remediation tools
**Task 2.2**: Add safety checks and confirmations
**Task 2.3**: Test remediation actions

**Checkpoint**: Successfully restart a pod using remediation tool

---

## Part 3: Add Authentication & RBAC (30 min)

### 3.1: Implement RBAC

```python
# src/auth/rbac.py
from typing import Dict, Any, List
import yaml
import logging

logger = logging.getLogger(__name__)

class RBACManager:
    """Role-Based Access Control for MCP tools"""
    
    def __init__(self, policy_file: str = "rbac_policy.yaml"):
        self.policies = self._load_policies(policy_file)
    
    def _load_policies(self, file_path: str) -> Dict:
        """Load RBAC policies from file"""
        try:
            with open(file_path, 'r') as f:
                return yaml.safe_load(f)
        except FileNotFoundError:
            logger.warning(f"RBAC policy file not found: {file_path}")
            return self._default_policy()
    
    def _default_policy(self) -> Dict:
        """Default RBAC policy"""
        return {
            "roles": {
                "admin": {
                    "permissions": ["*"]
                },
                "operator": {
                    "permissions": [
                        "diagnose_*",
                        "remediate_pod_restart",
                        "remediate_scale_deployment"
                    ]
                },
                "viewer": {
                    "permissions": [
                        "diagnose_*",
                        "analyze_*"
                    ]
                }
            },
            "users": {
                "admin": {"role": "admin"},
                "ops-team": {"role": "operator"},
                "dev-team": {"role": "viewer"}
            }
        }
    
    def is_authorized(
        self,
        user: str,
        tool_name: str,
        arguments: Dict[str, Any]
    ) -> bool:
        """Check if user is authorized to use tool"""
        
        # Get user role
        user_config = self.policies.get("users", {}).get(user)
        if not user_config:
            logger.warning(f"User {user} not found in RBAC policies")
            return False
        
        role = user_config.get("role")
        if not role:
            return False
        
        # Get role permissions
        role_config = self.policies.get("roles", {}).get(role)
        if not role_config:
            logger.warning(f"Role {role} not found in RBAC policies")
            return False
        
        permissions = role_config.get("permissions", [])
        
        # Check if tool is allowed
        if "*" in permissions:
            return True
        
        for permission in permissions:
            if self._matches_permission(tool_name, permission):
                # Check namespace restrictions if any
                if "namespace_restrictions" in role_config:
                    allowed_namespaces = role_config["namespace_restrictions"]
                    requested_namespace = arguments.get("namespace")
                    
                    if requested_namespace not in allowed_namespaces:
                        logger.warning(
                            f"User {user} not allowed in namespace {requested_namespace}"
                        )
                        return False
                
                return True
        
        logger.warning(
            f"User {user} (role: {role}) not authorized for tool {tool_name}"
        )
        return False
    
    def _matches_permission(self, tool_name: str, permission: str) -> bool:
        """Check if tool matches permission pattern"""
        if permission == "*":
            return True
        
        if "*" in permission:
            # Wildcard matching
            pattern = permission.replace("*", ".*")
            import re
            return bool(re.match(f"^{pattern}$", tool_name))
        
        return tool_name == permission
```

### 3.2: RBAC Policy File

```yaml
# rbac_policy.yaml
roles:
  admin:
    permissions:
      - "*"
  
  operator:
    permissions:
      - "diagnose_*"
      - "remediate_*"
      - "analyze_*"
    namespace_restrictions:
      - "default"
      - "production"
  
  developer:
    permissions:
      - "diagnose_*"
      - "analyze_*"
    namespace_restrictions:
      - "development"
      - "staging"
  
  viewer:
    permissions:
      - "diagnose_pod"
      - "diagnose_deployment"
      - "diagnose_service"

users:
  alice:
    role: admin
  bob:
    role: operator
  charlie:
    role: developer
  diana:
    role: viewer
```

**Task 3.1**: Implement RBAC manager
**Task 3.2**: Create RBAC policies
**Task 3.3**: Test authorization checks

**Checkpoint**: Verify user permissions work correctly

---

## Part 4: Package and Deploy (45 min)

### 4.1: Create Dockerfile

```dockerfile
# Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY src/ ./src/
COPY rbac_policy.yaml .

# Create non-root user
RUN useradd -m -u 1000 mcpuser && \
    chown -R mcpuser:mcpuser /app

USER mcpuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

EXPOSE 8080 9090

CMD ["python", "-m", "src.server"]
```

### 4.2: Kubernetes Manifests

```yaml
# manifests/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: k8s-ops-mcp-server
  namespace: mcp-servers
  labels:
    app: k8s-ops-mcp-server
spec:
  replicas: 3
  selector:
    matchLabels:
      app: k8s-ops-mcp-server
  template:
    metadata:
      labels:
        app: k8s-ops-mcp-server
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: k8s-ops-mcp-server
      containers:
        - name: server
          image: k8s-ops-mcp-server:1.0.0
          ports:
            - name: http
              containerPort: 8080
            - name: metrics
              containerPort: 9090
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: ENVIRONMENT
              value: "production"
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
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
---
apiVersion: v1
kind: Service
metadata:
  name: k8s-ops-mcp-server
  namespace: mcp-servers
spec:
  selector:
    app: k8s-ops-mcp-server
  ports:
    - name: http
      port: 80
      targetPort: 8080
    - name: metrics
      port: 9090
      targetPort: 9090
  type: ClusterIP
```

### 4.3: RBAC for Server

```yaml
# manifests/rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: k8s-ops-mcp-server
  namespace: mcp-servers
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: k8s-ops-mcp-server
rules:
  # Read access to most resources
  - apiGroups: [""]
    resources:
      - pods
      - pods/log
      - services
      - endpoints
      - events
      - configmaps
    verbs: ["get", "list", "watch"]
  
  - apiGroups: ["apps"]
    resources:
      - deployments
      - replicasets
      - statefulsets
      - daemonsets
    verbs: ["get", "list", "watch", "patch"]
  
  - apiGroups: ["batch"]
    resources:
      - jobs
      - cronjobs
    verbs: ["get", "list", "watch"]
  
  # Write access for remediation
  - apiGroups: [""]
    resources:
      - pods
    verbs: ["delete"]
  
  - apiGroups: ["apps"]
    resources:
      - deployments
      - deployments/scale
    verbs: ["patch", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: k8s-ops-mcp-server
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: k8s-ops-mcp-server
subjects:
  - kind: ServiceAccount
    name: k8s-ops-mcp-server
    namespace: mcp-servers
```

**Task 4.1**: Build Docker image
**Task 4.2**: Deploy to Kubernetes
**Task 4.3**: Verify deployment

**Checkpoint**: Server running in Kubernetes with proper RBAC

---

## Deliverables

1. **Complete MCP Server**:
   - [ ] Diagnostic tools implemented
   - [ ] Remediation tools implemented
   - [ ] Analysis tools implemented
   - [ ] RBAC configured
   - [ ] Metrics and tracing

2. **Deployment**:
   - [ ] Docker image built
   - [ ] Kubernetes manifests
   - [ ] RBAC configured
   - [ ] Service deployed and running

3. **Documentation**:
   - [ ] Tool documentation
   - [ ] RBAC policy guide
   - [ ] Deployment guide

## Testing

```bash
# Build and deploy
docker build -t k8s-ops-mcp-server:1.0.0 .
kubectl apply -f manifests/

# Test diagnostic tool
kubectl exec -it deployment/k8s-ops-mcp-server -- \
  python -m src.tools.diagnostics test

# Check metrics
kubectl port-forward svc/k8s-ops-mcp-server 9090:9090
curl http://localhost:9090/metrics
```

## Summary

You've built a production-ready MCP server with:

✅ Custom diagnostic and remediation tools  
✅ RBAC and authentication  
✅ Monitoring and tracing  
✅ Kubernetes deployment  
✅ Best practices

---

**End of Lab 5**
