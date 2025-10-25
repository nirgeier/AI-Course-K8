# Final Project: Building an Autonomous K8s Self-Healing Agent

**Duration**: 2.5 hours  
**Difficulty**: Advanced  
**Team Size**: Individual or Pairs

## Project Overview

Build a comprehensive autonomous self-healing agent that monitors Kubernetes pods, diagnoses failures, and automatically remediates issues. This project integrates all concepts learned throughout the course.

## Learning Objectives

- Apply advanced MCP tool development
- Implement intelligent decision-making logic
- Practice production-grade coding standards
- Demonstrate security and observability best practices
- Build end-to-end automated workflows

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│            Self-Healing Agent Architecture                   │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              MCP Server (Agent Core)                   │ │
│  └──────────┬─────────────────────────────────────────────┘ │
│             │                                                │
│  ┌──────────▼──────────┐  ┌─────────────┐  ┌────────────┐  │
│  │  Diagnostic Engine  │  │   Healing   │  │  Reporter  │  │
│  │  - Pod Status       │  │   Engine    │  │  - Metrics │  │
│  │  - Log Analysis     │  │  - Restart  │  │  - Alerts  │  │
│  │  - Metrics Check    │  │  - Rollback │  │  - Logs    │  │
│  │  - Config Validate  │  │  - Scale    │  │            │  │
│  └─────────────────────┘  └─────────────┘  └────────────┘  │
│             │                     │                │         │
│  ┌──────────▼─────────────────────▼────────────────▼─────┐  │
│  │              Kubernetes API Server                     │  │
│  └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Requirements

### 1. Diagnostic Tools (Must Implement)

#### Tool: `diagnose_pod`

**Description**: Comprehensive pod health diagnostic

**Input Schema**:
```json
{
  "namespace": "string (required)",
  "pod_name": "string (required)",
  "check_logs": "boolean (optional, default: true)",
  "check_events": "boolean (optional, default: true)"
}
```

**Output**:
```json
{
  "success": true,
  "pod_name": "nginx-deployment-abc123",
  "namespace": "default",
  "status": {
    "phase": "Running",
    "conditions": [...],
    "container_statuses": [...]
  },
  "issues": [
    {
      "severity": "critical",
      "type": "CrashLoopBackOff",
      "container": "nginx",
      "message": "Container is restarting frequently",
      "restart_count": 5
    }
  ],
  "logs": {
    "errors": [...],
    "warnings": [...]
  },
  "events": [...],
  "recommendations": [
    "Restart pod",
    "Check resource limits",
    "Review recent configuration changes"
  ]
}
```

**Must Check**:
- Pod phase and conditions
- Container statuses and restart counts
- Recent events
- Error patterns in logs
- Resource usage vs limits
- Configuration validity

#### Tool: `analyze_logs`

**Description**: Parse and analyze pod logs for errors

**Input Schema**:
```json
{
  "namespace": "string (required)",
  "pod_name": "string (required)",
  "container": "string (optional)",
  "tail_lines": "integer (optional, default: 100)",
  "since_seconds": "integer (optional, default: 300)"
}
```

**Output**:
```json
{
  "success": true,
  "container": "nginx",
  "total_lines": 250,
  "errors": [
    {
      "timestamp": "2025-10-25T10:30:45Z",
      "level": "ERROR",
      "message": "Failed to connect to database",
      "pattern": "connection_error"
    }
  ],
  "error_patterns": {
    "connection_error": 15,
    "timeout_error": 3,
    "oom_killer": 1
  },
  "recommendations": [
    "Check network connectivity",
    "Verify service endpoints",
    "Increase memory limits"
  ]
}
```

#### Tool: `check_resource_usage`

**Description**: Get current resource usage and compare with limits

**Input Schema**:
```json
{
  "namespace": "string (required)",
  "pod_name": "string (required)"
}
```

