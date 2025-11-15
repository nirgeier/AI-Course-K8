# Configuration Files for Lab 01

This directory contains all configuration files needed for the lab environment.

## Files

### kind-config.yaml
Kubernetes cluster configuration for kind.

**Features:**
- 1 control-plane node
- 2 worker nodes
- Port mappings for:
  - HTTP (80)
  - HTTPS (443)
  - Prometheus (30090)
  - Grafana (30030)
  - MCP servers (30000, 30001)
- Node labels for workload placement

**Usage:**
```bash
kind create cluster --config kind-config.yaml
```

### mcp-rbac.yaml
RBAC configuration for MCP servers.

**Resources:**
- ServiceAccount: `mcp-server`
- ClusterRole: `mcp-server-role`
- ClusterRoleBinding: `mcp-server-binding`
- Role: `mcp-server-namespace-role` (default namespace)
- RoleBinding: `mcp-server-namespace-binding`

**Permissions:**
- Read: pods, services, deployments, nodes, metrics
- Write: pods and services (default namespace only)

**Usage:**
```bash
kubectl apply -f mcp-rbac.yaml
```

## Customization

### Changing Ports

Edit `kind-config.yaml`:
```yaml
extraPortMappings:
  - containerPort: 30090
    hostPort: 9090  # Change this
    protocol: TCP
```

### Adding More Nodes

Edit `kind-config.yaml`:
```yaml
nodes:
  - role: control-plane
  - role: worker
  - role: worker
  - role: worker  # Add this
```

### Modifying RBAC Permissions

Edit `mcp-rbac.yaml` to add/remove permissions:
```yaml
rules:
  - apiGroups: [""]
    resources: ["configmaps"]  # Add new resource
    verbs: ["get", "list"]
```

## Validation

### Validate kind-config.yaml
```bash
kind create cluster --config kind-config.yaml --dry-run
```

### Validate mcp-rbac.yaml
```bash
kubectl apply -f mcp-rbac.yaml --dry-run=client
```

### Test RBAC Permissions
```bash
kubectl auth can-i get pods --as=system:serviceaccount:default:mcp-server
```
