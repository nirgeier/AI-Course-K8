# Lab 1: Comprehensive Environment Setup

**Duration**: 2 hours  
**Difficulty**: Beginner

## Overview

This lab provides a complete, production-ready development environment for building MCP servers with Kagent. It includes automated installation scripts, cluster configuration, monitoring stack deployment, and comprehensive verification tools.

## Learning Objectives

After completing this lab, you will be able to:

- Install and configure development tools (kind, kubectl, Helm, Docker)
- Set up kmcp CLI with proper authentication
- Create and manage a local Kubernetes cluster
- Deploy Prometheus and Grafana for monitoring
- Verify connectivity and permissions across all components
- Use automated scripts for efficient environment setup

## Prerequisites

### Hardware Requirements
- **RAM:** 8GB minimum (16GB recommended)
- **CPU:** 2+ cores (4+ recommended)
- **Disk:** 20GB free space
- **Network:** Internet connectivity required

### Software Requirements
- macOS 10.15+ or Linux (Ubuntu 20.04+, Debian 10+, RHEL/CentOS 8+)
- Admin/sudo access on your machine
- Homebrew (macOS) or apt/yum (Linux)

## Quick Start 🚀

The fastest way to set up your environment is using the automated setup script:

```bash
cd scripts
chmod +x setup.sh
./setup.sh
```

**Duration:** ~20-30 minutes

This script will:
- ✅ Install all required tools (Docker, kubectl, kind, Helm)
- ✅ Create a 3-node Kubernetes cluster
- ✅ Deploy Prometheus and Grafana monitoring stack
- ✅ Configure RBAC permissions
- ✅ Verify the complete environment
- ✅ Optionally install kmcp CLI

## Architecture

```
┌─────────────────────────────────────────────────┐
│           Development Environment               │
│                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │  Docker  │  │   kind   │  │  kubectl │       │
│  └──────────┘  └──────────┘  └──────────┘       │
│                                                 │
│  ┌─────────────────────────────────────┐        │
│  │   3-Node Kubernetes Cluster         │        │
│  │  ┌──────────┐    ┌──────────────┐   │        │
│  │  │   kmcp   │    │  Prometheus  │   │        │
│  │  │  server  │───▶│   & Grafana  │   │        │
│  │  └──────────┘    └──────────────┘   │        │
│  │  (1 control-plane + 2 workers)      │        │
│  └─────────────────────────────────────┘        │
└─────────────────────────────────────────────────┘
```

## What's Included

### ✅ Automated Installation Scripts
All tools automated for macOS and Linux:
- `install-docker.sh` - Docker installation
- `install-kubectl.sh` - kubectl CLI installation
- `install-kind.sh` - kind (Kubernetes in Docker) installation
- `install-helm.sh` - Helm package manager installation
- `install-kmcp.sh` - kmcp CLI installation (optional)

### ✅ Cluster Configuration
- 3-node Kubernetes cluster (1 control-plane, 2 workers)
- Configured port mappings for all services
- Node labels for workload placement
- Ingress-ready configuration

### ✅ Monitoring Stack
- Prometheus with custom configuration
- Grafana with dashboards and admin credentials
- NodePort access (no port-forward needed)
- Pre-configured for MCP server metrics
- 7-day retention period

### ✅ Security & RBAC
- ServiceAccount for MCP servers
- ClusterRole with appropriate permissions
- RoleBindings for namespace operations
- Permission testing included

### ✅ Verification & Testing
- Comprehensive environment verification (`verify-environment.sh`)
- Quick functional tests (`quick-test.sh`)
- Error detection and reporting
- Detailed status checks

### ✅ Management Utilities
- Master setup script (`setup.sh`)
- Cleanup script (`cleanup.sh`)
- Comprehensive documentation

## Directory Structure