**Output**:
```json
{
  "success": true,
  "pod_name": "nginx-deployment-abc123",
  "containers": [
    {
      "name": "nginx",
      "cpu": {
        "usage": "150m",
        "request": "100m",
        "limit": "200m",
        "percentage_of_limit": 75
      },
      "memory": {
        "usage": "256Mi",
        "request": "128Mi",
        "limit": "512Mi",
        "percentage_of_limit": 50
      },
      "issues": [
        "CPU usage above request"
      ]
    }
  ],
  "recommendations": [
    "Consider increasing CPU request"
  ]
}
```

### 2. Self-Healing Logic (Must Implement)

#### Tool: `auto_heal_pod`

**Description**: Automatically remediate pod issues based on diagnosis

**Input Schema**:
```json
{
  "namespace": "string (required)",
  "pod_name": "string (required)",
  "diagnosis": "object (required)",
  "dry_run": "boolean (optional, default: false)",
  "force": "boolean (optional, default: false)"
}
```

**Decision Logic**:

```python
if issue_type == "CrashLoopBackOff" and restart_count > 3:
    action = "delete_pod"  # Let controller recreate
elif issue_type == "OOMKilled":
    action = "increase_memory_limit"
elif issue_type == "ImagePullBackOff":
    action = "check_image_availability"
elif issue_type == "Pending" and reason == "Insufficient CPU":
    action = "scale_down_deployment" or "add_node"
else:
    action = "investigate_manually"
```

**Output**:
```json
{
  "success": true,
  "action_taken": "restart_pod",
  "pod_name": "nginx-deployment-abc123",
  "namespace": "default",
  "reason": "CrashLoopBackOff with 5 restarts",
  "dry_run": false,
  "timestamp": "2025-10-25T10:35:00Z",
  "verification": {
    "new_pod_status": "Running",
    "restart_count": 0,
    "healthy": true
  }
}
```

**Safety Checks** (Must Implement):
- Verify pod exists before acting
- Check if pod is managed by a controller
- Ensure action is appropriate for issue type
- Implement rate limiting (max actions per hour)
- Require approval for destructive actions (unless `force: true`)
- Log all actions to audit trail

#### Tool: `rollback_deployment`

**Description**: Rollback a deployment if healing fails

**Input Schema**:
```json
{
  "namespace": "string (required)",
  "deployment_name": "string (required)",
  "revision": "integer (optional)"
}
```

### 3. Observability & Reporting (Must Implement)

#### Metrics to Expose

```python
# Prometheus metrics
healing_attempts_total = Counter(
    "healing_attempts_total",
    "Total number of healing attempts",
    ["namespace", "pod", "action"]
)

healing_success_total = Counter(
    "healing_success_total",
    "Successful healing operations",
    ["namespace", "pod", "action"]
)

healing_duration_seconds = Histogram(
    "healing_duration_seconds",
    "Time taken to heal pods",
    ["namespace", "pod", "action"]
)

pod_health_score = Gauge(
    "pod_health_score",
    "Pod health score (0-100)",
    ["namespace", "pod"]
)
```

#### Grafana Dashboard Requirements

Create a dashboard with:

1. **Health Overview Panel**
   - Total pods monitored
   - Unhealthy pods count
   - Healing success rate

2. **Healing Activity Timeline**
   - Healing attempts over time
   - Success vs failure rate

3. **Issue Types Distribution**
   - Pie chart of issue types

4. **Top Problematic Pods**
   - Table of pods with most issues

5. **Healing Performance**
   - Average healing duration
   - P95, P99 latencies

### 4. Security Requirements (Must Implement)

#### RBAC Configuration

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: self-healing-agent
rules:
  # Read permissions
  - apiGroups: [""]
    resources: ["pods", "pods/log", "pods/status", "events"]
    verbs: ["get", "list", "watch"]
  
  # Write permissions (with care)
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["delete"]  # For pod restart
  
  # Deployment management
  - apiGroups: ["apps"]
    resources: ["deployments", "deployments/rollback"]
    verbs: ["get", "list", "patch"]
  
  # Metrics
  - apiGroups: ["metrics.k8s.io"]
    resources: ["pods"]
    verbs: ["get", "list"]
