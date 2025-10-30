#!/bin/bash

# setup.sh - Master setup script for Lab 01 environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Banner
echo -e "${BLUE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║          Lab 01: Environment Setup - Master Script           ║
║                                                              ║
║  This script will install and configure:                     ║
║  • Docker                                                    ║
║  • kubectl                                                   ║
║  • kind                                                      ║
║  • Helm                                                      ║
║  • uv                                                      ║
║  • kmcp CLI                                                  ║
║  • Kubernetes cluster                                        ║
║  • Prometheus & Grafana monitoring                           ║
║  • RBAC permissions                                          ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Function to print section header
section() {
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA} $1${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Function to run a script with error handling
run_script() {
    local script=$1
    local description=$2
    
    if [ -f "${script}" ]; then
        chmod +x "${script}"
        echo -e "${YELLOW}Running: ${description}${NC}"
        if bash "${script}"; then
            echo -e "${GREEN}✓ ${description} completed${NC}"
            return 0
        else
            echo -e "${RED}✗ ${description} failed${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Script not found: ${script}${NC}"
        return 1
    fi
}

# Function to ask user confirmation
confirm() {
    local prompt=$1
    local default=${2:-N}
    
    if [ "$default" == "Y" ]; then
        read -p "${prompt} (Y/n): " -n 1 -r
    else
        read -p "${prompt} (y/N): " -n 1 -r
    fi
    echo
    
    if [ "$default" == "Y" ]; then
        [[ ! $REPLY =~ ^[Nn]$ ]]
    else
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

# Main installation flow
main() {
    echo -e "${YELLOW}This script will set up your complete development environment.${NC}"
    echo -e "${YELLOW}Estimated time: 20-30 minutes${NC}"
    echo ""
    
    if ! confirm "Do you want to proceed with the installation?" "Y"; then
        echo "Installation cancelled."
        exit 0
    fi
    
    # # Step 1: Install Docker
    # section "Step 1/9: Installing Docker"
    # if confirm "Install Docker?" "Y"; then
    #     run_script "${SCRIPT_DIR}/install-docker.sh" "Docker installation" || {
    #         echo -e "${RED}Failed to install Docker. Please fix the issue and try again.${NC}"
    #         exit 1
    #     }
    # else
    #     echo -e "${YELLOW}Skipping Docker installation${NC}"
    # fi
    
    # # Step 2: Install kubectl
    # section "Step 2/9: Installing kubectl"
    # if confirm "Install kubectl?" "Y"; then
    #     run_script "${SCRIPT_DIR}/install-kubectl.sh" "kubectl installation" || {
    #         echo -e "${RED}Failed to install kubectl. Please fix the issue and try again.${NC}"
    #         exit 1
    #     }
    # else
    #     echo -e "${YELLOW}Skipping kubectl installation${NC}"
    # fi
    
    # # Step 3: Install kind
    # section "Step 3/9: Installing kind"
    # if confirm "Install kind?" "Y"; then
    #     run_script "${SCRIPT_DIR}/install-kind.sh" "kind installation" || {
    #         echo -e "${RED}Failed to install kind. Please fix the issue and try again.${NC}"
    #         exit 1
    #     }
    # else
    #     echo -e "${YELLOW}Skipping kind installation${NC}"
    # fi
    
    # # Step 4: Install Helm
    # section "Step 4/9: Installing Helm"
    # if confirm "Install Helm?" "Y"; then
    #     run_script "${SCRIPT_DIR}/install-helm.sh" "Helm installation" || {
    #         echo -e "${RED}Failed to install Helm. Please fix the issue and try again.${NC}"
    #         exit 1
    #     }
    # else
    #     echo -e "${YELLOW}Skipping Helm installation${NC}"
    # fi
    
    # # Step 5: Create kind cluster
    # section "Step 5/9: Creating Kubernetes Cluster"
    # if confirm "Create kind cluster?" "Y"; then
    #     run_script "${SCRIPT_DIR}/06-create-cluster.sh" "Cluster creation" || {
    #         echo -e "${RED}Failed to create cluster. Please fix the issue and try again.${NC}"
    #         exit 1
    #     }
    # else
    #     echo -e "${YELLOW}Skipping cluster creation${NC}"
    # fi
    
    # Step 6: Install Python prerequisites for kmcp
    section "Step 6/9: Installing Python Prerequisites"
    if confirm "Install Python 3 virtual environment support?" "Y"; then
        run_script "${SCRIPT_DIR}/install-python-prereqs.sh" "Python prerequisites installation" || {
            echo -e "${RED}Failed to prepare Python environment. Please resolve the issue and rerun.${NC}"
            exit 1
        }
    else
        echo -e "${YELLOW}Skipping Python prerequisites installation${NC}"
    fi

    # Step 7: Deploy monitoring stack
    section "Step 7/9: Deploying Monitoring Stack"
    if confirm "Deploy Prometheus and Grafana?" "Y"; then
        run_script "${SCRIPT_DIR}/deploy-monitoring.sh" "Monitoring deployment" || {
            echo -e "${YELLOW}Warning: Monitoring deployment failed. You can retry later.${NC}"
        }
    else
        echo -e "${YELLOW}Skipping monitoring deployment${NC}"
    fi
    
    # Step 8: Setup RBAC
    section "Step 8/9: Setting up RBAC Permissions"
    if confirm "Setup RBAC permissions?" "Y"; then
        run_script "${SCRIPT_DIR}/setup-rbac.sh" "RBAC setup" || {
            echo -e "${YELLOW}Warning: RBAC setup failed. You can retry later.${NC}"
        }
    else
        echo -e "${YELLOW}Skipping RBAC setup${NC}"
    fi
    
    # Step 9: Install kmcp CLI (optional)
    section "Step 9/9: Installing kmcp CLI"
    if confirm "Install kmcp CLI? (optional)" "Y"; then
        run_script "${SCRIPT_DIR}/install-kmcp.sh" "kmcp CLI installation" || {
            echo -e "${YELLOW}Warning: kmcp CLI installation failed. This is optional.${NC}"
        }
    else
        echo -e "${YELLOW}Skipping kmcp CLI installation${NC}"
    fi
    
    # Verification
    section "Verification"
    echo -e "${YELLOW}Running environment verification...${NC}"
    echo ""
    
    if [ -f "${SCRIPT_DIR}/verify-environment.sh" ]; then
        chmod +x "${SCRIPT_DIR}/verify-environment.sh"
        bash "${SCRIPT_DIR}/verify-environment.sh"
    fi
    
    # Final summary
    echo ""
    section "Installation Complete!"
    
    echo -e "${GREEN}✓ Lab 01 environment setup completed!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "  1. Restart your shell or run: ${YELLOW}source ~/.zshrc${NC}"
    echo -e "  2. Verify installation: ${YELLOW}./verify-environment.sh${NC}"
    echo -e "  3. Test cluster: ${YELLOW}./quick-test.sh${NC}"
    echo -e "  4. Access Prometheus: ${YELLOW}http://localhost:30090${NC}"
    echo -e "  5. Access Grafana: ${YELLOW}http://localhost:30030${NC} (admin/admin123)"
    echo ""
    echo -e "${BLUE}Useful commands:${NC}"
    echo -e "  • View cluster: ${YELLOW}kubectl get nodes${NC}"
    echo -e "  • View all pods: ${YELLOW}kubectl get pods -A${NC}"
    echo -e "  • View monitoring: ${YELLOW}kubectl get pods -n monitoring${NC}"
    echo -e "  • Delete cluster: ${YELLOW}kind delete cluster --name mcp-dev-cluster${NC}"
    echo ""
    echo -e "${MAGENTA}Happy learning! 🚀${NC}"
}

# Run main function
main
