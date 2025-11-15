FROM alpine

# Install system dependencies
RUN apk update && apk add --no-cache \
    bash \
    curl \
    git \
    wget \
    python3 \
    py3-pip \
    jq \
    nodejs \
    npm \
    cargo \
    rust

# Install uv (Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    ln -s /root/.cargo/bin/uv /usr/local/bin/uv

# Install Zellij
RUN cargo install --locked zellij && \
    ln -s /root/.cargo/bin/zellij /usr/local/bin/zellij

# Install MCP Inspector
RUN npm install -g @modelcontextprotocol/inspector

# Set working directory
WORKDIR /workspace

# Set default shell
ENV SHELL=/bin/bash

CMD ["/bin/bash"]               
