#!/bin/bash

# install-uv.sh - UV installation script for macOS, Linux, and Windows (WSL/Git Bash)
# This script automates UV installation across different platforms
# UV is an extremely fast Python package installer and resolver, written in Rust

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== UV Installation Script ===${NC}"
echo -e "${BLUE}UV: An extremely fast Python package installer and resolver${NC}"
echo ""

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    CYGWIN*)    MACHINE=Windows;;
    MINGW*)     MACHINE=Windows;;
    MSYS*)      MACHINE=Windows;;
    *)          MACHINE="UNKNOWN:${OS}"
esac

echo "Detected OS: ${MACHINE}"
echo ""

# Function to check if uv is already installed
check_uv() {
    if command -v uv &> /dev/null; then
        echo -e "${YELLOW}UV is already installed:${NC}"
        uv --version
        return 0
    else
        return 1
    fi
}

# Function to install uv on macOS
install_uv_mac() {
    echo -e "${GREEN}Installing UV on macOS...${NC}"
    echo ""
    
    # Check if Homebrew is installed
    if command -v brew &> /dev/null; then
        echo "Installing UV via Homebrew..."
        brew install uv
    else
        echo "Homebrew not found. Installing UV via standalone installer..."
        install_uv_standalone
    fi
}

# Function to install uv on Linux
install_uv_linux() {
    echo -e "${GREEN}Installing UV on Linux...${NC}"
    echo ""
    
    # Detect Linux distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        echo "Detected distribution: ${DISTRO}"
    fi
    
    # Use standalone installer for all Linux distributions
    install_uv_standalone
}

# Function to install uv on Windows (WSL/Git Bash/MSYS)
install_uv_windows() {
    echo -e "${GREEN}Installing UV on Windows...${NC}"
    echo ""
    
    # Check if running in WSL
    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "Running in WSL - using Linux installer..."
        install_uv_standalone
    else
        echo -e "${YELLOW}For native Windows, please use PowerShell with the following command:${NC}"
        echo -e "${BLUE}powershell -c \"irm https://astral.sh/uv/install.ps1 | iex\"${NC}"
        echo ""
        echo "Attempting standalone installer for Git Bash/MSYS..."
        install_uv_standalone
    fi
}

# Standalone installer (works on macOS, Linux, WSL)
install_uv_standalone() {
    echo "Downloading and running UV standalone installer..."
    
    # Download and run the installer
    curl -LsSf https://astral.sh/uv/install.sh | sh
    
    # Detect shell and add to PATH if needed
    detect_and_configure_shell
}

# Function to detect shell and configure PATH
detect_and_configure_shell() {
    echo ""
    echo -e "${YELLOW}Configuring shell environment...${NC}"
    
    # Determine which shell configuration file to use
    if [ -n "$BASH_VERSION" ]; then
        SHELL_RC="$HOME/.bashrc"
        SHELL_PROFILE="$HOME/.bash_profile"
    elif [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
        SHELL_PROFILE="$HOME/.zprofile"
    else
        # Try to detect from SHELL variable
        case "$SHELL" in
            */zsh)
                SHELL_RC="$HOME/.zshrc"
                SHELL_PROFILE="$HOME/.zprofile"
                ;;
            */bash)
                SHELL_RC="$HOME/.bashrc"
                SHELL_PROFILE="$HOME/.bash_profile"
                ;;
            */fish)
                SHELL_RC="$HOME/.config/fish/config.fish"
                ;;
            *)
                SHELL_RC="$HOME/.profile"
                ;;
        esac
    fi
    
    # UV installer typically adds to PATH automatically
    # Just inform the user
    echo -e "${GREEN}UV has been installed to ~/.cargo/bin${NC}"
    echo -e "${YELLOW}The installer should have updated your shell configuration.${NC}"
    echo -e "${YELLOW}If not, add the following to your ${SHELL_RC}:${NC}"
    echo -e "${BLUE}export PATH=\"\$HOME/.cargo/bin:\$PATH\"${NC}"
}

# Verify uv installation
verify_uv() {
    echo ""
    echo -e "${GREEN}Verifying UV installation...${NC}"
    
    # Source cargo env if it exists
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    fi
    
    # Add to PATH for this session
    export PATH="$HOME/.cargo/bin:$PATH"
    
    if command -v uv &> /dev/null; then
        echo -e "${GREEN}✓ UV is installed successfully!${NC}"
        echo ""
        echo "UV version:"
        uv --version
        
        echo ""
        echo -e "${BLUE}Testing UV with a simple command...${NC}"
        uv pip --help &> /dev/null && echo -e "${GREEN}✓ UV is working correctly!${NC}"
        
        return 0
    else
        echo -e "${RED}✗ UV installation verification failed${NC}"
        echo -e "${YELLOW}You may need to restart your terminal or run:${NC}"
        echo -e "${BLUE}source ~/.cargo/env${NC}"
        echo -e "${YELLOW}or${NC}"
        echo -e "${BLUE}export PATH=\"\$HOME/.cargo/bin:\$PATH\"${NC}"
        return 1
    fi
}

# Display usage information
show_usage() {
    echo ""
    echo -e "${GREEN}=== UV Quick Start Guide ===${NC}"
    echo ""
    echo "Common UV commands:"
    echo -e "${BLUE}  uv pip install <package>${NC}     - Install a Python package"
    echo -e "${BLUE}  uv pip list${NC}                  - List installed packages"
    echo -e "${BLUE}  uv venv${NC}                      - Create a virtual environment"
    echo -e "${BLUE}  uv init${NC}                      - Initialize a new project"
    echo -e "${BLUE}  uv add <package>${NC}             - Add a package to your project"
    echo -e "${BLUE}  uv run <script>${NC}              - Run a Python script"
    echo ""
    echo "For more information, visit: https://docs.astral.sh/uv/"
    echo ""
}

# Main execution
main() {
    if check_uv; then
        echo -e "${GREEN}UV is already installed and working.${NC}"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping installation."
            show_usage
            exit 0
        fi
    fi
    
    case "${MACHINE}" in
        Mac)
            install_uv_mac
            ;;
        Linux)
            install_uv_linux
            ;;
        Windows)
            install_uv_windows
            ;;
        *)
            echo -e "${RED}Unsupported operating system: ${MACHINE}${NC}"
            echo -e "${YELLOW}Please visit https://docs.astral.sh/uv/getting-started/installation/ for manual installation instructions.${NC}"
            exit 1
            ;;
    esac
    
    verify_uv
    show_usage
    
    echo -e "${GREEN}=== UV installation completed! ===${NC}"
    echo -e "${YELLOW}Note: You may need to restart your terminal for PATH changes to take effect.${NC}"
}

main
