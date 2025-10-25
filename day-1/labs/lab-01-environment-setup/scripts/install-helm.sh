#!/bin/bash

# install-helm.sh - Helm installation script for macOS and Linux

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Helm Installation Script ===${NC}"
echo ""

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    *)          MACHINE="UNKNOWN:${OS}"
esac

echo "Detected OS: ${MACHINE}"
echo ""

# Check if Helm is already installed
check_helm() {
    if command -v helm &> /dev/null; then
        echo -e "${YELLOW}Helm is already installed:${NC}"
        helm version
        return 0
    else
        return 1
    fi
}

# Install Helm on macOS
install_helm_mac() {
    echo -e "${GREEN}Installing Helm on macOS...${NC}"
    
    if ! command -v brew &> /dev/null; then
        echo -e "${RED}Homebrew is not installed. Please install Homebrew first.${NC}"
        exit 1
    fi
    
    brew install helm
}

# Install Helm on Linux
install_helm_linux() {
    echo -e "${GREEN}Installing Helm on Linux...${NC}"
    
    # Download and run the official Helm installation script
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}

# Configure Helm repositories
configure_helm_repos() {
    echo -e "${GREEN}Configuring Helm repositories...${NC}"
    
    # Add Prometheus community charts
    echo "Adding prometheus-community repository..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    
    # Add Grafana charts
    echo "Adding grafana repository..."
    helm repo add grafana https://grafana.github.io/helm-charts
    
    # Add bitnami charts (commonly used)
    echo "Adding bitnami repository..."
    helm repo add bitnami https://charts.bitnami.com/bitnami
    
    # Update repositories
    echo "Updating Helm repositories..."
    helm repo update
    
    echo -e "${GREEN}✓ Helm repositories configured${NC}"
}

# Verify Helm installation
verify_helm() {
    echo -e "${GREEN}Verifying Helm installation...${NC}"
    
    if helm version &> /dev/null; then
        echo -e "${GREEN}✓ Helm is installed successfully!${NC}"
        helm version
        
        echo ""
        echo "Configured repositories:"
        helm repo list
    else
        echo -e "${RED}✗ Helm verification failed${NC}"
        return 1
    fi
}

# Main execution
main() {
    if check_helm; then
        echo -e "${GREEN}Helm is already installed.${NC}"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping installation."
            
            # Still offer to configure repos
            read -p "Do you want to configure Helm repositories? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                configure_helm_repos
            fi
            exit 0
        fi
    fi
    
    case "${MACHINE}" in
        Mac)
            install_helm_mac
            ;;
        Linux)
            install_helm_linux
            ;;
        *)
            echo -e "${RED}Unsupported operating system: ${MACHINE}${NC}"
            exit 1
            ;;
    esac
    
    echo ""
    verify_helm
    
    echo ""
    configure_helm_repos
    
    echo ""
    echo -e "${GREEN}=== Helm installation completed successfully! ===${NC}"
}

main
