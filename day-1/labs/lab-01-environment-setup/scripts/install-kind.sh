#!/bin/bash

# install-kind.sh - kind installation script for macOS and Linux

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== kind Installation Script ===${NC}"
echo ""

# kind version to install
KIND_VERSION="v0.20.0"

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    *)          MACHINE="UNKNOWN:${OS}"
esac

echo "Detected OS: ${MACHINE}"
echo ""

# Check if kind is already installed
check_kind() {
    if command -v kind &> /dev/null; then
        echo -e "${YELLOW}kind is already installed:${NC}"
        kind version
        return 0
    else
        return 1
    fi
}

# Install kind on macOS
install_kind_mac() {
    echo -e "${GREEN}Installing kind on macOS...${NC}"
    
    if ! command -v brew &> /dev/null; then
        echo -e "${RED}Homebrew is not installed. Please install Homebrew first.${NC}"
        exit 1
    fi
    
    brew install kind
}

# Install kind on Linux
install_kind_linux() {
    echo -e "${GREEN}Installing kind ${KIND_VERSION} on Linux...${NC}"
    
    # Download kind
    curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
    
    # Make it executable
    chmod +x ./kind
    
    # Move to /usr/local/bin
    sudo mv ./kind /usr/local/bin/kind
}

# Verify kind installation
verify_kind() {
    echo -e "${GREEN}Verifying kind installation...${NC}"
    
    if kind version &> /dev/null; then
        echo -e "${GREEN}✓ kind is installed successfully!${NC}"
        kind version
    else
        echo -e "${RED}✗ kind verification failed${NC}"
        return 1
    fi
}

# Check Docker prerequisite
check_docker() {
    echo -e "${GREEN}Checking Docker prerequisite...${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}✗ Docker is not installed!${NC}"
        echo -e "${YELLOW}kind requires Docker to be installed and running.${NC}"
        echo "Please run ./install-docker.sh first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${RED}✗ Docker daemon is not running!${NC}"
        echo "Please start Docker and try again."
        exit 1
    fi
    
    echo -e "${GREEN}✓ Docker is installed and running${NC}"
}

# Main execution
main() {
    check_docker
    
    echo ""
    
    if check_kind; then
        echo -e "${GREEN}kind is already installed.${NC}"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping installation."
            exit 0
        fi
    fi
    
    case "${MACHINE}" in
        Mac)
            install_kind_mac
            ;;
        Linux)
            install_kind_linux
            ;;
        *)
            echo -e "${RED}Unsupported operating system: ${MACHINE}${NC}"
            exit 1
            ;;
    esac
    
    echo ""
    verify_kind
    
    echo ""
    echo -e "${GREEN}=== kind installation completed successfully! ===${NC}"
    echo -e "${YELLOW}Note: kind uses Docker to create Kubernetes clusters${NC}"
}

main
