#!/bin/bash
# setup_triton_direct.sh - Install Triton server directly (no Docker)
# For use in containerized VastAI instances

set -e

echo "=========================================="
echo "Triton Direct Installation (No Docker)"
echo "For Containerized VastAI Instances"
echo "=========================================="
echo ""

MICROSERVICES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRITON_REPO="${MICROSERVICES_DIR}/triton_model_repository"
# Use a more recent/stable version - check https://github.com/triton-inference-server/server/releases
TRITON_VERSION="2.48.0"

echo "Microservices Dir: ${MICROSERVICES_DIR}"
echo "Triton Repository: ${TRITON_REPO}"
echo ""

# Step 1: Check if Triton is already installed
if [ -d "${MICROSERVICES_DIR}/tritonserver" ] && [ -f "${MICROSERVICES_DIR}/tritonserver/bin/tritonserver" ]; then
    echo "✓ Triton server already installed"
    echo "  Location: ${MICROSERVICES_DIR}/tritonserver"
else
    echo "=========================================="
    echo "Step 1: Downloading Triton Server"
    echo "=========================================="
    
    cd "${MICROSERVICES_DIR}"
    
    # Detect Ubuntu version
    UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "24.04")
    echo "Detected Ubuntu version: ${UBUNTU_VERSION}"
    
    # Try multiple versions and package names
    # Triton release naming can vary: ubuntu2404, ubuntu22.04, ubuntu2004, etc.
    # Note: Ubuntu 24.04 may not have releases yet, so we try 22.04 packages which are compatible
    VERSIONS_TO_TRY=("2.47.0" "2.46.0" "2.45.0" "2.44.0" "2.43.0")
    PACKAGE_NAMES=()
    
    # Build list of package names to try
    # Ubuntu 24.04 can use 22.04 packages (they're usually compatible)
    if [[ "$UBUNTU_VERSION" == "24.04" ]]; then
        PACKAGE_NAMES=("ubuntu22.04" "ubuntu2204" "ubuntu2004" "ubuntu20.04")
    elif [[ "$UBUNTU_VERSION" == "22.04" ]]; then
        PACKAGE_NAMES=("ubuntu22.04" "ubuntu2204" "ubuntu2004" "ubuntu20.04")
    else
        PACKAGE_NAMES=("ubuntu2004" "ubuntu20.04" "ubuntu22.04" "ubuntu2204")
    fi
    
    DOWNLOAD_SUCCESS=false
    TRITON_PKG=""
    
    for VERSION in "${VERSIONS_TO_TRY[@]}"; do
        for PKG_SUFFIX in "${PACKAGE_NAMES[@]}"; do
            TRITON_PKG="tritonserver-${VERSION}-${PKG_SUFFIX}.tar.gz"
            TRITON_URL="https://github.com/triton-inference-server/server/releases/download/v${VERSION}/${TRITON_PKG}"
            
            echo "Trying: ${TRITON_URL}"
            if wget -q --spider "${TRITON_URL}" 2>/dev/null; then
                echo "✓ Found valid URL: ${TRITON_URL}"
                echo "Downloading..."
                if wget -q --show-progress "${TRITON_URL}"; then
                    DOWNLOAD_SUCCESS=true
                    TRITON_VERSION="${VERSION}"
                    break 2
                fi
            fi
        done
    done
    
    if [ "$DOWNLOAD_SUCCESS" = false ]; then
        echo "❌ Failed to download Triton server after trying multiple versions"
        echo ""
        echo "Please manually download from:"
        echo "  https://github.com/triton-inference-server/server/releases"
        echo ""
        echo "Or try installing via pip:"
        echo "  pip install tritonclient[all]"
        echo "  # Then use tritonserver from pip installation"
        echo ""
        echo "Or use Docker (if available):"
        echo "  docker pull nvcr.io/nvidia/tritonserver:latest-py3"
        exit 1
    fi
    
    echo "Extracting..."
    tar -xzf "${TRITON_PKG}"
    
    # Find and rename extracted directory (name varies by version)
    EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "tritonserver-*" | head -1)
    if [ -n "$EXTRACTED_DIR" ]; then
        mv "$EXTRACTED_DIR" tritonserver
        echo "✓ Extracted to: tritonserver/"
    else
        echo "⚠️  Warning: Could not find extracted directory, checking current directory..."
        if [ -d "tritonserver" ]; then
            echo "✓ Triton directory already exists"
        else
            echo "❌ Extraction failed or unexpected structure"
            exit 1
        fi
    fi
    
    # Cleanup
    rm -f "${TRITON_PKG}"
    
    echo "✓ Triton server installed"
fi
echo ""

# Step 2: Install Python backend dependencies
echo "=========================================="
echo "Step 2: Installing Python Dependencies"
echo "=========================================="

pip install -q tritonclient[all] numpy || {
    echo "⚠️  Some packages failed to install, continuing..."
}
echo "✓ Python dependencies installed"
echo ""

# Step 3: Create start script
echo "=========================================="
echo "Step 3: Creating Start Script"
echo "=========================================="

cat > "${MICROSERVICES_DIR}/start_triton_direct.sh" << EOF
#!/bin/bash
# Start Triton server directly (no Docker)

cd "$(dirname "\$0")"

TRITON_BIN="./tritonserver/bin/tritonserver"
TRITON_REPO="./triton_model_repository"

if [ ! -f "\$TRITON_BIN" ]; then
    echo "❌ Triton server not found. Run setup_triton_direct.sh first"
    exit 1
fi

if [ ! -d "\$TRITON_REPO" ]; then
    echo "❌ Triton model repository not found: \$TRITON_REPO"
    exit 1
fi

echo "Starting Triton server..."
echo "Model repository: \$(pwd)/\$TRITON_REPO"
echo ""

\$TRITON_BIN \\
  --model-repository=\$TRITON_REPO \\
  --log-verbose=1 \\
  --strict-model-config=false \\
  --http-port=8000 \\
  --grpc-port=8001 \\
  --metrics-port=8002
EOF

chmod +x "${MICROSERVICES_DIR}/start_triton_direct.sh"
echo "✓ Created start_triton_direct.sh"
echo ""

# Step 4: Verify installation
echo "=========================================="
echo "Step 4: Verifying Installation"
echo "=========================================="

if [ -f "${MICROSERVICES_DIR}/tritonserver/bin/tritonserver" ]; then
    echo "✓ Triton binary found"
    "${MICROSERVICES_DIR}/tritonserver/bin/tritonserver" --version || true
else
    echo "❌ Triton binary not found"
    exit 1
fi

if [ -d "${TRITON_REPO}" ]; then
    echo "✓ Model repository found"
    echo "  Models: $(find ${TRITON_REPO} -name "config.pbtxt" | wc -l) config files"
else
    echo "⚠️  Model repository not found: ${TRITON_REPO}"
fi

echo ""

# Step 5: Summary
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "To start Triton server:"
echo "  cd microservices"
echo "  ./start_triton_direct.sh"
echo ""
echo "Or manually:"
echo "  ./tritonserver/bin/tritonserver --model-repository=./triton_model_repository"
echo ""
echo "Server will be available at:"
echo "  HTTP: http://localhost:8000"
echo "  gRPC: localhost:8001"
echo "  Metrics: http://localhost:8002/metrics"
echo ""
echo "=========================================="