```
lab-01-environment-setup/
├── README.md (this file)
├── scripts/
│   ├── setup.sh                     # Master setup script ⭐
│   ├── install-docker.sh            # Docker installation
│   ├── install-kubectl.sh           # kubectl installation
│   ├── install-kind.sh              # kind installation
│   ├── install-helm.sh              # Helm installation
│   ├── install-kmcp.sh              # kmcp CLI installation
│   ├── create-cluster.sh            # Cluster creation
│   ├── deploy-monitoring.sh         # Monitoring stack deployment
│   ├── setup-rbac.sh                # RBAC configuration
│   ├── verify-environment.sh        # Environment verification ⭐
│   ├── quick-test.sh                # Quick functionality test
│   └── cleanup.sh                   # Environment cleanup
└── config/
    ├── kind-config.yaml             # kind cluster configuration
    └── mcp-rbac.yaml                # RBAC resources
```

## Installation Options

### Option 1: Automated Setup (Recommended) ⭐

Run the master script that handles everything:

```bash
cd scripts
chmod +x setup.sh
./setup.sh
```

**Features:**

- Interactive prompts for each step
- Step-by-step confirmation
- Comprehensive error handling
- Progress tracking
- Automatic verification at completion

**Duration:** ~20-30 minutes

### Option 2: Manual Step-by-Step

Install components individually using the provided scripts:

```bash
cd scripts
chmod +x *.sh

# 1. Install tools (15-25 min)
./install-docker.sh
./install-kubectl.sh
./install-kind.sh
./install-helm.sh

# 2. Create infrastructure (10-15 min)
./create-cluster.sh
./deploy-monitoring.sh
./setup-rbac.sh

# 3. Optional: Install kmcp CLI (5 min)
./install-kmcp.sh

# 4. Verify (2-3 min)
./verify-environment.sh
./quick-test.sh
```

### Option 3: Traditional Manual Setup

Follow the detailed step-by-step instructions below for complete control over each installation step.

---

## Detailed Setup Instructions

## Step 1: Install Docker (15 minutes)

### macOS - Docker Installation

### macOS

```bash
# Using Homebrew
brew install --cask docker

# Start Docker Desktop
open -a Docker

# Verify installation
docker --version
docker ps
```

### Linux (Ubuntu/Debian)

```bash
# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add your user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker --version
docker ps
```

### Verification

```bash
# Test Docker installation
docker run hello-world
```

Expected output: You should see a "Hello from Docker!" message.

## Step 2: Install kubectl (10 minutes)

### macOS

```bash
# Using Homebrew
brew install kubectl

# Verify installation
kubectl version --client
```

### Linux

```bash
# Download latest stable version
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Install kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify installation
kubectl version --client
```

### Configure kubectl autocomplete

```bash
# For zsh (macOS default)
echo 'source <(kubectl completion zsh)' >> ~/.zshrc
echo 'alias k=kubectl' >> ~/.zshrc
echo 'complete -F __start_kubectl k' >> ~/.zshrc
source ~/.zshrc

# For bash
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc
source ~/.bashrc
```

## Step 3: Install kind (15 minutes)

kind (Kubernetes IN Docker) allows you to run Kubernetes clusters using Docker containers as nodes.

### macOS

```bash
# Using Homebrew
brew install kind

# Verify installation
kind version
```

### Linux

```bash
# Download kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64

# Install kind
sudo install -o root -g root -m 0755 kind /usr/local/bin/kind

# Verify installation
kind version
```

### Create kind cluster configuration

Create a file `kind-config.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: mcp-dev-cluster
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
      - containerPort: 30000
        hostPort: 30000
        protocol: TCP
  - role: worker
  - role: worker
```

### Create the cluster

```bash
# Create cluster with configuration
kind create cluster --config kind-config.yaml

# Verify cluster
kubectl cluster-info --context kind-mcp-dev-cluster
kubectl get nodes
```

Expected output: You should see one control-plane node and two worker nodes in "Ready" status.

## Step 4: Install Helm (10 minutes)

### macOS

```bash
# Using Homebrew
brew install helm

# Verify installation
helm version
```

### Linux

```bash
# Download installation script
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
```

### Add common Helm repositories

```bash
# Add Prometheus community charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Add Grafana charts
helm repo add grafana https://grafana.github.io/helm-charts

# Update repositories
helm repo update
```

