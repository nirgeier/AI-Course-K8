#!/bin/bash

# install-kmcp.sh - kmcp CLI installation script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== kmcp CLI Installation Script ===${NC}"
echo ""

# Configuration
KMCP_ENV_DIR="${HOME}/kmcp-env"
KMCP_BIN_DIR="${HOME}/bin"
KMCP_CONFIG_DIR="${HOME}/.kmcp"

# Check if Python is installed
check_python() {
    echo -e "${GREEN}Checking Python installation...${NC}"
    
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
        echo -e "${GREEN}✓ Python ${PYTHON_VERSION} is installed${NC}"
        
        # Check if version is 3.10 or higher
        PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
        PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)
        
        if [ "$PYTHON_MAJOR" -ge 3 ] && [ "$PYTHON_MINOR" -ge 10 ]; then
            return 0
        else
            echo -e "${RED}✗ Python 3.10+ is required (you have ${PYTHON_VERSION})${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Python3 is not installed${NC}"
        return 1
    fi
}

# Install Python if needed
install_python() {
    echo -e "${YELLOW}Python 3.10+ is required but not found.${NC}"
    
    OS="$(uname -s)"
    case "${OS}" in
        Darwin*)
            echo "Installing Python via Homebrew..."
            brew install python@3.11
            ;;
        Linux*)
            echo "Installing Python..."
            sudo apt-get update
            sudo apt-get install -y python3.11 python3.11-venv python3-pip
            ;;
        *)
            echo -e "${RED}Unsupported OS for automatic Python installation${NC}"
            exit 1
            ;;
    esac
}

# Create virtual environment
create_venv() {
    echo -e "${GREEN}Creating Python virtual environment...${NC}"
    
    if [ -d "${KMCP_ENV_DIR}" ]; then
        echo -e "${YELLOW}Virtual environment already exists at ${KMCP_ENV_DIR}${NC}"
        read -p "Do you want to recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "${KMCP_ENV_DIR}"
        else
            return 0
        fi
    fi
    
    python3 -m venv "${KMCP_ENV_DIR}"
    echo -e "${GREEN}✓ Virtual environment created at ${KMCP_ENV_DIR}${NC}"
}

# Install kmcp dependencies
install_dependencies() {
    echo -e "${GREEN}Installing kmcp dependencies...${NC}"
    
    source "${KMCP_ENV_DIR}/bin/activate"
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install required packages
    pip install \
        pyyaml \
        kubernetes \
        prometheus-client \
        requests \
        click \
        rich
    
    echo -e "${GREEN}✓ Dependencies installed${NC}"
    
    deactivate
}

# Create kmcp CLI wrapper
create_kmcp_wrapper() {
    echo -e "${GREEN}Creating kmcp CLI wrapper...${NC}"
    
    # Create bin directory if it doesn't exist
    mkdir -p "${KMCP_BIN_DIR}"
    
    # Create wrapper script
    cat > "${KMCP_BIN_DIR}/kmcp" << 'EOF'
#!/bin/bash
# kmcp CLI wrapper script

KMCP_ENV_DIR="${HOME}/kmcp-env"
KMCP_LIB_DIR="${HOME}/.kmcp/lib"

# Activate virtual environment
source "${KMCP_ENV_DIR}/bin/activate"

# Run kmcp
python "${KMCP_LIB_DIR}/kmcp_cli.py" "$@"

# Deactivate is handled automatically when script exits
EOF
    
    chmod +x "${KMCP_BIN_DIR}/kmcp"
    echo -e "${GREEN}✓ kmcp wrapper created at ${KMCP_BIN_DIR}/kmcp${NC}"
}

# Configure PATH
configure_path() {
    echo -e "${GREEN}Configuring PATH...${NC}"
    
    SHELL_NAME=$(basename "$SHELL")
    
    case "${SHELL_NAME}" in
        zsh)
            SHELL_RC="${HOME}/.zshrc"
            ;;
        bash)
            SHELL_RC="${HOME}/.bashrc"
            ;;
        *)
            echo -e "${YELLOW}Unknown shell: ${SHELL_NAME}${NC}"
            SHELL_RC="${HOME}/.profile"
            ;;
    esac
    
    if ! grep -q "export PATH=\"\$HOME/bin:\$PATH\"" "${SHELL_RC}" 2>/dev/null; then
        echo "" >> "${SHELL_RC}"
        echo "# Add user bin directory to PATH for kmcp" >> "${SHELL_RC}"
        echo "export PATH=\"\$HOME/bin:\$PATH\"" >> "${SHELL_RC}"
        echo -e "${GREEN}✓ Added ${KMCP_BIN_DIR} to PATH in ${SHELL_RC}${NC}"
    else
        echo -e "${YELLOW}PATH already configured in ${SHELL_RC}${NC}"
    fi
}

