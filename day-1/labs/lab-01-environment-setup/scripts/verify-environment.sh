#!/bin/bash

# verify-environment.sh - Comprehensive environment verification script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Environment Verification Script for Lab 01       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Track overall status
ERRORS=0
WARNINGS=0

# Function to check command availability and version
check_command() {
    local cmd=$1
    local name=$2
    
    echo -e "${YELLOW}Checking ${name}...${NC}"
    if command -v $cmd &> /dev/null; then
        echo -e "${GREEN}  ✓ ${name} is installed${NC}"
        local version_output=$($cmd version 2>&1 | head -n 1)
        echo -e "    Version: ${version_output}"
        return 0
    else
        echo -e "${RED}  ✗ ${name} is NOT installed${NC}"
        ((ERRORS++))
        return 1
    fi
}

# Function to check Docker status
check_docker() {
    echo -e "${YELLOW}Checking Docker...${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}  ✗ Docker is NOT installed${NC}"
        ((ERRORS++))
        return 1
    fi
    
    echo -e "${GREEN}  ✓ Docker is installed${NC}"
    docker --version
    
    if docker info &> /dev/null; then
        echo -e "${GREEN}  ✓ Docker daemon is running${NC}"
        
        # Check Docker resources
        local total_mem=$(docker info 2>/dev/null | grep "Total Memory" | awk '{print $3}')
        echo -e "    Total Memory: ${total_mem}"
        
        return 0
    else
        echo -e "${RED}  ✗ Docker daemon is NOT running${NC}"
        ((ERRORS++))
        return 1
    fi
}

# Function to check Kubernetes cluster
check_cluster() {
    echo -e "${YELLOW}Checking Kubernetes cluster...${NC}"
    
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}  ✗ Kubernetes cluster is NOT accessible${NC}"
        ((ERRORS++))
        return 1
    fi
    
    echo -e "${GREEN}  ✓ Kubernetes cluster is running${NC}"
    
    # Get cluster info
    local context=$(kubectl config current-context 2>/dev/null)
    echo -e "    Current context: ${context}"
    
    # Check nodes
    local node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    local ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c Ready || echo "0")
    
    echo -e "    Total nodes: ${node_count}"
    echo -e "    Ready nodes: ${ready_nodes}"
    
    if [ "$node_count" -eq "$ready_nodes" ] && [ "$node_count" -gt 0 ]; then
        echo -e "${GREEN}  ✓ All nodes are Ready${NC}"
        kubectl get nodes
    else
        echo -e "${RED}  ✗ Some nodes are not Ready${NC}"
        kubectl get nodes
        ((ERRORS++))
    fi
}

# Function to check monitoring stack
check_monitoring() {
    echo -e "${YELLOW}Checking monitoring stack...${NC}"
    
    if ! kubectl get namespace monitoring &> /dev/null; then
        echo -e "${RED}  ✗ Monitoring namespace does NOT exist${NC}"
        ((ERRORS++))
        return 1
    fi
    
    echo -e "${GREEN}  ✓ Monitoring namespace exists${NC}"
    
    # Check Prometheus
    if kubectl get pods -n monitoring -l app=kube-prometheus-stack-prometheus &> /dev/null; then
        local prom_ready=$(kubectl get pods -n monitoring -l app=kube-prometheus-stack-prometheus --no-headers 2>/dev/null | grep -c "Running" || echo "0")
        if [ "$prom_ready" -gt 0 ]; then
            echo -e "${GREEN}  ✓ Prometheus is running${NC}"
        else
            echo -e "${RED}  ✗ Prometheus is NOT running${NC}"
            ((ERRORS++))
        fi
    else
        echo -e "${YELLOW}  ⚠ Prometheus pods not found${NC}"
        ((WARNINGS++))
    fi
    
    # Check Grafana
    if kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana &> /dev/null; then
        local grafana_ready=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana --no-headers 2>/dev/null | grep -c "Running" || echo "0")
        if [ "$grafana_ready" -gt 0 ]; then
            echo -e "${GREEN}  ✓ Grafana is running${NC}"
        else
            echo -e "${RED}  ✗ Grafana is NOT running${NC}"
            ((ERRORS++))
        fi
    else
        echo -e "${YELLOW}  ⚠ Grafana pods not found${NC}"
        ((WARNINGS++))
    fi
    
    # Show all monitoring pods
    echo ""
    echo -e "${BLUE}  Monitoring pods status:${NC}"
    kubectl get pods -n monitoring
}