## Step 5: Install Prometheus & Grafana (30 minutes)

### Create monitoring namespace

```bash
kubectl create namespace monitoring
```

### Deploy Prometheus

```bash
# Install Prometheus using Helm
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30090 \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30030

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l "release=prometheus" -n monitoring --timeout=300s
```

### Verify Prometheus installation

```bash
# Check pods
kubectl get pods -n monitoring

# Port-forward Prometheus (in a separate terminal)
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Open browser: http://localhost:9090

### Verify Grafana installation

```bash
# Get Grafana admin password
kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# Port-forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

Open browser: http://localhost:3000
- Username: `admin`
- Password: (use the password from the previous command)

## Step 6: Install kmcp CLI (20 minutes)

### Install Python environment (if not already installed)

```bash
# macOS
brew install python@3.11

# Linux
sudo apt-get install -y python3.11 python3.11-venv python3-pip
```

### Install kmcp CLI

> **Note**: This is a simulated installation for training purposes.
> In production, you would install from official Kagent repository.

```bash
# Create virtual environment
python3 -m venv ~/kmcp-env

# Activate virtual environment
source ~/kmcp-env/bin/activate

# Install kmcp (simulated - adjust for actual package)
pip install --upgrade pip
pip install pyyaml kubernetes prometheus-client

# Create kmcp wrapper script
mkdir -p ~/bin
cat > ~/bin/kmcp << 'EOF'
#!/bin/bash
source ~/kmcp-env/bin/activate
python -m kmcp "$@"
EOF

chmod +x ~/bin/kmcp

# Add to PATH
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Create kmcp configuration directory

```bash
mkdir -p ~/.kmcp
cat > ~/.kmcp/config.yaml << 'EOF'
apiVersion: v1
kind: Config
current-context: kind-mcp-dev-cluster
contexts:
  - name: kind-mcp-dev-cluster
    context:
      cluster: kind-mcp-dev-cluster
      namespace: default
      user: kind-mcp-dev-cluster
clusters:
  - name: kind-mcp-dev-cluster
    cluster:
      server: https://127.0.0.1:6443
      certificate-authority: ~/.kube/kind-mcp-dev-cluster-ca.crt
users:
  - name: kind-mcp-dev-cluster
    user:
      client-certificate: ~/.kube/kind-mcp-dev-cluster.crt
      client-key: ~/.kube/kind-mcp-dev-cluster.key
