# This is a script to set up the development environment for the AI Course
# It installs necessary packages and tools
#!/bin/bash

#rm -rf mkdir echo-mcp-server
# Create project directory
mkdir echo-mcp-server 2>/dev/null || true
cd echo-mcp-server || exit 1;

# Create and activate a Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip 

# Install required Python packages
cat << EOF > requirements.txt
uv
zellij
EOF

# Install additional tools
pip install -r requirements.txt

# Initialize UV project
uv init

# Create a Zellij layout file
cat << EOF >> zellij-layout.kdl
layout {
    pane split_direction="vertical" {
        pane
        pane split_direction="horizontal" {
            pane
            pane
        }
    }
}
EOF

# Start Zellij with the custom layout
zellij --layout=zellij-layout.kdl

