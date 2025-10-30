#!/bin/bash

# install-python-prereqs.sh - Ensure Python 3 + venv/pip are available for kmcp installation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

REQUIRED_VERSION="3.10"
TMP_GET_PIP="/tmp/get-pip.py"
PYTHON_BIN=""

echo -e "${GREEN}=== Python Prerequisites Installation ===${NC}"
echo ""

version_ge() {
    local ver_a=$1
    local ver_b=$2
    local a_part b_part

    while [ -n "$ver_a" ] || [ -n "$ver_b" ]; do
        a_part=${ver_a%%.*}
        b_part=${ver_b%%.*}

        if [ "$ver_a" = "$a_part" ]; then
            ver_a=""
        else
            ver_a=${ver_a#*.}
        fi

        if [ "$ver_b" = "$b_part" ]; then
            ver_b=""
        else
            ver_b=${ver_b#*.}
        fi

        a_part=${a_part:-0}
        b_part=${b_part:-0}

        if (( a_part > b_part )); then
            return 0
        fi
        if (( a_part < b_part )); then
            return 1
        fi
    done

    return 0
}

resolve_python_bin() {
    local candidates=(python3 python3.12 python3.11 python3.10)
    local candidate version

    for candidate in "${candidates[@]}"; do
        if command -v "$candidate" >/dev/null 2>&1; then
            version="$($candidate --version 2>/dev/null | awk '{print $2}')"
            if [ -n "$version" ] && version_ge "$version" "$REQUIRED_VERSION"; then
                PYTHON_BIN="$candidate"
                return 0
            fi
        fi
    done

    return 1
}

python_has_ensurepip() {
    if ! resolve_python_bin; then
        return 1
    fi

    "$PYTHON_BIN" -m ensurepip --version >/dev/null 2>&1
}

ensure_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        return 0
    fi

    echo -e "${YELLOW}Homebrew not found. Installing Homebrew...${NC}"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo -e "${GREEN}✓ Homebrew installed${NC}"
}

install_python_mac() {
    echo -e "${GREEN}Setting up Python on macOS...${NC}"
    ensure_homebrew
    brew update
    brew install python@3.12
    brew link python@3.12 --force
}

install_python_debian() {
    echo -e "${GREEN}Setting up Python on Debian/Ubuntu...${NC}"
    sudo apt-get update
    sudo apt-get install -y python3 python3-venv python3-pip
}

install_python_rhel() {
    echo -e "${GREEN}Setting up Python on RHEL/CentOS/Fedora...${NC}"
    if command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y python3 python3-pip python3-virtualenv
    else
        sudo yum install -y python3 python3-pip python3-virtualenv
    fi
}

bootstrap_pip() {
    if "$PYTHON_BIN" -m ensurepip --version >/dev/null 2>&1; then
        return 0
    fi

    echo -e "${YELLOW}ensurepip unavailable. Bootstrapping pip manually...${NC}"
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o "$TMP_GET_PIP"
    "$PYTHON_BIN" "$TMP_GET_PIP"
    rm -f "$TMP_GET_PIP"
}

verify_python() {
    local version
    if ! resolve_python_bin; then
        echo -e "${RED}Python ${REQUIRED_VERSION}+ executable not found after installation${NC}"
        exit 1
    fi

    version=$("$PYTHON_BIN" --version | awk '{print $2}')

    if ! version_ge "$version" "$REQUIRED_VERSION"; then
        echo -e "${RED}Python ${REQUIRED_VERSION}+ is required. Current version: ${version}${NC}"
        exit 1
    fi

    "$PYTHON_BIN" -m venv --help >/dev/null 2>&1 || {
        echo -e "${RED}Python venv module still unavailable after installation${NC}"
        exit 1
    }

    "$PYTHON_BIN" -m pip --version >/dev/null 2>&1 || {
        echo -e "${RED}pip is missing after installation${NC}"
        exit 1
    }

    echo -e "${GREEN}✓ Python environment prerequisites verified (${PYTHON_BIN})${NC}"
}

main() {
    OS="$(uname -s)"
    case "$OS" in
        Darwin*) MACHINE=Mac;;
        Linux*) MACHINE=Linux;;
        *) MACHINE="UNKNOWN";;
    esac

    if python_has_ensurepip; then
        echo -e "${YELLOW}Python ${REQUIRED_VERSION}+ with ensurepip already configured.${NC}"
        "$PYTHON_BIN" --version
        "$PYTHON_BIN" -m ensurepip --version >/dev/null 2>&1 || true
        exit 0
    fi

    case "$MACHINE" in
        Mac)
            install_python_mac
            ;;
        Linux)
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                case "$ID" in
                    ubuntu|debian)
                        install_python_debian
                        ;;
                    centos|rhel|fedora)
                        install_python_rhel
                        ;;
                    *)
                        echo -e "${YELLOW}Unsupported Linux distribution: $ID${NC}"
                        echo -e "${YELLOW}Attempting generic python3 installation via detected package manager${NC}"
                        if command -v apt-get >/dev/null 2>&1; then
                            sudo apt-get update
                            sudo apt-get install -y python3 python3-venv python3-pip || true
                        elif command -v dnf >/dev/null 2>&1; then
                            sudo dnf install -y python3 python3-pip python3-virtualenv || true
                        elif command -v yum >/dev/null 2>&1; then
                            sudo yum install -y python3 python3-pip python3-virtualenv || true
                        else
                            echo -e "${RED}No supported package manager detected. Please install Python ${REQUIRED_VERSION}+ manually.${NC}"
                            exit 1
                        fi
                        ;;
                esac
            else
                echo -e "${RED}Cannot detect Linux distribution. Aborting.${NC}"
                exit 1
            fi
            ;;
        *)
            echo -e "${RED}Unsupported operating system: ${OS}${NC}"
            exit 1
            ;;
    esac

    if ! resolve_python_bin; then
        echo -e "${RED}Unable to locate Python ${REQUIRED_VERSION}+ after installation${NC}"
        exit 1
    fi

    bootstrap_pip
    verify_python

    echo ""
    echo -e "${GREEN}=== Python prerequisites installed successfully ===${NC}"
    "$PYTHON_BIN" --version
    "$PYTHON_BIN" -m pip --version
    echo -e "${YELLOW}You may need to restart your shell if PATH changes were applied.${NC}"
}

main
