# Troubleshooting Guide

## Common Issues and Solutions

This guide covers common issues you may encounter during the AI/MCP in K8S course and their solutions.

## Table of Contents

- [Environment Setup Issues](#environment-setup-issues)
- [Docker Issues](#docker-issues)
- [Kubernetes Issues](#kubernetes-issues)
- [MCP Server Issues](#mcp-server-issues)
- [Monitoring Issues](#monitoring-issues)
- [Networking Issues](#networking-issues)

## Environment Setup Issues

### Issue: kind cluster creation fails

**Symptoms**:
```
ERROR: failed to create cluster: failed to ensure docker network
```

**Causes**:
- Docker not running
- Port already in use
- Insufficient resources

**Solutions**:

```bash
# 1. Verify Docker is running
docker ps

# 2. Delete existing cluster
kind delete cluster --name mcp-dev-cluster

# 3. Check for port conflicts
lsof -i :80
lsof -i :443
lsof -i :6443

# 4. Create cluster with different ports
cat > kind-config-alt.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: mcp-dev-cluster
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 8080
      - containerPort: 443
        hostPort: 8443
EOF

kind create cluster --config kind-config-alt.yaml
```

### Issue: kubectl cannot connect to cluster

**Symptoms**:
```
The connection to the server localhost:8080 was refused
```

**Solutions**:

```bash
# 1. Check if cluster is running
kind get clusters

# 2. Verify context
kubectl config get-contexts

# 3. Set correct context
kubectl config use-context kind-mcp-dev-cluster

# 4. Test connection
kubectl cluster-info
```

## Docker Issues

### Issue: Permission denied when running Docker

**Symptoms**:
```
Got permission denied while trying to connect to the Docker daemon socket
```

**Solutions**:

```bash
# Linux: Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker ps
```

### Issue: Docker build fails with "no space left on device"

**Solutions**:

```bash
# Clean up Docker resources
docker system prune -a --volumes

# Check disk space
df -h

# Remove unused images
docker image prune -a
```

### Issue: Image pull rate limit exceeded

**Symptoms**:
```
Error response from daemon: toomanyrequests: You have reached your pull rate limit
```

**Solutions**:

```bash
# Login to Docker Hub
docker login

# Or use a mirror
# Edit /etc/docker/daemon.json
{
  "registry-mirrors": ["https://mirror.gcr.io"]
}

# Restart Docker
sudo systemctl restart docker  # Linux
# Or restart Docker Desktop on macOS
```

## Kubernetes Issues

### Issue: Pods stuck in Pending state

**Symptoms**:
```
NAME                    READY   STATUS    RESTARTS   AGE
my-pod-abc123          0/1     Pending   0          5m
```

**Diagnosis**:

```bash
# Describe the pod
kubectl describe pod my-pod-abc123

# Common causes in describe output:
# - "Insufficient cpu/memory" -> Resource shortage
# - "FailedScheduling" -> No suitable node
# - "ImagePullBackOff" -> Cannot pull image
```

**Solutions**:

```bash
# For resource issues
kubectl top nodes
kubectl describe nodes

# Reduce resource requests or add nodes
kind create cluster --config kind-config.yaml  # with more nodes

# For image issues
kind load docker-image my-image:tag --name mcp-dev-cluster
```

### Issue: Pods in CrashLoopBackOff

**Symptoms**:
```
NAME                    READY   STATUS             RESTARTS   AGE
my-pod-abc123          0/1     CrashLoopBackOff   5          5m
```

**Diagnosis**:

```bash
# Check logs
kubectl logs my-pod-abc123

# Check previous container logs
kubectl logs my-pod-abc123 --previous

# Describe pod for events
kubectl describe pod my-pod-abc123
```

**Common Causes & Solutions**:

```bash
# 1. Application error
# Fix: Review logs and fix application code

# 2. Missing dependencies/config
kubectl get configmap
kubectl get secret

# 3. Wrong command/args
kubectl get pod my-pod-abc123 -o yaml | grep -A5 command

# 4. Health check failures
kubectl get pod my-pod-abc123 -o yaml | grep -A10 livenessProbe
```

### Issue: Service not accessible

**Diagnosis**:

```bash
# Check service
kubectl get svc my-service

# Check endpoints
kubectl get endpoints my-service

# If no endpoints:
# 1. Check if pods are running
kubectl get pods -l app=my-app

# 2. Verify label selector matches
kubectl get svc my-service -o yaml | grep -A3 selector
kubectl get pods --show-labels
```

**Solutions**:

```bash
# Fix label mismatch
kubectl label pod my-pod app=my-app

# Test from within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- sh
# Inside pod:
curl http://my-service:8080
```

## MCP Server Issues

### Issue: MCP server not starting

**Symptoms**:
- Container exits immediately
- Logs show import errors

**Diagnosis**:

```bash
# Check container logs
docker logs <container-id>

# Or in Kubernetes
kubectl logs -l app=mcp-server

# Common issues:
# - ModuleNotFoundError -> Missing dependencies
# - SyntaxError -> Python version mismatch
# - Connection refused -> Cannot reach K8s API
```

**Solutions**:

```bash
# 1. Verify dependencies
pip list | grep mcp
pip install -r requirements.txt

# 2. Check Python version
python --version  # Should be 3.10+

# 3. Rebuild image
docker build --no-cache -t mcp-server:latest .

# 4. Verify Kubernetes permissions
kubectl auth can-i get pods --as=system:serviceaccount:default:mcp-server
```

### Issue: Tool execution fails

**Symptoms**:
- Tool returns error response
- Timeout errors

**Diagnosis**:

```python
# Add debug logging
import structlog
logger = structlog.get_logger()

@tool
async def my_tool(args):
    logger.debug("Tool called", args=args)
    try:
        result = do_something(args)
        logger.info("Tool succeeded", result=result)
        return result
    except Exception as e:
        logger.exception("Tool failed")
        raise
```

**Solutions**:

```bash
# 1. Test tool independently
python -c "
import asyncio
from src.tools.my_tool import my_tool
result = asyncio.run(my_tool({'param': 'value'}))
print(result)
"

# 2. Check input validation
# Ensure schema matches actual input

# 3. Verify Kubernetes access
kubectl get pods  # As the service account
```

## Monitoring Issues

### Issue: Prometheus not scraping metrics

**Symptoms**:
- No data in Grafana
- Targets show "down" in Prometheus

**Diagnosis**:

```bash
# 1. Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open http://localhost:9090/targets

# 2. Check ServiceMonitor
kubectl get servicemonitor -n monitoring

# 3. Verify metrics endpoint
kubectl port-forward svc/mcp-server 8080:8080
curl http://localhost:8080/metrics
```

**Solutions**:

```bash
# 1. Create ServiceMonitor
cat > servicemonitor.yaml << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: mcp-server
  namespace: default
spec:
  selector:
    matchLabels:
      app: mcp-server
  endpoints:
  - port: metrics
    interval: 30s
EOF

kubectl apply -f servicemonitor.yaml

# 2. Verify service has correct labels
kubectl get svc mcp-server -o yaml

# 3. Check Prometheus configuration
kubectl get prometheus -n monitoring -o yaml
```

### Issue: Grafana dashboard shows no data

**Solutions**:

```bash
# 1. Check data source configuration
# Grafana -> Configuration -> Data Sources
# Verify Prometheus URL and access

# 2. Test query in Prometheus
# http://localhost:9090
# Run your metric query

# 3. Check time range in Grafana
# Ensure it matches when data was generated

# 4. Verify metric labels match dashboard variables
```

### Issue: Alert not firing

**Diagnosis**:

```bash
# 1. Check alert rules
kubectl get prometheusrule -n monitoring

# 2. View alert status in Prometheus
# http://localhost:9090/alerts

# 3. Check Alertmanager
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
# Open http://localhost:9093
```

**Solutions**:

```yaml
# Example alert rule
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: mcp-server-alerts
  namespace: monitoring
spec:
  groups:
  - name: mcp-server
    interval: 30s
    rules:
    - alert: MCPServerDown
      expr: up{job="mcp-server"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "MCP Server is down"
```

## Networking Issues

### Issue: Cannot access service from outside cluster

**Solutions**:

```bash
# 1. Use port-forward for development
kubectl port-forward svc/my-service 8080:80

# 2. Use NodePort service
kubectl patch svc my-service -p '{"spec":{"type":"NodePort"}}'
kubectl get svc my-service  # Note the NodePort

# For kind, map the port
kind delete cluster --name mcp-dev-cluster
# Edit kind-config.yaml to add port mapping
kind create cluster --config kind-config.yaml

# 3. Use Ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

### Issue: DNS resolution not working

**Diagnosis**:

```bash
# Test DNS from within cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
# Inside pod:
nslookup kubernetes.default
nslookup my-service.default.svc.cluster.local

# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

**Solutions**:

```bash
# Restart CoreDNS
kubectl rollout restart deployment/coredns -n kube-system

# Check DNS configuration
kubectl get configmap coredns -n kube-system -o yaml
```

## Performance Issues

### Issue: Slow API responses

**Diagnosis**:

```bash
# 1. Check resource usage
kubectl top pods
kubectl top nodes

# 2. Enable profiling
# Add to Python code:
import cProfile
cProfile.run('my_function()')

# 3. Check for network latency
kubectl exec -it my-pod -- time curl http://api-service
```

**Solutions**:

```bash
# 1. Increase resources
kubectl set resources deployment my-app --limits=cpu=200m,memory=512Mi

# 2. Add caching
# Implement application-level caching

# 3. Optimize database queries
# Use connection pooling
# Add indices

# 4. Scale horizontally
kubectl scale deployment my-app --replicas=3
```

## Debugging Tips

### General Debugging Workflow

```bash
# 1. Check pod status
kubectl get pods -A

# 2. Describe problem pod
kubectl describe pod <pod-name>

# 3. Check logs
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # Previous container

# 4. Execute into pod
kubectl exec -it <pod-name> -- sh

# 5. Check events
kubectl get events --sort-by='.lastTimestamp'

# 6. Check resource usage
kubectl top pod <pod-name>
```

### Enable Debug Logging

```python
# In Python MCP server
import logging
import os

log_level = os.getenv("LOG_LEVEL", "INFO")
logging.basicConfig(level=getattr(logging, log_level))
```

```yaml
# In Kubernetes deployment
env:
  - name: LOG_LEVEL
    value: "DEBUG"
```

### Useful kubectl Plugins

```bash
# Install krew (kubectl plugin manager)
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

# Install useful plugins
kubectl krew install ctx      # Switch contexts easily
kubectl krew install ns       # Switch namespaces easily
kubectl krew install stern    # Multi-pod log tailing
kubectl krew install tree     # Resource hierarchy

# Usage
kubectl ctx kind-mcp-dev-cluster
kubectl ns default
kubectl stern mcp-server
kubectl tree deployment mcp-server
```

## Getting Help

### Resources

- Course Slack: `#course-help`
- Instructor email: instructor@example.com
- GitHub Discussions: [Course Repository Issues](https://github.com/course/issues)

### Before Asking for Help

1. Check this troubleshooting guide
2. Search course materials
3. Review error messages carefully
4. Try to isolate the problem
5. Document what you've tried

### When Asking for Help

Provide:

```markdown
## Issue Description
Brief description of the problem

## Environment
- OS: macOS/Linux/Windows
- Kubernetes version: 
- Docker version: 
- Python version: 

## Steps to Reproduce
1. Step 1
2. Step 2
3. Step 3

## Expected Behavior
What you expected to happen

## Actual Behavior
What actually happened

## Error Messages
```
Paste error messages here
```

## Additional Context
Screenshots, logs, etc.
```

---

**Still Stuck?** Don't hesitate to ask your instructor! We're here to help. 🙋‍♂️
