#!/bin/bash

#==============================================================================
# cleanup.sh - Cleanup script for Lab 01 environment setup
#
# DESCRIPTION:
#   Comprehensive cleanup script for removing the Lab 01 Kubernetes development
#   environment. This script safely removes the kind cluster, monitoring stack,
#   RBAC resources, and optionally cleans up Docker resources and kmcp CLI
#   installation while preserving core tools and configuration files.
#
# USAGE:
#   ./cleanup.sh
#
# PREREQUISITES:
#   - kind cluster 'mcp-dev-cluster' (optional - script handles if not present)
#   - Docker running (for Docker cleanup option)
#   - kubectl configured (for config cleanup)
#
# FEATURES:
#   - Interactive confirmation prompts for safety
#   - Selective cleanup with user choices
#   - Preserves core development tools (Docker, kubectl, kind, Helm)
#   - Cleans kubectl config entries for removed cluster
#   - Optional Docker resource cleanup
#   - Optional kmcp CLI removal with configuration
#   - Comprehensive cleanup summary and reinstallation guidance
#
# CLEANUP TARGETS:
#   - kind Kubernetes cluster (mcp-dev-cluster)
#   - Monitoring stack (Prometheus & Grafana)
#   - RBAC resources and deployed applications
#   - kubectl config entries for the cluster
#   - Docker unused resources (optional)
#   - kmcp CLI and virtual environment (optional)
#   - kmcp configuration directory (optional)
#
# PRESERVED ITEMS:
#   - Docker, kubectl, kind, Helm binaries
#   - Configuration files in script directory
#   - Other kubectl contexts and clusters
#
# EXIT CODES:
#   0 - Success or user cancellation
#
# AUTHOR: AI Course Lab Environment Setup
# VERSION: 1.0
#==============================================================================

# cleanup.sh - Cleanup script for Lab 01 environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Lab 01 Environment Cleanup ===${NC}"
echo ""

# Function to confirm action
confirm() {
    read -p "$1 (y/N): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Warning
echo -e "${RED}WARNING: This script will remove:${NC}"
echo "  • kind Kubernetes cluster (mcp-dev-cluster)"
echo "  • Monitoring stack (Prometheus & Grafana)"
echo "  • RBAC resources"
echo "  • All deployed applications"
echo ""
echo -e "${YELLOW}It will NOT remove:${NC}"
echo "  • Docker, kubectl, kind, Helm binaries"
echo "  • kmcp CLI"
echo "  • Configuration files in this directory"
echo ""

if ! confirm "Are you sure you want to proceed?"; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Starting cleanup...${NC}"
echo ""

# Step 1: Delete kind cluster
echo -e "${BLUE}[1/3] Deleting kind cluster...${NC}"
if kind get clusters 2>/dev/null | grep -q "mcp-dev-cluster"; then
    kind delete cluster --name mcp-dev-cluster
    echo -e "${GREEN}✓ Cluster deleted${NC}"
else
    echo -e "${YELLOW}⚠ Cluster 'mcp-dev-cluster' not found${NC}"
fi
echo ""

# Step 2: Clean up Docker resources (optional)
echo -e "${BLUE}[2/3] Cleaning up Docker resources...${NC}"
if confirm "Remove unused Docker images and volumes?"; then
    docker system prune -f
    echo -e "${GREEN}✓ Docker resources cleaned${NC}"
else
    echo -e "${YELLOW}⚠ Skipping Docker cleanup${NC}"
fi
echo ""

# Step 3: Clean up temporary files
echo -e "${BLUE}[3/3] Cleaning up temporary files...${NC}"
if [ -d "${HOME}/.kube" ]; then
    # Backup kubectl config
    if [ -f "${HOME}/.kube/config" ]; then
        # Remove kind cluster entries from kubectl config
        kubectl config delete-context kind-mcp-dev-cluster 2>/dev/null || true
        kubectl config delete-cluster kind-mcp-dev-cluster 2>/dev/null || true
        kubectl config delete-user kind-mcp-dev-cluster 2>/dev/null || true
        echo -e "${GREEN}✓ Removed kind cluster from kubectl config${NC}"
    fi
fi
echo ""

# Optional: Remove kmcp
if confirm "Remove kmcp CLI installation?"; then
    echo -e "${YELLOW}Removing kmcp CLI...${NC}"
    
    # Remove virtual environment
    if [ -d "${HOME}/kmcp-env" ]; then
        rm -rf "${HOME}/kmcp-env"
        echo -e "${GREEN}✓ Removed kmcp virtual environment${NC}"
    fi
    
    # Remove kmcp binary
    if [ -f "${HOME}/bin/kmcp" ]; then
        rm -f "${HOME}/bin/kmcp"
        echo -e "${GREEN}✓ Removed kmcp binary${NC}"
    fi
    
    # Remove kmcp config (optional)
    if confirm "Remove kmcp configuration directory (~/.kmcp)?"; then
        if [ -d "${HOME}/.kmcp" ]; then
            rm -rf "${HOME}/.kmcp"
            echo -e "${GREEN}✓ Removed kmcp configuration${NC}"
        fi
    fi
fi
echo ""

# Summary
echo -e "${GREEN}=== Cleanup completed! ===${NC}"
echo ""
echo -e "${BLUE}Remaining installations:${NC}"
echo "  • Docker (if installed)"
echo "  • kubectl (if installed)"
echo "  • kind (if installed)"
echo "  • Helm (if installed)"
echo ""
echo -e "${YELLOW}To reinstall the environment, run:${NC}"
echo -e "  ${GREEN}./setup.sh${NC}"
echo ""
echo -e "${YELLOW}To completely remove all tools, you'll need to manually uninstall:${NC}"
echo "  • Docker: brew uninstall --cask docker (macOS)"
echo "  • kubectl: brew uninstall kubectl (macOS)"
echo "  • kind: brew uninstall kind (macOS)"
echo "  • Helm: brew uninstall helm (macOS)"
echo ""
