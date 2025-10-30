# UV Installation Guide

Complete cross-platform installation guide for UV - the extremely fast Python package installer and resolver.

## What is UV?

UV is a next-generation Python package installer and resolver written in Rust. It's designed to be a drop-in replacement for pip, pip-tools, and virtualenv, but with significantly better performance.

**Key Features:**

- 🚀 **10-100x faster** than pip
- 📦 Built-in virtual environment management
- 🔒 Dependency resolution and locking
- 🎯 Project management with `uv init`
- 💾 Smart caching for faster installs
- 🔄 Compatible with pip and pip-tools

## Quick Start

### macOS / Linux / WSL

```bash
# Download and run the installation script
cd scripts
chmod +x install-uv.sh
./install-uv.sh
```

### Windows (PowerShell)

```powershell
# Run as Administrator (recommended)
cd scripts
.\install-uv.ps1
```

## Platform-Specific Installation

### macOS

#### Option 1: Using the Install Script (Recommended)

```bash
./install-uv.sh
```

The script will:

1. Check for existing UV installation
2. Install via Homebrew if available, otherwise use standalone installer
3. Configure shell environment
4. Verify installation

#### Option 2: Homebrew

```bash
brew install uv
```

#### Option 3: Standalone Installer

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Linux

#### Option 1: Using the Install Script (Recommended)

```bash
./install-uv.sh
```

The script supports:

- Ubuntu/Debian
- RHEL/CentOS/Fedora
- Other distributions via standalone installer

#### Option 2: Standalone Installer

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

#### Option 3: Package Managers

**For Arch Linux:**

```bash
# AUR package
yay -S uv
```

### Windows

#### Option 1: Using the PowerShell Script (Recommended)

```powershell
# Run PowerShell as Administrator
.\install-uv.ps1
```

The script will:

1. Check for existing installation
2. Try official installer
3. Fall back to winget if available
4. Configure PATH automatically

#### Option 2: Official Installer

```powershell
powershell -c "irm https://astral.sh/uv/install.ps1 | iex"
```

#### Option 3: Windows Package Manager (winget)

```powershell
winget install --id=astral-sh.uv -e
```

#### Option 4: Scoop

```powershell
scoop install uv
```

### Windows Subsystem for Linux (WSL)

Follow the Linux installation instructions:

```bash
./install-uv.sh
```

## Post-Installation

### Verify Installation

```bash
# Check version
uv --version

# Test basic functionality
uv pip --help
```

### Configure Shell (if needed)

The installer usually configures your shell automatically. If UV is not found, add to your shell configuration:

**Bash (~/.bashrc or ~/.bash_profile):**

```bash
export PATH="$HOME/.cargo/bin:$PATH"
```

**Zsh (~/.zshrc):**

```zsh
export PATH="$HOME/.cargo/bin:$PATH"
```

**Fish (~/.config/fish/config.fish):**

```fish
set -gx PATH $HOME/.cargo/bin $PATH
```

**PowerShell (Windows):**

UV installer automatically updates your PATH. If needed, add manually:

```powershell
$env:Path += ";$env:USERPROFILE\.cargo\bin"
```

Then reload your shell or run:

```bash
source ~/.bashrc  # or ~/.zshrc, etc.
```

## Quick Start Guide

### Creating a Virtual Environment

```bash
# Create a virtual environment
uv venv

# Activate it
# macOS/Linux:
source .venv/bin/activate
# Windows:
.venv\Scripts\activate
```

### Installing Packages

```bash
# Install a package
uv pip install requests

# Install from requirements.txt
uv pip install -r requirements.txt

# Install multiple packages
uv pip install fastapi uvicorn pydantic
```

### Project Management

```bash
# Initialize a new project
uv init my-project
cd my-project

# Add dependencies
uv add fastapi
uv add --dev pytest

# Run a script
uv run main.py
```

### Dependency Management

```bash
# Generate requirements.txt
uv pip freeze > requirements.txt

# Compile requirements with exact versions
uv pip compile requirements.in -o requirements.txt

# Sync environment with requirements
uv pip sync requirements.txt
```

## Common UV Commands

| Command | Description |
|---------|-------------|
| `uv venv` | Create a virtual environment |
| `uv pip install <package>` | Install a package |
| `uv pip uninstall <package>` | Uninstall a package |
| `uv pip list` | List installed packages |
| `uv pip freeze` | Output installed packages in requirements format |
| `uv pip compile` | Compile requirements file with locked versions |
| `uv pip sync` | Sync environment with requirements file |
| `uv init` | Initialize a new project |
| `uv add <package>` | Add a package to the project |
| `uv remove <package>` | Remove a package from the project |
| `uv run <script>` | Run a Python script |
| `uv --version` | Show UV version |
| `uv --help` | Show help information |