# Function to check RBAC configuration
check_rbac() {
    echo -e "${YELLOW}Checking RBAC configuration...${NC}"
    
    # Check ServiceAccount
    if kubectl get serviceaccount mcp-server -n default &> /dev/null; then
        echo -e "${GREEN}  ✓ ServiceAccount 'mcp-server' exists${NC}"
    else
        echo -e "${RED}  ✗ ServiceAccount 'mcp-server' does NOT exist${NC}"
        ((ERRORS++))
    fi
    
    # Check ClusterRole
    if kubectl get clusterrole mcp-server-role &> /dev/null; then
        echo -e "${GREEN}  ✓ ClusterRole 'mcp-server-role' exists${NC}"
    else
        echo -e "${RED}  ✗ ClusterRole 'mcp-server-role' does NOT exist${NC}"
        ((ERRORS++))
    fi
    
    # Check ClusterRoleBinding
    if kubectl get clusterrolebinding mcp-server-binding &> /dev/null; then
        echo -e "${GREEN}  ✓ ClusterRoleBinding 'mcp-server-binding' exists${NC}"
    else
        echo -e "${RED}  ✗ ClusterRoleBinding 'mcp-server-binding' does NOT exist${NC}"
        ((ERRORS++))
    fi
    
    # Test some permissions
    echo -e "${BLUE}  Testing permissions:${NC}"
    local tests=("get pods" "list services" "get deployments")
    for test in "${tests[@]}"; do
        if kubectl auth can-i ${test} --as=system:serviceaccount:default:mcp-server &> /dev/null; then
            echo -e "${GREEN}    ✓ Can ${test}${NC}"
        else
            echo -e "${RED}    ✗ Cannot ${test}${NC}"
            ((WARNINGS++))
        fi
    done
}

# Function to check kmcp CLI
check_kmcp() {
    echo -e "${YELLOW}Checking kmcp CLI...${NC}"
    
    # Add bin to PATH for this check
    export PATH="${HOME}/bin:${PATH}"
    
    if command -v kmcp &> /dev/null; then
        echo -e "${GREEN}  ✓ kmcp CLI is installed${NC}"
        kmcp version 2>/dev/null || echo "    (version command not available)"
        
        # Check config
        if [ -f "${HOME}/.kmcp/config.yaml" ]; then
            echo -e "${GREEN}  ✓ kmcp configuration file exists${NC}"
        else
            echo -e "${YELLOW}  ⚠ kmcp configuration file not found${NC}"
            ((WARNINGS++))
        fi
    else
        echo -e "${YELLOW}  ⚠ kmcp CLI is NOT installed${NC}"
        echo -e "    (This is optional for lab 01)"
        ((WARNINGS++))
    fi
}

# Function to check Helm repositories
check_helm_repos() {
    echo -e "${YELLOW}Checking Helm repositories...${NC}"
    
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}  ✗ Helm is NOT installed${NC}"
        ((ERRORS++))
        return 1
    fi
    
    local expected_repos=("prometheus-community" "grafana" "bitnami")
    local repos=$(helm repo list -o json 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
    
    for repo in "${expected_repos[@]}"; do
        if echo "$repos" | grep -q "^${repo}$"; then
            echo -e "${GREEN}  ✓ Repository '${repo}' is configured${NC}"
        else
            echo -e "${YELLOW}  ⚠ Repository '${repo}' is NOT configured${NC}"
            ((WARNINGS++))
        fi
    done
}

# Function to show summary
show_summary() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              Verification Summary                  ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}✓ All checks passed! Your environment is ready.${NC}"
        return 0
    elif [ $ERRORS -eq 0 ]; then
        echo -e "${YELLOW}⚠ ${WARNINGS} warning(s) found, but environment should work.${NC}"
        return 0
    else
        echo -e "${RED}✗ ${ERRORS} error(s) and ${WARNINGS} warning(s) found.${NC}"
        echo -e "${RED}Please fix the errors before proceeding.${NC}"
        return 1
    fi
}

# Main execution
main() {
    echo -e "${BLUE}Starting environment verification...${NC}"
    echo ""
    
    # Run all checks
    check_docker
    echo ""
    
    check_command kubectl "kubectl"
    echo ""
    
    check_command kind "kind"
    echo ""
    
    check_command helm "Helm"
    echo ""
    
    check_cluster
    echo ""
    
    check_monitoring
    echo ""
    
    check_rbac
    echo ""
    
    check_kmcp
    echo ""
    
    check_helm_repos
    
    # Show summary
    show_summary
}

# Run main function
main

exit $?