EOF
```

## Step 7: Set up RBAC permissions (15 minutes)

Create RBAC resources for MCP server development:

```bash
cat > mcp-rbac.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: mcp-server
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: mcp-server-role
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "pods/status"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["services", "endpoints"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "statefulsets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["metrics.k8s.io"]
    resources: ["pods", "nodes"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: mcp-server-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: mcp-server-role
subjects:
  - kind: ServiceAccount
    name: mcp-server
    namespace: default
EOF

kubectl apply -f mcp-rbac.yaml
```

## Step 8: Verification and Testing (15 minutes)

### Create verification script

```bash
cat > verify-environment.sh << 'EOF'
#!/bin/bash

echo "=== Environment Verification Script ==="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

check_command() {
    if command -v $1 &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 is installed"
        $1 version 2>&1 | head -n 1
    else
        echo -e "${RED}✗${NC} $1 is NOT installed"
        return 1
    fi
    echo ""
}

echo "1. Checking Docker..."
check_command docker

echo "2. Checking kubectl..."
check_command kubectl

echo "3. Checking kind..."
check_command kind

echo "4. Checking Helm..."
check_command helm

echo "5. Checking Kubernetes cluster..."
if kubectl cluster-info &> /dev/null; then
    echo -e "${GREEN}✓${NC} Kubernetes cluster is running"
    kubectl get nodes
else
    echo -e "${RED}✗${NC} Kubernetes cluster is NOT accessible"
fi
echo ""

echo "6. Checking monitoring stack..."
if kubectl get pods -n monitoring | grep -q "Running"; then
    echo -e "${GREEN}✓${NC} Monitoring stack is running"
    kubectl get pods -n monitoring
else
    echo -e "${RED}✗${NC} Monitoring stack has issues"
    kubectl get pods -n monitoring
fi
echo ""

echo "7. Checking RBAC configuration..."
if kubectl get serviceaccount mcp-server &> /dev/null; then
    echo -e "${GREEN}✓${NC} MCP ServiceAccount exists"
else
    echo -e "${RED}✗${NC} MCP ServiceAccount is missing"
fi
echo ""

echo "=== Verification Complete ==="
EOF

chmod +x verify-environment.sh
./verify-environment.sh
```

### Test cluster connectivity

```bash
# Get cluster information
kubectl cluster-info

# List all namespaces
kubectl get namespaces

# List all pods across all namespaces
kubectl get pods --all-namespaces

# Test service account
kubectl auth can-i get pods --as=system:serviceaccount:default:mcp-server
```

## Step 9: IDE Setup (Optional, 10 minutes)

### VS Code Extensions

Install the following VS Code extensions:

```bash
# Kubernetes
code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools

# YAML
code --install-extension redhat.vscode-yaml

# Python
code --install-extension ms-python.python

# Docker
code --install-extension ms-azuretools.vscode-docker
```

### Configure VS Code settings

Create `.vscode/settings.json` in your workspace:

```json
{
  "yaml.schemas": {
    "https://json.schemastore.org/kustomization": "kustomization.yaml",
    "kubernetes": "*.k8s.yaml"
  },
  "python.linting.enabled": true,
  "python.linting.pylintEnabled": true,
  "python.formatting.provider": "black"
}
```

## Verification and Access

### Verify Complete Environment

After installation, verify your environment:

```bash
cd scripts
./verify-environment.sh
```

**Expected Output:**

```
✓ Docker is installed and running
✓ kubectl is installed
✓ kind is installed
✓ Helm is installed
✓ Kubernetes cluster is running
✓ All nodes are Ready
✓ Monitoring stack is running
✓ RBAC configuration is correct
```

### Run Quick Functional Test

```bash
cd scripts
./quick-test.sh
```

This creates a test pod with the mcp-server ServiceAccount, verifies network connectivity, checks monitoring endpoints, and cleans up test resources.

### Access Services

#### Prometheus

```bash
# NodePort (recommended)
open http://localhost:30090

# Or port-forward
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
open http://localhost:9090
```

#### Grafana

```bash
# NodePort (recommended)
open http://localhost:30030

# Or port-forward
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
open http://localhost:3000
```

**Credentials:**

- Username: `admin`
- Password: `admin123`

## Available Scripts Reference

### Installation Scripts

| Script | Description | Duration |
|--------|-------------|----------|
| `install-docker.sh` | Installs Docker for macOS/Linux | 5-10 min |
| `install-kubectl.sh` | Installs kubectl CLI | 2-5 min |
| `install-kind.sh` | Installs kind (Kubernetes in Docker) | 2-5 min |
| `install-helm.sh` | Installs Helm package manager | 2-5 min |
| `install-k9s.sh` | Installs k9s terminal UI (optional) | 2-5 min |
| `install-kmcp.sh` | Installs kmcp CLI (optional) | 5 min |

### Cluster Management Scripts

| Script | Description | Duration |
|--------|-------------|----------|
| `create-cluster.sh` | Creates kind Kubernetes cluster | 3-5 min |
| `deploy-monitoring.sh` | Deploys Prometheus & Grafana | 5-10 min |
| `setup-rbac.sh` | Configures RBAC permissions | 1 min |

### Utility Scripts

| Script | Description |
|--------|-------------|
| `verify-environment.sh` | Comprehensive environment verification |
| `quick-test.sh` | Quick cluster functionality test |
| `cleanup.sh` | Remove cluster and resources |
| `setup.sh` | Master orchestration script ⭐ |

## Common Commands

```bash
# View cluster info
kubectl cluster-info
kubectl get nodes
kubectl get pods -A

# View monitoring pods
kubectl get pods -n monitoring

# View logs
kubectl logs -n monitoring <pod-name>

# Delete cluster
kind delete cluster --name mcp-dev-cluster

# Recreate cluster
cd scripts
./create-cluster.sh
./deploy-monitoring.sh
./setup-rbac.sh

# Test service account permissions
kubectl auth can-i get pods --as=system:serviceaccount:default:mcp-server
```

## Common Workflows

### Fresh Install

```bash
cd scripts
./setup.sh
./verify-environment.sh
./quick-test.sh
```

### Reinstall Cluster Only

```bash
kind delete cluster --name mcp-dev-cluster
cd scripts
./create-cluster.sh
./deploy-monitoring.sh
./setup-rbac.sh
```

### Update Monitoring Stack

```bash
cd scripts
./deploy-monitoring.sh
# Choose "upgrade" when prompted
```

### Complete Removal

```bash
cd scripts
./cleanup.sh
```

## Cleanup

To remove the environment:

```bash
cd scripts
./cleanup.sh
```

**This removes:**

- kind cluster
- Monitoring stack
- RBAC resources
- (Optional) Docker resources
- (Optional) kmcp CLI

**This preserves:**

- Tool installations (Docker, kubectl, kind, Helm)
- Configuration files in lab directory

## Troubleshooting

### Docker Not Starting

**Issue**: Docker daemon is not running

**Solution**:

```bash
# macOS
open -a Docker

# Linux
sudo systemctl start docker
sudo systemctl enable docker
```

### kind Cluster Creation Fails

**Issue**: Port already in use

**Solution**:

```bash
# Delete existing cluster
kind delete cluster --name mcp-dev-cluster

# Edit config/kind-config.yaml to use different ports if needed
# Recreate cluster
cd scripts
./create-cluster.sh
```

### Prometheus Pods Not Starting

**Issue**: Insufficient resources

**Solution**:

```bash
# Increase Docker resources
# Docker Desktop -> Preferences -> Resources
# Set Memory to at least 8GB

# Or reduce resource requests
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.resources.requests.memory=512Mi
```

### kubectl Context Issues

**Issue**: Cannot connect to cluster

**Solution**:

```bash
# List contexts
kubectl config get-contexts

# Set correct context
kubectl config use-context kind-mcp-dev-cluster

# Verify
kubectl cluster-info
```

### Monitoring Pods Failing

**Issue**: Pods in CrashLoopBackOff or Pending state

**Solution**:

```bash
# Check resources
kubectl top nodes

# View pod status
kubectl describe pod -n monitoring <pod-name>

# View logs
kubectl logs -n monitoring <pod-name>

# Restart deployment
kubectl rollout restart -n monitoring deployment/prometheus-grafana
```

### Port Conflicts

**Issue**: Ports 30090, 30030, or other ports already in use

**Solution**:

```bash
# Delete cluster
kind delete cluster --name mcp-dev-cluster

# Edit config/kind-config.yaml to use different ports
# Recreate cluster
cd scripts
./create-cluster.sh
```

## Features Overview

### Installation Scripts

- ✅ Multi-platform support (macOS/Linux)
- ✅ Version checking and validation
- ✅ Idempotent operations (safe to run multiple times)
- ✅ Comprehensive error handling
- ✅ Progress indicators and colored output
- ✅ Shell autocomplete configuration

### Cluster Configuration

- ✅ 3-node cluster (production-like setup)
- ✅ Port mappings for all services
- ✅ Node labels for workload scheduling
- ✅ Ingress-ready configuration
- ✅ High-availability considerations

### Monitoring Stack

- ✅ Prometheus with custom configuration
- ✅ Grafana with pre-configured dashboards
- ✅ NodePort access (no port-forward needed)
- ✅ Service monitors enabled
- ✅ Resource limits configured
- ✅ 7-day metric retention

### RBAC

- ✅ ServiceAccount for MCP servers
- ✅ ClusterRole with read permissions
- ✅ Role for namespace-specific operations
- ✅ Permission testing tools
- ✅ Security best practices

### kmcp CLI

- ✅ Python virtual environment isolation
- ✅ CLI with multiple subcommands
- ✅ Rich terminal output formatting
- ✅ Configuration file support
- ✅ kubectl integration
- ✅ Extensible command structure

**Note**: The kmcp CLI is a **mock implementation** for training purposes. In production, use the official Kagent kmcp CLI.

## Implementation Notes

### Design Decisions

**Modular Scripts**: Each script handles one specific task and can be run independently for maximum flexibility.

**Error Handling**: All scripts use `set -e` and provide clear, actionable error messages.

**Idempotency**: Scripts can be run multiple times safely without causing issues or duplicating resources.

**User Confirmation**: Interactive prompts prevent accidental operations and give users control.

**Color Output**: Enhanced readability with colored terminal output for better user experience.

### Monitoring Configuration

Prometheus and Grafana are configured with:

- NodePort services (port 30090 for Prometheus, 30030 for Grafana)
- Service monitor selectors disabled (monitors all services by default)
- Resource limits for cluster stability
- 7-day retention period for metrics
- Fixed admin password (`admin123`) for training purposes
- Pre-configured to scrape MCP server metrics

## Environment Variables

Scripts use these environment variables (with defaults):

| Variable | Default | Description |
|----------|---------|-------------|
| `KMCP_ENV_DIR` | `~/kmcp-env` | kmcp virtual environment |
| `KMCP_BIN_DIR` | `~/bin` | kmcp binary directory |
| `KMCP_CONFIG_DIR` | `~/.kmcp` | kmcp configuration |

## File Permissions

All scripts should be executable. This is done automatically by `setup.sh`, but you can set them manually:

```bash
cd scripts
chmod +x *.sh
```

## Deliverables

By the end of this lab, you should have:

- ✅ Docker installed and running
- ✅ kubectl configured and operational
- ✅ kind cluster with 3 nodes running
- ✅ Helm installed with common repositories added
- ✅ Prometheus and Grafana deployed and accessible
- ✅ kmcp CLI configured (optional)
- ✅ RBAC permissions set up
- ✅ All verification checks passing
- ✅ Understanding of the complete MCP development environment

## Next Steps

Once your environment is set up:

1. ✅ Save your cluster configuration
2. ✅ Bookmark Prometheus (http://localhost:30090) and Grafana (http://localhost:30030) URLs
3. ✅ Keep the verification script handy for future checks
4. ✅ Explore Prometheus and Grafana dashboards
5. ✅ Review RBAC permissions
6. ✅ Try kmcp commands (if installed)
7. ➡️ Proceed to [Lab 2: Building Your First MCP Server](../lab-02-first-mcp-server/README.md)

## Reference Commands

Quick reference for common operations:

```bash
# Cluster status
kubectl get nodes
kubectl get pods -A
kubectl cluster-info

# Access Prometheus (NodePort)
open http://localhost:30090

# Access Grafana (NodePort)
open http://localhost:30030

# Access via port-forward (alternative)
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# View logs
kubectl logs -n monitoring <pod-name>

# Verify environment
cd scripts
./verify-environment.sh

# Quick test
cd scripts
./quick-test.sh

# Delete and recreate cluster
kind delete cluster --name mcp-dev-cluster
cd scripts
./create-cluster.sh
./deploy-monitoring.sh
./setup-rbac.sh

# Complete cleanup
cd scripts
./cleanup.sh
```

## Support

For issues or questions:

1. Run `./verify-environment.sh` for comprehensive diagnostics
2. Check script error messages for specific guidance
3. Review logs: `kubectl logs -n <namespace> <pod-name>`
4. Consult the troubleshooting section above
5. Check [main troubleshooting guide](../../../docs/troubleshooting.md)
6. Ask your instructor for assistance

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kind Documentation](https://kind.sigs.k8s.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

---

**Estimated Completion Time**: 2 hours  
**Difficulty**: Beginner  
**Lab Type**: Environment Setup

**Ready to start?** Run `cd scripts && ./setup.sh` and let the automation do the work! 🚀
