# Lab 01 Environment Setup - Complete Implementation

## Quick Start 🚀

```bash
cd /Users/nirg/repositories/AI-Course/day-1/labs/lab-01-environment-setup/scripts
chmod +x setup.sh
./setup.sh
```

## What's Included

This implementation provides a complete, production-ready environment setup for Lab 01:

### ✅ Installation Scripts
All tools automated for macOS and Linux:
- Docker
- kubectl
- kind
- Helm
- kmcp CLI (Python-based mock implementation)

### ✅ Cluster Configuration
- 3-node Kubernetes cluster (1 control-plane, 2 workers)
- Configured port mappings for all services
- Node labels for workload placement

### ✅ Monitoring Stack
- Prometheus with custom configuration
- Grafana with admin credentials
- Pre-configured for MCP server metrics

### ✅ Security & RBAC
- ServiceAccount for MCP servers
- ClusterRole with appropriate permissions
- RoleBindings for namespace operations

### ✅ Verification & Testing
- Comprehensive environment verification
- Quick functional tests
- Error detection and reporting

### ✅ Utilities
- Master setup script
- Cleanup script
- Documentation

## Directory Structure

```
lab-01-environment-setup/
├── README.md (this file)
├── scripts/
│   ├── README.md                    # Script documentation
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
    ├── README.md                    # Configuration documentation
    ├── kind-config.yaml             # kind cluster configuration
    └── mcp-rbac.yaml                # RBAC resources
```

## Installation Options

### Option 1: Automated Setup (Recommended) ⭐
Run the master script that handles everything:
```bash
cd scripts
./setup.sh
```

**Features:**
- Interactive prompts
- Step-by-step confirmation
- Error handling
- Progress tracking
- Automatic verification

**Duration:** ~20-30 minutes

### Option 2: Manual Step-by-Step
Install components individually:

```bash
cd scripts

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

### Option 3: Custom Installation
Use individual scripts for specific components.

## Verification

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

## Quick Test

Run a functional test:

```bash
cd scripts
./quick-test.sh
```

This creates a test pod, verifies connectivity, and cleans up.

## Access Services

### Prometheus
```bash
# NodePort (recommended)
open http://localhost:30090

# Or port-forward
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
open http://localhost:9090
```

### Grafana
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
./06-create-cluster.sh
```

## Troubleshooting

### Docker not running
```bash
# macOS
open -a Docker

# Linux
sudo systemctl start docker
```

### Cluster not accessible
```bash
kubectl config use-context kind-mcp-dev-cluster
kubectl cluster-info
```

### Monitoring pods failing
```bash
# Check resources
kubectl top nodes

# View pod status
kubectl describe pod -n monitoring <pod-name>

# Restart deployment
kubectl rollout restart -n monitoring deployment/prometheus-grafana
```

### Port conflicts
```bash
# Delete cluster
kind delete cluster --name mcp-dev-cluster

# Edit config/kind-config.yaml to use different ports
# Recreate cluster
./06-create-cluster.sh
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
- Tool installations
- Configuration files

## Requirements

### Hardware
- **RAM:** 8GB minimum (16GB recommended)
- **CPU:** 2+ cores (4+ recommended)
- **Disk:** 20GB free space
- **Network:** Internet connectivity required

### Software
- macOS 10.15+ or Linux (Ubuntu 20.04+, Debian 10+, RHEL/CentOS 8+)
- Admin/sudo access
- Homebrew (macOS) or apt/yum (Linux)

## Features

### Installation Scripts
- ✅ Multi-platform support (macOS/Linux)
- ✅ Version checking
- ✅ Idempotent operations
- ✅ Error handling
- ✅ Progress indicators
- ✅ Autocomplete configuration

### Cluster Configuration
- ✅ 3-node cluster (production-like)
- ✅ Port mappings for all services
- ✅ Node labels for scheduling
- ✅ Ingress-ready configuration

### Monitoring Stack
- ✅ Prometheus with custom config
- ✅ Grafana with dashboards
- ✅ NodePort access (no port-forward needed)
- ✅ Service monitors enabled
- ✅ Resource limits configured

### RBAC
- ✅ ServiceAccount for MCP servers
- ✅ ClusterRole with read permissions
- ✅ Role for namespace operations
- ✅ Permission testing

### kmcp CLI
- ✅ Python virtual environment
- ✅ CLI with subcommands
- ✅ Rich terminal output
- ✅ Configuration file
- ✅ kubectl integration

## Next Steps

After completing Lab 01 setup:

1. ✅ Verify environment: `./verify-environment.sh`
2. ✅ Test cluster: `./quick-test.sh`
3. ✅ Explore Prometheus and Grafana
4. ✅ Review RBAC permissions
5. ✅ Try kmcp commands
6. ➡️ Proceed to [Lab 02: Building Your First MCP Server](../lab-02-first-mcp-server/README.md)

## Support

For issues or questions:

1. Run `./verify-environment.sh` for diagnostics
2. Check script error messages
3. Review logs: `kubectl logs -n <namespace> <pod-name>`
4. Consult [main troubleshooting guide](../../../docs/troubleshooting.md)

## Implementation Notes

### Design Decisions

**Modular Scripts:** Each script handles one specific task and can be run independently.

**Error Handling:** All scripts use `set -e` and provide clear error messages.

**Idempotency:** Scripts can be run multiple times safely.

**User Confirmation:** Interactive prompts prevent accidental operations.

**Color Output:** Enhanced readability with colored terminal output.

### kmcp CLI Implementation

The kmcp CLI is a **mock implementation** for training purposes:
- Python-based with Click framework
- Rich library for formatted output
- Configuration file support
- Extensible command structure

In production, you would use the official Kagent kmcp CLI.

### Monitoring Configuration

Prometheus and Grafana are configured with:
- NodePort services (no port-forward needed)
- Service monitor selectors disabled (monitors all services)
- Resource limits for stability
- 7-day retention period
- Fixed admin password

## License

Educational use only.

---

**Ready to start?** Run `./setup.sh` and let the automation do the work! 🚀
