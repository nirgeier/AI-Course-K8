#!/bin/bash

#==============================================================================
# 06-create-cluster.sh - Create kind Kubernetes cluster
#
# DESCRIPTION:
#   Creates a local Kubernetes cluster using kind (Kubernetes in Docker).
#   This script sets up a development environment for Kubernetes applications
#   with proper configuration and validation.
#
# USAGE:
#   ./06-create-cluster.sh
#
# PREREQUISITES:
#   - kind must be installed (use ./install-kind.sh)
#   - Docker must be running
#   - kubectl should be available for cluster verification
#
# FEATURES:
#   - Creates a kind cluster with custom or default configuration
#   - Checks for existing cluster and offers recreation option
#   - Validates Docker daemon availability
#   - Waits for cluster readiness before completion
#   - Displays cluster information and node status
#
# CONFIGURATION:
#   - Cluster name: mcp-dev-cluster
#   - Config file: ../config/kind-config.yaml (if available)
#   - Timeout: 300 seconds for node readiness
#
# EXIT CODES:
#   0 - Success
#   1 - Missing dependencies or Docker not running
#
# AUTHOR: AI Course Lab Environment Setup
# VERSION: 1.0
#==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Creating kind Kubernetes Cluster ===${NC}"
echo ""

# Configuration variables
CLUSTER_NAME="mcp-dev-cluster"  # Name of the kind cluster to create
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/kind-config.yaml"  # Path to kind configuration file

# Dependency validation: Check if kind is installed
if ! command -v kind &> /dev/null; then
    echo -e "${RED}✗ kind is not installed${NC}"
    echo "Please run ./install-kind.sh first"
    exit 1
fi

# Docker daemon validation: Ensure Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}✗ Docker is not running${NC}"
    echo "Please start Docker and try again"
    exit 1
fi

# Cluster existence check: Prevent accidental overwrites
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${YELLOW}Cluster '${CLUSTER_NAME}' already exists${NC}"
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing cluster..."
        kind delete cluster --name "${CLUSTER_NAME}"
    else
        echo "Using existing cluster"
        kubectl cluster-info --context "kind-${CLUSTER_NAME}"
        exit 0
    fi
fi

# Cluster creation: Use custom config if available, otherwise use defaults
echo -e "${GREEN}Creating cluster '${CLUSTER_NAME}'...${NC}"
echo "This may take a few minutes..."
echo ""

if [ -f "${CONFIG_FILE}" ]; then
    # Create cluster with custom configuration file
    kind create cluster --config "${CONFIG_FILE}"
else
    echo -e "${YELLOW}Config file not found at ${CONFIG_FILE}${NC}"
    echo "Creating cluster with default configuration..."
    # Create cluster with default settings and explicit name
    kind create cluster --name "${CLUSTER_NAME}"
fi

# Cluster readiness validation: Wait for all nodes to be ready
echo ""
echo -e "${GREEN}Waiting for cluster to be ready...${NC}"
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Success confirmation: Display cluster information
echo ""
echo -e "${GREEN}Cluster created successfully!${NC}"
echo ""
kubectl cluster-info --context "kind-${CLUSTER_NAME}"

echo ""
echo -e "${GREEN}Nodes:${NC}"
kubectl get nodes

echo ""
echo -e "${GREEN}=== Cluster creation completed! ===${NC}"
echo -e "${YELLOW}Context set to: kind-${CLUSTER_NAME}${NC}"
