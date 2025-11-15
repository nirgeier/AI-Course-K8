#!/bin/bash

# install-docker.sh - Docker installation script for macOS and Linux
# This script automates Docker installation across different platforms

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Docker Installation Script ===${NC}"
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

# Function to check if Docker is already installed
check_docker() {
    if command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker is already installed:${NC}"
        docker --version
        return 0
    else
        return 1
    fi
}

# Function to install Docker on macOS
install_docker_mac() {
    echo -e "${GREEN}Installing Docker on macOS...${NC}"
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        echo -e "${RED}Homebrew is not installed. Installing Homebrew first...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    echo "Installing Docker Desktop via Homebrew..."
    brew install --cask docker
    
    echo -e "${YELLOW}Starting Docker Desktop...${NC}"
    open -a Docker
    
    echo -e "${YELLOW}Waiting for Docker to start (this may take a minute)...${NC}"
    # Wait for Docker daemon to start
    for i in {1..30}; do
        if docker info &> /dev/null; then
            echo -e "${GREEN}Docker is running!${NC}"
            break
        fi
        echo -n "."
        sleep 2
    done
    echo ""
}

# Function to install Docker on Linux
install_docker_linux() {
    echo -e "${GREEN}Installing Docker on Linux...${NC}"
    
    # Detect Linux distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        echo -e "${RED}Cannot detect Linux distribution${NC}"
        exit 1
    fi
    
    case "${DISTRO}" in
        ubuntu|debian)
            install_docker_debian
            ;;
        centos|rhel|fedora)
            install_docker_rhel
            ;;
        *)
            echo -e "${RED}Unsupported Linux distribution: ${DISTRO}${NC}"
            exit 1
            ;;
    esac
}

# Install Docker on Debian/Ubuntu
install_docker_debian() {
    echo "Installing Docker on Debian/Ubuntu..."
    
    # Update package index
    sudo apt-get update
    
    # Install prerequisites
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add current user to docker group
    sudo usermod -aG docker $USER
    
    # Start Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    echo -e "${YELLOW}Note: You may need to log out and back in for group changes to take effect${NC}"
}

# Install Docker on RHEL/CentOS/Fedora
install_docker_rhel() {
    echo "Installing Docker on RHEL/CentOS/Fedora..."
    
    # Install prerequisites
    sudo yum install -y yum-utils
    
    # Add Docker repository
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    # Install Docker
    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add current user to docker group
    sudo usermod -aG docker $USER
    
    echo -e "${YELLOW}Note: You may need to log out and back in for group changes to take effect${NC}"
}

# Verify Docker installation
verify_docker() {
    echo -e "${GREEN}Verifying Docker installation...${NC}"
    
    # Wait for Docker to be ready
    for i in {1..10}; do
        if docker info &> /dev/null; then
            break
        fi
        echo "Waiting for Docker daemon..."
        sleep 2
    done
    
    echo "Docker version:"
    docker --version
    
    echo ""
    echo "Running hello-world container to test Docker..."
    if docker run hello-world &> /dev/null; then
        echo -e "${GREEN}✓ Docker is working correctly!${NC}"
    else
        echo -e "${RED}✗ Docker test failed${NC}"
        return 1
    fi
}

# Main execution
main() {
    if check_docker; then
        echo -e "${GREEN}Docker is already installed and working.${NC}"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping installation."
            exit 0
        fi
    fi
    
    case "${MACHINE}" in
        Mac)
            install_docker_mac
            ;;
        Linux)
            install_docker_linux
            ;;
        *)
            echo -e "${RED}Unsupported operating system: ${MACHINE}${NC}"
            exit 1
            ;;
    esac
    
    echo ""
    verify_docker
    
    echo ""
    echo -e "${GREEN}=== Docker installation completed successfully! ===${NC}"
}

main
