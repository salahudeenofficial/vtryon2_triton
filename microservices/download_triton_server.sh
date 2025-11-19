#!/bin/bash
# Download Triton Inference Server binary from GitHub releases
# This is needed because PyTriton doesn't include the standalone server binary

set -e

echo "=========================================="
echo "Download Triton Inference Server Binary"
echo "=========================================="
echo ""

MICROSERVICES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${MICROSERVICES_DIR}"

# Use version 2.47.0 (has server binary for Ubuntu 22.04, works on 24.04)
TRITON_VERSION="2.47.0"
UBUNTU_VERSION="22.04"  # Ubuntu 22.04 package works on 24.04

DOWNLOAD_URL="https://github.com/triton-inference-server/server/releases/download/v${TRITON_VERSION}/tritonserver-${TRITON_VERSION}-ubuntu${UBUNTU_VERSION}.tar.gz"
TAR_FILE="tritonserver-${TRITON_VERSION}-ubuntu${UBUNTU_VERSION}.tar.gz"
EXTRACT_DIR="tritonserver-${TRITON_VERSION}-ubuntu${UBUNTU_VERSION}"

echo "Downloading Triton server ${TRITON_VERSION}..."
echo "URL: ${DOWNLOAD_URL}"
echo ""

# Check if already downloaded
if [ -f "${TAR_FILE}" ]; then
    echo "✓ Archive already exists: ${TAR_FILE}"
else
    # Download
    if command -v wget >/dev/null 2>&1; then
        wget -q --show-progress "${DOWNLOAD_URL}" || {
            echo "❌ Download failed"
            echo ""
            echo "Try manually:"
            echo "  wget ${DOWNLOAD_URL}"
            echo "  tar -xzf ${TAR_FILE}"
            exit 1
        }
    elif command -v curl >/dev/null 2>&1; then
        curl -L -o "${TAR_FILE}" "${DOWNLOAD_URL}" || {
            echo "❌ Download failed"
            exit 1
        }
    else
        echo "❌ Neither wget nor curl found"
        exit 1
    fi
    echo "✓ Downloaded: ${TAR_FILE}"
fi

echo ""
echo "Extracting..."
tar -xzf "${TAR_FILE}" || {
    echo "❌ Extraction failed"
    exit 1
}

# Rename to consistent directory name
if [ -d "${EXTRACT_DIR}" ]; then
    if [ -d "tritonserver" ] && [ "${EXTRACT_DIR}" != "tritonserver" ]; then
        rm -rf tritonserver
    fi
    if [ "${EXTRACT_DIR}" != "tritonserver" ]; then
        mv "${EXTRACT_DIR}" tritonserver
    fi
fi

# Verify binary exists
if [ -f "tritonserver/bin/tritonserver" ]; then
    chmod +x tritonserver/bin/tritonserver
    echo "✓ Triton server binary ready: tritonserver/bin/tritonserver"
    echo ""
    echo "Testing binary..."
    ./tritonserver/bin/tritonserver --version || echo "  (version check skipped)"
    echo ""
    echo "=========================================="
    echo "Installation Complete!"
    echo "=========================================="
    echo ""
    echo "Triton server binary is ready at:"
    echo "  $(pwd)/tritonserver/bin/tritonserver"
    echo ""
    echo "Start Triton with:"
    echo "  ./start_triton_direct.sh"
    echo ""
else
    echo "❌ Binary not found after extraction"
    exit 1
fi

