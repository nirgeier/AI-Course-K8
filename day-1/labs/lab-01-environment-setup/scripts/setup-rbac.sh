#!/bin/bash

# setup-rbac.sh - Setup RBAC permissions for MCP servers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Setting up RBAC Permissions ===${NC}"
echo ""

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RBAC_FILE="${SCRIPT_DIR}/../config/mcp-rbac.yaml"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl is not installed${NC}"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}✗ Kubernetes cluster is not accessible${NC}"
    exit 1
fi

# Apply RBAC configuration
if [ -f "${RBAC_FILE}" ]; then
    echo -e "${GREEN}Applying RBAC configuration...${NC}"
    kubectl apply -f "${RBAC_FILE}"
    echo -e "${GREEN}✓ RBAC configuration applied${NC}"
else
    echo -e "${RED}✗ RBAC configuration file not found: ${RBAC_FILE}${NC}"
    exit 1
fi

# Verify ServiceAccount
echo ""
echo -e "${GREEN}Verifying RBAC setup...${NC}"

if kubectl get serviceaccount mcp-server -n default &> /dev/null; then
    echo -e "${GREEN}✓ ServiceAccount 'mcp-server' created${NC}"
else
    echo -e "${RED}✗ ServiceAccount 'mcp-server' not found${NC}"
fi

if kubectl get clusterrole mcp-server-role &> /dev/null; then
    echo -e "${GREEN}✓ ClusterRole 'mcp-server-role' created${NC}"
else
    echo -e "${RED}✗ ClusterRole 'mcp-server-role' not found${NC}"
fi

if kubectl get clusterrolebinding mcp-server-binding &> /dev/null; then
    echo -e "${GREEN}✓ ClusterRoleBinding 'mcp-server-binding' created${NC}"
else
    echo -e "${RED}✗ ClusterRoleBinding 'mcp-server-binding' not found${NC}"
fi

# Test permissions
echo ""
echo -e "${GREEN}Testing permissions...${NC}"

TESTS=(
    "get pods"
    "list pods"
    "get services"
    "get deployments"
    "list nodes"
)

for test in "${TESTS[@]}"; do
    if kubectl auth can-i ${test} --as=system:serviceaccount:default:mcp-server &> /dev/null; then
        echo -e "${GREEN}✓ Can ${test}${NC}"
    else
        echo -e "${RED}✗ Cannot ${test}${NC}"
    fi
done

echo ""
echo -e "${GREEN}=== RBAC setup completed! ===${NC}"
