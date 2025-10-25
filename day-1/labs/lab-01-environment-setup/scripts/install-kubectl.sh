#!/bin/bash

# install-kubectl.sh - kubectl installation script for macOS and Linux

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== kubectl Installation Script ===${NC}"
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

# Check if kubectl is already installed
check_kubectl() {
    if command -v kubectl &> /dev/null; then
        echo -e "${YELLOW}kubectl is already installed:${NC}"
        kubectl version --client
        return 0
    else
        return 1
    fi
}

# Install kubectl on macOS
install_kubectl_mac() {
    echo -e "${GREEN}Installing kubectl on macOS...${NC}"
    
    if ! command -v brew &> /dev/null; then
        echo -e "${RED}Homebrew is not installed. Please install Homebrew first.${NC}"
        exit 1
    fi
    
    brew install kubectl
}

# Install kubectl on Linux
install_kubectl_linux() {
    echo -e "${GREEN}Installing kubectl on Linux...${NC}"
    
    # Download latest stable version
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    echo "Downloading kubectl ${KUBECTL_VERSION}..."
    
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    
    # Download checksum
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"
    
    # Verify checksum
    echo "Verifying checksum..."
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
    
    # Install kubectl
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    
    # Clean up
    rm kubectl kubectl.sha256
}

# Configure kubectl autocomplete
configure_autocomplete() {
    echo -e "${GREEN}Configuring kubectl autocomplete...${NC}"
    
    SHELL_NAME=$(basename "$SHELL")
    
    case "${SHELL_NAME}" in
        zsh)
            SHELL_RC="${HOME}/.zshrc"
            if ! grep -q "kubectl completion zsh" "${SHELL_RC}" 2>/dev/null; then
                echo "" >> "${SHELL_RC}"
                echo "# kubectl autocomplete" >> "${SHELL_RC}"
                echo "source <(kubectl completion zsh)" >> "${SHELL_RC}"
                echo "alias k=kubectl" >> "${SHELL_RC}"
                echo "complete -F __start_kubectl k" >> "${SHELL_RC}"
                echo -e "${GREEN}Added autocomplete configuration to ${SHELL_RC}${NC}"
            fi
            ;;
        bash)
            SHELL_RC="${HOME}/.bashrc"
            if ! grep -q "kubectl completion bash" "${SHELL_RC}" 2>/dev/null; then
                echo "" >> "${SHELL_RC}"
                echo "# kubectl autocomplete" >> "${SHELL_RC}"
                echo "source <(kubectl completion bash)" >> "${SHELL_RC}"
                echo "alias k=kubectl" >> "${SHELL_RC}"
                echo "complete -F __start_kubectl k" >> "${SHELL_RC}"
                echo -e "${GREEN}Added autocomplete configuration to ${SHELL_RC}${NC}"
            fi
            ;;
        *)
            echo -e "${YELLOW}Shell ${SHELL_NAME} autocomplete not configured${NC}"
            ;;
    esac
}

# Verify kubectl installation
verify_kubectl() {
    echo -e "${GREEN}Verifying kubectl installation...${NC}"
    
    if kubectl version --client &> /dev/null; then
        echo -e "${GREEN}✓ kubectl is installed successfully!${NC}"
        kubectl version --client
    else
        echo -e "${RED}✗ kubectl verification failed${NC}"
        return 1
    fi
}

# Main execution
main() {
    if check_kubectl; then
        echo -e "${GREEN}kubectl is already installed.${NC}"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping installation."
            exit 0
        fi
    fi
    
    case "${MACHINE}" in
        Mac)
            install_kubectl_mac
            ;;
        Linux)
            install_kubectl_linux
            ;;
        *)
            echo -e "${RED}Unsupported operating system: ${MACHINE}${NC}"
            exit 1
            ;;
    esac
    
    echo ""
    verify_kubectl
    
    echo ""
    configure_autocomplete
    
    echo ""
    echo -e "${GREEN}=== kubectl installation completed successfully! ===${NC}"
    echo -e "${YELLOW}Note: You may need to restart your shell or run 'source ~/.zshrc' (or ~/.bashrc) for autocomplete to work${NC}"
}

main