## Migration from pip

UV is designed to be a drop-in replacement for pip. Simply replace `pip` with `uv pip`:

```bash
# Before (pip)
pip install requests
pip install -r requirements.txt
pip freeze > requirements.txt

# After (UV)
uv pip install requests
uv pip install -r requirements.txt
uv pip freeze > requirements.txt
```

## Performance Comparison

UV is significantly faster than traditional Python package managers:

| Operation | pip | UV | Speedup |
|-----------|-----|-----|---------|
| Install Flask | ~3s | ~0.3s | **10x** |
| Install Django | ~8s | ~0.5s | **16x** |
| Install large project | ~120s | ~5s | **24x** |

*Benchmarks may vary based on system and network conditions*

## Troubleshooting

### UV command not found

**Solution:**

1. Ensure UV is in your PATH
2. Restart your terminal
3. Run: `source ~/.cargo/env` (macOS/Linux)
4. Or manually add to PATH (see Post-Installation section)

### Permission denied errors (Linux/macOS)

**Solution:**

```bash
# Make sure install script is executable
chmod +x install-uv.sh
./install-uv.sh
```

### Installation fails on Windows

**Solution:**

1. Run PowerShell as Administrator
2. Check Windows Defender/Antivirus isn't blocking
3. Try alternative installation method (winget or Scoop)

### UV installed but not working in virtual environment

**Solution:**

UV should be available globally. If issues persist:

```bash
# Reinstall
curl -LsSf https://astral.sh/uv/install.sh | sh

# Or use system package manager
brew reinstall uv  # macOS
```

### Slow installation even with UV

**Solution:**

UV uses caching. First install may be slower:

```bash
# Clear cache and retry
uv clean
uv pip install <package>
```

## Updating UV

### macOS/Linux

```bash
# Using Homebrew
brew upgrade uv

# Using standalone installer
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Windows

```powershell
# Using winget
winget upgrade --id=astral-sh.uv

# Using Scoop
scoop update uv

# Or re-run installer
irm https://astral.sh/uv/install.ps1 | iex
```

## Uninstalling UV

### macOS/Linux

```bash
# If installed via Homebrew
brew uninstall uv

# If installed via standalone installer
rm -rf ~/.cargo/bin/uv
# Remove from shell config (~/.bashrc, ~/.zshrc, etc.)
```

### Windows

```powershell
# If installed via winget
winget uninstall astral-sh.uv

# If installed via Scoop
scoop uninstall uv

# Or manually remove from: %USERPROFILE%\.cargo\bin\
```

## Additional Resources

- **Official Documentation**: https://docs.astral.sh/uv/
- **GitHub Repository**: https://github.com/astral-sh/uv
- **Getting Started**: https://docs.astral.sh/uv/getting-started/
- **Command Reference**: https://docs.astral.sh/uv/reference/cli/

## Comparison with Other Tools

| Feature | UV | pip | poetry | pdm |
|---------|-----|-----|--------|-----|
| Speed | ⚡⚡⚡ | ⚡ | ⚡⚡ | ⚡⚡ |
| Dependency Resolution | ✅ | ✅ | ✅ | ✅ |
| Lock Files | ✅ | ❌ | ✅ | ✅ |
| Virtual Environments | ✅ | ❌ | ✅ | ✅ |
| Project Management | ✅ | ❌ | ✅ | ✅ |
| pip Compatible | ✅ | ✅ | ⚠️ | ⚠️ |
| Rust-based | ✅ | ❌ | ❌ | ❌ |

## Why Use UV?

1. **Speed**: 10-100x faster than pip
2. **Modern**: Built with modern Python packaging standards
3. **Simple**: Drop-in replacement for pip
4. **Reliable**: Deterministic dependency resolution
5. **Efficient**: Smart caching reduces redundant downloads
6. **Comprehensive**: Combines pip, pip-tools, and virtualenv functionality

## Next Steps

After installing UV:

1. ✅ Verify installation: `uv --version`
2. ✅ Create a test project: `uv init test-project`
3. ✅ Add dependencies: `uv add requests`
4. ✅ Explore UV documentation: https://docs.astral.sh/uv/
5. ✅ Proceed to Lab 02: Building Your First MCP Server

---

**Need Help?**

- Check the [troubleshooting section](#troubleshooting)
- Visit the [official documentation](https://docs.astral.sh/uv/)
- Review the [GitHub issues](https://github.com/astral-sh/uv/issues)
