# Lab 01 Setup Scripts - Quick Reference

This directory contains all the automation scripts for Lab 01 environment setup.

## Quick Start

### Option 1: Automated Full Setup (Recommended)
```bash
cd scripts
chmod +x setup.sh
./setup.sh
```

### Option 2: Manual Step-by-Step Setup
```bash
cd scripts
chmod +x *.sh

# 1. Install tools
./install-docker.sh
./install-kubectl.sh
./install-kind.sh
./install-helm.sh
./install-k9s.sh

# 2. Create cluster and deploy services
./create-cluster.sh
./deploy-monitoring.sh
./setup-rbac.sh

# 3. (Optional) Install kmcp CLI
./install-kmcp.sh

# 4. Verify installation
./verify-environment.sh
```

## Available Scripts

### Installation Scripts

| Script | Description | Duration |
|--------|-------------|----------|
| `install-docker.sh` | Installs Docker for macOS/Linux | 5-10 min |
| `install-kubectl.sh` | Installs kubectl CLI | 2-5 min |
| `install-kind.sh` | Installs kind (Kubernetes in Docker) | 2-5 min |
| `install-helm.sh` | Installs Helm package manager | 2-5 min |
| `install-k9s.sh` | Installs k9s Kubernetes CLI UI | 2-5 min |
| `install-kmcp.sh` | Installs kmcp CLI (optional) | 5 min |
| `install-python-prereqs.sh` | Installs Python prerequisites | 3-5 min |
| `install-uv.sh` | Installs UV (Python package manager) - macOS/Linux | 2-5 min |
| `install-uv.ps1` | Installs UV (Python package manager) - Windows | 2-5 min |

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

### Master Script

| Script | Description |
|--------|-------------|
| `setup.sh` | Orchestrates entire setup process |

## Script Details

### setup.sh
**Master setup script** that runs all installation steps in order with user confirmation at each step.

**Usage:**
```bash
./setup.sh
```

**Features:**
- Interactive prompts
- Error handling
- Progress tracking
- Final verification

### verify-environment.sh
**Comprehensive verification** of all installed components.

**Usage:**
```bash
./verify-environment.sh
```

**Checks:**
- ✓ Docker installation and status
- ✓ kubectl configuration
- ✓ kind installation
- ✓ Helm and repositories
- ✓ Cluster accessibility
- ✓ Monitoring stack (Prometheus/Grafana)
- ✓ RBAC configuration
- ✓ kmcp CLI (if installed)

**Exit codes:**
- `0` - All checks passed
- `1` - Some checks failed

### quick-test.sh
**Quick functional test** to verify cluster is working.

**Usage:**
```bash
./quick-test.sh
```

**Tests:**
- Creates test pod with mcp-server ServiceAccount
- Verifies network connectivity
- Checks monitoring endpoints
- Creates test service
- Cleans up test resources

### cleanup.sh
**Complete environment teardown** - removes cluster and resources.

**Usage:**
```bash
./cleanup.sh
```

**Removes:**
- kind cluster
- Monitoring stack
- RBAC resources
- Optionally: Docker resources, kmcp CLI

**Preserves:**
- Tool installations (Docker, kubectl, kind, Helm)
- Configuration files in lab directory

## Troubleshooting

### Docker not starting
```bash
# macOS
open -a Docker

# Linux
sudo systemctl start docker
```

### Port already in use
```bash
# Delete existing cluster
kind delete cluster --name mcp-dev-cluster

# Recreate
./06-create-cluster.sh
```

### Insufficient resources
Increase Docker Desktop resources:
- Memory: 8GB minimum
- CPU: 4 cores recommended

### kubectl context issues
```bash
# List contexts
kubectl config get-contexts

# Set correct context
kubectl config use-context kind-mcp-dev-cluster
```

### Monitoring pods not starting
```bash
# Check pod status
kubectl get pods -n monitoring

# Check logs
kubectl logs -n monitoring <pod-name>

# Restart deployment
kubectl rollout restart -n monitoring deployment/prometheus-grafana
```

## Access Information

### Prometheus
- **NodePort URL**: http://localhost:30090
- **Port-forward**: `kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090`

### Grafana
- **NodePort URL**: http://localhost:30030
- **Port-forward**: `kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80`
- **Username**: admin
- **Password**: admin123

## Environment Variables

Scripts use these environment variables (with defaults):

| Variable | Default | Description |
|----------|---------|-------------|
| `KMCP_ENV_DIR` | `~/kmcp-env` | kmcp virtual environment |
| `KMCP_BIN_DIR` | `~/bin` | kmcp binary directory |
| `KMCP_CONFIG_DIR` | `~/.kmcp` | kmcp configuration |

## Requirements

### Hardware
- 8GB RAM minimum
- 20GB free disk space
- Internet connectivity

### Operating Systems
- macOS (Intel/Apple Silicon)
- Linux (Ubuntu/Debian/RHEL/CentOS)
- Windows WSL2 (not fully tested)

### Prerequisites
- Admin/sudo access
- Homebrew (macOS) or apt/yum (Linux)

## Common Workflows

### Fresh Install
```bash
./setup.sh
./verify-environment.sh
./quick-test.sh
```

### Reinstall Cluster Only
```bash
kind delete cluster --name mcp-dev-cluster
./create-cluster.sh
./deploy-monitoring.sh
./setup-rbac.sh
```

### Update Monitoring Stack
```bash
./deploy-monitoring.sh
# Choose "upgrade" when prompted
```

### Complete Removal
```bash
./cleanup.sh
# Then manually uninstall tools if desired
```

## File Permissions

All scripts should be executable:
```bash
chmod +x *.sh
```

This is done automatically by `setup.sh`.

## Support

If you encounter issues:

1. Check `verify-environment.sh` output
2. Review script error messages
3. Check [main troubleshooting guide](../../../docs/troubleshooting.md)
4. Review logs: `kubectl logs -n <namespace> <pod-name>`

## Next Steps

After successful setup:

1. ✅ Verify environment: `./verify-environment.sh`
2. ✅ Test cluster: `./quick-test.sh`
3. ✅ Access Grafana and Prometheus
4. ✅ Proceed to [Lab 02: Building Your First MCP Server](../../lab-02-first-mcp-server/README.md)
