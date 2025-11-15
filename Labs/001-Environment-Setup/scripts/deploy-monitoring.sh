#!/bin/bash

#==============================================================================
# deploy-monitoring.sh - Deploy Prometheus and Grafana monitoring stack
#
# DESCRIPTION:
#   Deploys a comprehensive monitoring stack using Prometheus and Grafana via
#   Helm charts on the kind Kubernetes cluster. This script provides observability
#   and metrics collection for the Lab 01 development environment with pre-
#   configured dashboards and monitoring capabilities.
#
# USAGE:
#   ./deploy-monitoring.sh
#
# PREREQUISITES:
#   - kind cluster 'mcp-dev-cluster' must be running
#   - kubectl configured and accessible
#   - Helm 3.x installed and configured
#   - Docker running (for cluster access)
#
# FEATURES:
#   - Automated Helm repository configuration
#   - Namespace creation and management
#   - Prometheus and Grafana deployment via kube-prometheus-stack
#   - NodePort service exposure for easy access
#   - Pre-configured Grafana admin credentials
#   - Resource limits and retention policies
#   - Interactive upgrade option for existing installations
#   - Comprehensive deployment validation and status reporting
#
# CONFIGURATION:
#   - Namespace: monitoring
#   - Prometheus NodePort: 30090
#   - Grafana NodePort: 30030
#   - Grafana admin password: admin123
#   - Prometheus retention: 7 days
#   - Memory request: 512Mi
#   - CPU request: 250m
#
# MONITORING COMPONENTS:
#   - Prometheus server for metrics collection
#   - Grafana for visualization and dashboards
#   - AlertManager for alert handling
#   - Node Exporter for node metrics
#   - kube-state-metrics for Kubernetes object metrics
#   - Prometheus Operator for CRD management
#
# ACCESS METHODS:
#   - Direct NodePort access (localhost:30090, localhost:30030)
#   - kubectl port-forward for secure tunneling
#   - Service discovery within cluster
#
# EXIT CODES:
#   0 - Success or user cancellation
#   1 - Missing dependencies or cluster inaccessible
#
# AUTHOR: AI Course Lab Environment Setup
# VERSION: 1.0
#==============================================================================

# deploy-monitoring.sh - Deploy Prometheus and Grafana monitoring stack

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Deploying Monitoring Stack ===${NC}"
echo ""

# Configuration
NAMESPACE="monitoring"
RELEASE_NAME="prometheus"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl is not installed${NC}"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo -e "${RED}✗ Helm is not installed${NC}"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}✗ Kubernetes cluster is not accessible${NC}"
    echo "Please create the cluster first using ./06-create-cluster.sh"
    exit 1
fi

# Create monitoring namespace
echo -e "${GREEN}Creating monitoring namespace...${NC}"
if kubectl get namespace "${NAMESPACE}" &> /dev/null; then
    echo -e "${YELLOW}Namespace '${NAMESPACE}' already exists${NC}"
else
    kubectl create namespace "${NAMESPACE}"
    echo -e "${GREEN}✓ Namespace created${NC}"
fi

# Add Helm repositories if not already added
echo ""
echo -e "${GREEN}Configuring Helm repositories...${NC}"
if ! helm repo list | grep -q prometheus-community; then
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
fi

if ! helm repo list | grep -q grafana; then
    helm repo add grafana https://grafana.github.io/helm-charts
fi  
kubectl get pods -n ${NAMESPACE}

echo ""
echo -e "${YELLOW}Note: You can access services using NodePort (30090 for Prometheus, 30030 for Grafana)${NC}"
echo -e "${YELLOW}      or use port-forward commands shown above${NC}"