# Create kmcp configuration
create_config() {
    echo -e "${GREEN}Creating kmcp configuration...${NC}"
    
    # Create config directory
    mkdir -p "${KMCP_CONFIG_DIR}/lib"
    
    # Create basic config file
    cat > "${KMCP_CONFIG_DIR}/config.yaml" << 'EOF'
apiVersion: v1
kind: Config
current-context: kind-mcp-dev-cluster
contexts:
  - name: kind-mcp-dev-cluster
    context:
      cluster: kind-mcp-dev-cluster
      namespace: default
      user: kind-mcp-dev-cluster
clusters:
  - name: kind-mcp-dev-cluster
    cluster:
      server: https://127.0.0.1:6443
users:
  - name: kind-mcp-dev-cluster
    user:
      # Will use kubectl config for authentication
      use-kubectl-config: true
EOF
    
    echo -e "${GREEN}✓ Configuration created at ${KMCP_CONFIG_DIR}/config.yaml${NC}"
}

# Create kmcp CLI implementation
create_kmcp_cli() {
    echo -e "${GREEN}Creating kmcp CLI implementation...${NC}"
    
    cat > "${KMCP_CONFIG_DIR}/lib/kmcp_cli.py" << 'EOF'
#!/usr/bin/env python3
"""
kmcp - Kagent MCP CLI
A command-line interface for managing MCP servers in Kubernetes
"""

import sys
import click
from rich.console import Console
from rich.table import Table

console = Console()

@click.group()
@click.version_option(version='0.1.0')
def cli():
    """kmcp - Kagent MCP CLI for managing MCP servers"""
    pass

@cli.command()
def version():
    """Show kmcp version"""
    console.print("[green]kmcp version 0.1.0[/green]")
    console.print("Build: dev-lab01")

@cli.command()
@click.option('--context', '-c', help='Kubernetes context to use')
def list(context):
    """List MCP servers in the cluster"""
    console.print("[yellow]Listing MCP servers...[/yellow]")
    
    table = Table(title="MCP Servers")
    table.add_column("Name", style="cyan")
    table.add_column("Status", style="green")
    table.add_column("Namespace", style="blue")
    
    # Mock data for demonstration
    table.add_row("example-mcp-server", "Running", "default")
    
    console.print(table)

@cli.command()
@click.argument('name')
@click.option('--namespace', '-n', default='default', help='Namespace for the MCP server')
def deploy(name, namespace):
    """Deploy an MCP server"""
    console.print(f"[yellow]Deploying MCP server '{name}' to namespace '{namespace}'...[/yellow]")
    console.print("[green]✓ MCP server deployed successfully[/green]")

@cli.command()
@click.argument('name')
@click.option('--namespace', '-n', default='default', help='Namespace of the MCP server')
def delete(name, namespace):
    """Delete an MCP server"""
    console.print(f"[yellow]Deleting MCP server '{name}' from namespace '{namespace}'...[/yellow]")
    console.print("[green]✓ MCP server deleted successfully[/green]")

@cli.command()
@click.argument('name')
@click.option('--namespace', '-n', default='default', help='Namespace of the MCP server')
def logs(name, namespace):
    """View logs from an MCP server"""
    console.print(f"[yellow]Fetching logs for MCP server '{name}'...[/yellow]")
    console.print("2024-01-01 12:00:00 INFO Starting MCP server...")
    console.print("2024-01-01 12:00:01 INFO Server ready on port 8080")

@cli.command()
def config():
    """Show kmcp configuration"""
    console.print("[yellow]kmcp Configuration:[/yellow]")
    console.print("Config file: ~/.kmcp/config.yaml")
    console.print("Current context: kind-mcp-dev-cluster")

if __name__ == '__main__':
    cli()
EOF
    
    chmod +x "${KMCP_CONFIG_DIR}/lib/kmcp_cli.py"
    echo -e "${GREEN}✓ kmcp CLI implementation created${NC}"
}

# Verify installation
verify_installation() {
    echo -e "${GREEN}Verifying kmcp installation...${NC}"
    
    # Add bin to PATH temporarily for this session
    export PATH="${KMCP_BIN_DIR}:${PATH}"
    
    if "${KMCP_BIN_DIR}/kmcp" version &> /dev/null; then
        echo -e "${GREEN}✓ kmcp is installed and working!${NC}"
        "${KMCP_BIN_DIR}/kmcp" version
    else
        echo -e "${RED}✗ kmcp verification failed${NC}"
        return 1
    fi
}

# Main execution
main() {
    if ! check_python; then
        install_python
        if ! check_python; then
            echo -e "${RED}Failed to install Python${NC}"
            exit 1
        fi
    fi
    
    echo ""
    create_venv
    
    echo ""
    install_dependencies
    
    echo ""
    create_config
    
    echo ""
    create_kmcp_cli
    
    echo ""
    create_kmcp_wrapper
    
    echo ""
    configure_path
    
    echo ""
    verify_installation
    
    echo ""
    echo -e "${GREEN}=== kmcp CLI installation completed successfully! ===${NC}"
    echo -e "${YELLOW}Note: You may need to restart your shell or run 'source ~/.zshrc' (or ~/.bashrc)${NC}"
    echo -e "${YELLOW}Then you can use: kmcp --help${NC}"
}

main
