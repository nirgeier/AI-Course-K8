#!/bin/bash

# install-k9s.sh - k9s installation script for macOS and Linux

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== k9s Installation Script ===${NC}"
echo ""

# k9s version to install
K9S_VERSION="v0.32.4"

# Detect OS and Architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

case "${OS}" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    *)          MACHINE="UNKNOWN:${OS}"
esac

case "${ARCH}" in
    x86_64)     ARCHITECTURE="amd64";;
    arm64|aarch64) ARCHITECTURE="arm64";;
    *)          ARCHITECTURE="UNKNOWN:${ARCH}"
esac

echo "Detected OS: ${MACHINE}"
echo "Detected Architecture: ${ARCHITECTURE}"
echo ""

# Check if k9s is already installed
check_k9s() {
    if command -v k9s &> /dev/null; then
        echo -e "${YELLOW}k9s is already installed:${NC}"
        k9s version
        return 0
    else
        return 1
    fi
}

# Install k9s on macOS
install_k9s_mac() {
    echo -e "${GREEN}Installing k9s on macOS...${NC}"
    
    if ! command -v brew &> /dev/null; then
        echo -e "${RED}Homebrew is not installed. Please install Homebrew first.${NC}"
        exit 1
    fi
    
    brew install k9s
}

# Install k9s on Linux
install_k9s_linux() {
    echo -e "${GREEN}Installing k9s ${K9S_VERSION} on Linux...${NC}"
    
    # Create temp directory
    TEMP_DIR=$(mktemp -d)
    cd "${TEMP_DIR}"
    
    # Download k9s
    echo "Downloading k9s..."
    curl -LO "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${ARCHITECTURE}.tar.gz"
    
    # Extract archive
    echo "Extracting k9s..."
    tar xzf "k9s_Linux_${ARCHITECTURE}.tar.gz"
    
    # Make it executable
    chmod +x k9s
    
    # Move to /usr/local/bin
    echo "Installing k9s to /usr/local/bin..."
    sudo mv k9s /usr/local/bin/k9s
    
    # Cleanup
    cd -
    rm -rf "${TEMP_DIR}"
}

# Verify k9s installation
verify_k9s() {
    echo -e "${GREEN}Verifying k9s installation...${NC}"
    
    if k9s version &> /dev/null; then
        echo -e "${GREEN}✓ k9s is installed successfully!${NC}"
        k9s version
    else
        echo -e "${RED}✗ k9s verification failed${NC}"
        return 1
    fi
}

# Check kubectl prerequisite
check_kubectl() {
    echo -e "${GREEN}Checking kubectl prerequisite...${NC}"
    
    if ! command -v kubectl &> /dev/null; then
        echo -e "${YELLOW}⚠ kubectl is not installed!${NC}"
        echo -e "${YELLOW}k9s requires kubectl to interact with Kubernetes clusters.${NC}"
        echo "Please run ./install-kubectl.sh first."
        echo ""
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo -e "${GREEN}✓ kubectl is installed${NC}"
    fi
}

# Main execution
main() {
    check_kubectl
    
    echo ""
    
    if check_k9s; then
        echo -e "${GREEN}k9s is already installed.${NC}"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping installation."
            exit 0
        fi
    fi
    
    case "${MACHINE}" in
        Mac)
            install_k9s_mac
            ;;
        Linux)
            if [[ "${ARCHITECTURE}" == "UNKNOWN:"* ]]; then
                echo -e "${RED}Unsupported architecture: ${ARCH}${NC}"
                exit 1
            fi
            install_k9s_linux
            ;;
        *)
            echo -e "${RED}Unsupported operating system: ${MACHINE}${NC}"
            exit 1
            ;;
    esac
    
    echo ""
    verify_k9s
    
    echo ""
    echo -e "${GREEN}=== k9s installation completed successfully! ===${NC}"
    echo -e "${YELLOW}Usage: Run 'k9s' to start the Kubernetes cluster UI${NC}"
    echo -e "${YELLOW}Tip: Press '?' inside k9s for help and keyboard shortcuts${NC}"
}

main