```

#### Audit Logging

Every action must be logged with:
- Timestamp
- Action type
- Target pod/deployment
- Reason for action
- User/agent who initiated
- Result (success/failure)
- Duration

### 5. Testing Requirements (Must Implement)

#### Unit Tests

- Test each diagnostic tool independently
- Test healing logic decision tree
- Test input validation
- Test error handling

#### Integration Tests

- Test full diagnostic → healing workflow
- Test with actual Kubernetes resources
- Test safety checks work correctly

#### Failure Injection Tests

Create failing pods to test:
- CrashLoopBackOff scenario
- OOMKilled scenario
- ImagePullBackOff scenario
- Resource exhaustion scenario

## Implementation Guide

### Phase 1: Setup (20 minutes)

```bash
# Create project structure
mkdir -p ~/mcp-servers/self-healing-agent
cd ~/mcp-servers/self-healing-agent

# Copy template from course materials
cp -r /path/to/course/resources/templates/self-healing-agent/* .

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### Phase 2: Implement Diagnostic Tools (45 minutes)

1. Start with `diagnose_pod` tool
2. Implement `analyze_logs` tool
3. Implement `check_resource_usage` tool
4. Add comprehensive error handling
5. Write unit tests

### Phase 3: Implement Healing Logic (40 minutes)

1. Create decision engine
2. Implement safety checks
3. Implement `auto_heal_pod` tool
4. Add rate limiting
5. Implement audit logging

### Phase 4: Add Observability (20 minutes)

1. Add Prometheus metrics
2. Create Grafana dashboard
3. Implement structured logging
4. Add health checks

### Phase 5: Deploy and Test (25 minutes)

1. Build Docker image
2. Deploy to Kubernetes
3. Create test scenarios
4. Run integration tests
5. Verify dashboard

## Starter Code

### Project Structure

```
self-healing-agent/
├── README.md
├── requirements.txt
├── Dockerfile
├── k8s/
│   ├── deployment.yaml
│   ├── rbac.yaml
│   └── servicemonitor.yaml
├── src/
│   ├── __init__.py
│   ├── server.py
│   ├── tools/
│   │   ├── __init__.py
│   │   ├── diagnostic.py
│   │   ├── healing.py
│   │   └── metrics.py
│   ├── engines/
│   │   ├── __init__.py
│   │   ├── decision.py
│   │   └── safety.py
│   └── utils/
│       ├── __init__.py
│       ├── k8s_client.py
│       ├── logging.py
│       └── metrics.py
├── tests/
│   ├── __init__.py
│   ├── test_diagnostic.py
│   ├── test_healing.py
│   └── test_integration.py
└── dashboards/
    └── self-healing-dashboard.json
```

### Sample Decision Engine

```python
# src/engines/decision.py
from typing import Dict, Any, List
from dataclasses import dataclass

@dataclass
class HealingDecision:
    action: str
    reason: str
    confidence: float
    safety_checks_passed: bool
    estimated_risk: str  # low, medium, high

class DecisionEngine:
    """Intelligent decision engine for pod healing."""
    
    def decide_action(self, diagnosis: Dict[str, Any]) -> HealingDecision:
        """Decide what action to take based on diagnosis."""
        issues = diagnosis.get("issues", [])
        
        if not issues:
            return HealingDecision(
                action="none",
                reason="No issues detected",
                confidence=1.0,
                safety_checks_passed=True,
                estimated_risk="low"
            )
        
        # Find highest severity issue
        critical_issues = [i for i in issues if i["severity"] == "critical"]
        
        if critical_issues:
            issue = critical_issues[0]
            return self._decide_for_issue(issue, diagnosis)
        
        return HealingDecision(
            action="monitor",
            reason="No critical issues",
            confidence=0.9,
            safety_checks_passed=True,
            estimated_risk="low"
        )
    
    def _decide_for_issue(
        self, 
        issue: Dict[str, Any],
        diagnosis: Dict[str, Any]
    ) -> HealingDecision:
        """Decide action for specific issue."""
        issue_type = issue["type"]
        
        if issue_type == "CrashLoopBackOff":
            if issue.get("restart_count", 0) > 5:
                return HealingDecision(
                    action="delete_pod",
                    reason=f"Excessive restarts: {issue['restart_count']}",
                    confidence=0.95,
                    safety_checks_passed=True,
                    estimated_risk="medium"
                )
        
        elif issue_type == "OOMKilled":
            return HealingDecision(
                action="increase_memory",
                reason="Pod killed due to OOM",
                confidence=0.90,
                safety_checks_passed=True,
                estimated_risk="low"
            )
        
        # Add more decision logic...
        
        return HealingDecision(
            action="investigate",
            reason=f"Unknown issue type: {issue_type}",
            confidence=0.5,
            safety_checks_passed=False,
            estimated_risk="high"
        )
```

## Testing Scenarios

### Scenario 1: CrashLoopBackOff

```bash
# Deploy a pod that crashes
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: crashloop-test
spec:
  containers:
  - name: crasher
    image: busybox
    command: ["sh", "-c", "exit 1"]
EOF

# Wait for CrashLoopBackOff
kubectl wait --for=condition=Ready=false pod/crashloop-test --timeout=60s

# Test your agent
# It should detect the issue and restart the pod
```

### Scenario 2: OOM Killer

```bash
# Deploy pod with low memory limit
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: oom-test
spec:
  containers:
  - name: memory-hog
    image: polinux/stress
    resources:
      limits:
        memory: "50Mi"
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "100M"]
EOF

# Test your agent's detection and response
```

## Evaluation Rubric

### Functionality (40 points)

- [ ] All diagnostic tools implemented (10 pts)
- [ ] Healing logic works correctly (10 pts)
- [ ] Safety checks prevent harmful actions (10 pts)
- [ ] Handles all test scenarios (10 pts)

### Code Quality (20 points)

- [ ] Clean, readable code (5 pts)
- [ ] Proper error handling (5 pts)
- [ ] Comprehensive tests (5 pts)
- [ ] Good documentation (5 pts)

### Security (20 points)

- [ ] Proper RBAC configuration (5 pts)
- [ ] Audit logging complete (5 pts)
- [ ] Rate limiting implemented (5 pts)
- [ ] No security vulnerabilities (5 pts)

### Observability (20 points)

- [ ] Prometheus metrics exposed (5 pts)
- [ ] Grafana dashboard complete (5 pts)
- [ ] Structured logging (5 pts)
- [ ] Alerts configured (5 pts)

## Submission

### Required Deliverables

1. Complete source code (GitHub repository)
2. README with:
   - Architecture overview
   - Installation instructions
   - Usage examples
   - Design decisions
3. Grafana dashboard JSON
4. Test results and coverage report
5. 5-minute demo video (optional)

### Submission Format

```
self-healing-agent-submission/
├── README.md
├── ARCHITECTURE.md
├── src/
├── tests/
├── k8s/
├── dashboards/
├── docs/
│   ├── design-decisions.md
│   └── test-results.md
└── demo/ (optional)
    └── demo-video.mp4
```

## Bonus Challenges (Optional)

1. **Multi-Cluster Support**: Extend to monitor multiple clusters
2. **AI Integration**: Use LangChain to make smarter decisions
3. **Slack Integration**: Send notifications to Slack
4. **Advanced Healing**: Implement rollback strategies
5. **Cost Optimization**: Suggest resource optimization
6. **Predictive Healing**: Predict failures before they happen

## Resources

- [Starter Template](./templates/self-healing-agent/)
- [Sample Test Suite](./examples/test-suite/)
- [Reference Implementation](./solutions/self-healing-agent/)
- [Troubleshooting Guide](./docs/troubleshooting.md)

## Tips for Success

1. **Start Simple**: Get basic diagnostic working first
2. **Test Frequently**: Test each component as you build
3. **Safety First**: Implement safety checks early
4. **Document Decisions**: Keep notes on why you made choices
5. **Ask Questions**: Don't hesitate to ask instructors
6. **Time Management**: Allocate time for testing and debugging

---

**Good Luck!** 🚀

Build something amazing and show off your MCP/Kagent skills!
