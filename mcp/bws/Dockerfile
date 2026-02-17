# Robust Dockerfile for BWS MCP Server (SSOT)
# Includes both Python SDK and BWS CLI (from correct sdk-sm repo)

FROM python:3.11-slim

WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install BWS CLI (Secrets Manager) v2.0.0
# Verified URL: https://github.com/bitwarden/sdk-sm/releases/download/bws-v2.0.0/bws-x86_64-unknown-linux-gnu-2.0.0.zip
RUN curl -fsSL -o bws.zip "https://github.com/bitwarden/sdk-sm/releases/download/bws-v2.0.0/bws-x86_64-unknown-linux-gnu-2.0.0.zip" && \
    unzip bws.zip && \
    mv bws /usr/local/bin/bws && \
    chmod +x /usr/local/bin/bws && \
    rm bws.zip

# Verify BWS installation
RUN bws --version

# Install Python dependencies
RUN pip install --no-cache-dir \
    mcp \
    bitwarden-sdk \
    python-dotenv

# Copy server code
COPY server.py .

# Expose MCP port (if using SSE or similar)
EXPOSE 9000

CMD ["python", "server.py"]
