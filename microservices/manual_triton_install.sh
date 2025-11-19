#!/bin/bash
# Manual Triton installation script
# Use this if setup_triton_direct.sh fails

set -e

echo "=========================================="
echo "Manual Triton Installation"
echo "=========================================="
echo ""

MICROSERVICES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${MICROSERVICES_DIR}"

# Try version 2.47.0 first (most recent stable)
echo "Attempting to download Triton 2.47.0 (Ubuntu 22.04 - compatible with 24.04)..."
if wget -q --show-progress https://github.com/triton-inference-server/server/releases/download/v2.47.0/tritonserver-2.47.0-ubuntu22.04.tar.gz; then
    echo "✓ Download successful"
    tar -xzf tritonserver-2.47.0-ubuntu22.04.tar.gz
    mv tritonserver-2.47.0-ubuntu22.04 tritonserver
    rm tritonserver-2.47.0-ubuntu22.04.tar.gz
    echo "✓ Triton installed successfully"
    exit 0
fi

# Try version 2.46.0
echo "Trying version 2.46.0..."
if wget -q --show-progress https://github.com/triton-inference-server/server/releases/download/v2.46.0/tritonserver-2.46.0-ubuntu22.04.tar.gz; then
    echo "✓ Download successful"
    tar -xzf tritonserver-2.46.0-ubuntu22.04.tar.gz
    mv tritonserver-2.46.0-ubuntu22.04 tritonserver
    rm tritonserver-2.46.0-ubuntu22.04.tar.gz
    echo "✓ Triton installed successfully"
    exit 0
fi

# Try version 2.45.0
echo "Trying version 2.45.0..."
if wget -q --show-progress https://github.com/triton-inference-server/server/releases/download/v2.45.0/tritonserver-2.45.0-ubuntu22.04.tar.gz; then
    echo "✓ Download successful"
    tar -xzf tritonserver-2.45.0-ubuntu22.04.tar.gz
    mv tritonserver-2.45.0-ubuntu22.04 tritonserver
    rm tritonserver-2.45.0-ubuntu22.04.tar.gz
    echo "✓ Triton installed successfully"
    exit 0
fi

echo "❌ All download attempts failed"
echo ""
echo "Please manually download from:"
echo "  https://github.com/triton-inference-server/server/releases"
echo ""
echo "Look for a release with 'ubuntu22.04' or 'ubuntu20.04' in the filename"
echo "Then extract and rename to 'tritonserver' directory"
exit 1

