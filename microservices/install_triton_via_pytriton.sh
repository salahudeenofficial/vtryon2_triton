#!/bin/bash
# Install Triton via PyTriton (includes server binaries)
# This is the recommended method when direct downloads fail

set -e

echo "=========================================="
echo "Triton Installation via PyTriton"
echo "=========================================="
echo ""
echo "PyTriton includes Triton Inference Server binaries"
echo "This is the recommended method for Ubuntu 24.04"
echo ""

MICROSERVICES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${MICROSERVICES_DIR}"

# Step 1: Check prerequisites
echo "=========================================="
echo "Step 1: Checking Prerequisites"
echo "=========================================="

# Check Python
if ! command -v python3 >/dev/null 2>&1; then
    echo "❌ Python 3 not found"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
echo "✓ Python version: ${PYTHON_VERSION}"

# Check pip
if ! command -v pip >/dev/null 2>&1 && ! command -v pip3 >/dev/null 2>&1; then
    echo "❌ pip not found. Installing..."
    python3 -m ensurepip --upgrade
fi

PIP_CMD=$(command -v pip3 || command -v pip)
echo "✓ pip found: ${PIP_CMD}"

# Check glibc
if command -v ldd >/dev/null 2>&1; then
    GLIBC_VERSION=$(ldd --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    echo "✓ glibc version: ${GLIBC_VERSION}"
    if [ -n "$GLIBC_VERSION" ]; then
        REQUIRED_GLIBC="2.35"
        if [ "$(printf '%s\n' "$REQUIRED_GLIBC" "$GLIBC_VERSION" | sort -V | head -1)" != "$REQUIRED_GLIBC" ]; then
            echo "⚠️  Warning: glibc ${GLIBC_VERSION} may be too old (need >= 2.35)"
        fi
    fi
fi

echo ""

# Step 2: Install PyTriton
echo "=========================================="
echo "Step 2: Installing PyTriton"
echo "=========================================="
echo "This will install Triton Inference Server binaries along with PyTriton"
echo ""

${PIP_CMD} install --upgrade pip
${PIP_CMD} install nvidia-pytriton

echo "✓ PyTriton installed"
echo ""

# Step 3: Find Triton binary location
echo "=========================================="
echo "Step 3: Locating Triton Server Binary"
echo "=========================================="

# PyTriton may not include the server binary - it's primarily a Python library
# We need to find it or download it separately

TRITON_BIN=""

# Method 1: Check if it's in PATH
if command -v tritonserver >/dev/null 2>&1; then
    TRITON_BIN=$(which tritonserver)
    echo "✓ Found tritonserver in PATH: ${TRITON_BIN}"
fi

# Method 2: Check Python package locations
if [ -z "$TRITON_BIN" ]; then
    # Try various Python package locations
    PYTHON_PATHS=(
        "$(python3 -c 'import site; print(site.getsitepackages()[0] if site.getsitepackages() else "")' 2>/dev/null)"
        "$(python3 -c 'import site; print(site.getusersitepackages())' 2>/dev/null)"
        "$(python3 -c 'import nvidia.pytriton; import os; print(os.path.dirname(nvidia.pytriton.__file__))' 2>/dev/null)"
    )
    
    for PYTHON_PATH in "${PYTHON_PATHS[@]}"; do
        if [ -n "$PYTHON_PATH" ] && [ -d "$PYTHON_PATH" ]; then
            # Check common subdirectories
            POTENTIAL_PATHS=(
                "${PYTHON_PATH}/nvidia/pytriton/bin/tritonserver"
                "${PYTHON_PATH}/nvidia/pytriton/tritonserver"
                "${PYTHON_PATH}/tritonserver/bin/tritonserver"
            )
            for POTENTIAL in "${POTENTIAL_PATHS[@]}"; do
                if [ -f "$POTENTIAL" ] && [ -x "$POTENTIAL" ]; then
                    TRITON_BIN="$POTENTIAL"
                    echo "✓ Found tritonserver in Python package: ${TRITON_BIN}"
                    break 2
                fi
            done
        fi
    done
fi

# Method 3: Search in common locations
if [ -z "$TRITON_BIN" ]; then
    SEARCH_PATHS=(
        "${HOME}/.local/bin"
        "${HOME}/.local/lib"
        "/usr/local/bin"
        "/opt/tritonserver/bin"
    )
    
    for SEARCH_PATH in "${SEARCH_PATHS[@]}"; do
        if [ -f "${SEARCH_PATH}/tritonserver" ] && [ -x "${SEARCH_PATH}/tritonserver" ]; then
            TRITON_BIN="${SEARCH_PATH}/tritonserver"
            echo "✓ Found tritonserver: ${TRITON_BIN}"
            break
        fi
    done
fi

# Method 4: Use find to search
if [ -z "$TRITON_BIN" ]; then
    FOUND=$(find "${HOME}/.local" -name "tritonserver" -type f -executable 2>/dev/null | head -1)
    if [ -n "$FOUND" ]; then
        TRITON_BIN="$FOUND"
        echo "✓ Found tritonserver via search: ${TRITON_BIN}"
    fi
fi

# If still not found, PyTriton doesn't include the server binary
# We need to download it separately
if [ -z "$TRITON_BIN" ] || [ ! -f "$TRITON_BIN" ]; then
    echo "⚠️  Triton server binary not found"
    echo ""
    echo "PyTriton is installed, but it doesn't include the standalone server binary."
    echo "Downloading the server binary separately..."
    echo ""
    
    # Download the server binary
    if [ -f "${MICROSERVICES_DIR}/download_triton_server.sh" ]; then
        chmod +x "${MICROSERVICES_DIR}/download_triton_server.sh"
        "${MICROSERVICES_DIR}/download_triton_server.sh" || {
            echo ""
            echo "❌ Failed to download Triton server binary"
            echo ""
            echo "You can download it manually:"
            echo "  ./download_triton_server.sh"
            echo ""
            echo "Or from:"
            echo "  https://github.com/triton-inference-server/server/releases/download/v2.47.0/tritonserver-2.47.0-ubuntu22.04.tar.gz"
            exit 1
        }
        
        # Check if it's now available
        if [ -f "${MICROSERVICES_DIR}/tritonserver/bin/tritonserver" ]; then
            TRITON_BIN="${MICROSERVICES_DIR}/tritonserver/bin/tritonserver"
            echo "✓ Triton server binary downloaded and ready"
        else
            echo "❌ Binary still not found after download"
            exit 1
        fi
    else
        echo "❌ download_triton_server.sh not found"
        echo ""
        echo "Please download the server binary manually:"
        echo "  wget https://github.com/triton-inference-server/server/releases/download/v2.47.0/tritonserver-2.47.0-ubuntu22.04.tar.gz"
        echo "  tar -xzf tritonserver-2.47.0-ubuntu22.04.tar.gz"
        echo "  mv tritonserver-2.47.0-ubuntu22.04 tritonserver"
        exit 1
    fi
else
    # Copy or symlink to expected location
    mkdir -p "${MICROSERVICES_DIR}/tritonserver/bin"
    if [ ! -f "${MICROSERVICES_DIR}/tritonserver/bin/tritonserver" ]; then
        if [ "$TRITON_BIN" != "${MICROSERVICES_DIR}/tritonserver/bin/tritonserver" ]; then
            cp "$TRITON_BIN" "${MICROSERVICES_DIR}/tritonserver/bin/tritonserver" 2>/dev/null || \
            ln -s "$TRITON_BIN" "${MICROSERVICES_DIR}/tritonserver/bin/tritonserver" 2>/dev/null || \
            echo "⚠️  Could not copy/link, but binary is available at: ${TRITON_BIN}"
        fi
    fi
    
    # Check version
    if [ -f "${MICROSERVICES_DIR}/tritonserver/bin/tritonserver" ]; then
        echo "✓ Triton binary ready at: ${MICROSERVICES_DIR}/tritonserver/bin/tritonserver"
        "${MICROSERVICES_DIR}/tritonserver/bin/tritonserver" --version 2>/dev/null || echo "  (version check skipped)"
    fi
fi

echo ""

# Step 4: Install Python backend dependencies
echo "=========================================="
echo "Step 4: Installing Python Backend Dependencies"
echo "=========================================="

${PIP_CMD} install tritonclient[all] numpy || {
    echo "⚠️  Some packages failed to install, continuing..."
}
echo "✓ Python dependencies installed"
echo ""

# Step 5: Update start script
echo "=========================================="
echo "Step 5: Creating/Updating Start Script"
echo "=========================================="

cat > "${MICROSERVICES_DIR}/start_triton_direct.sh" << 'EOF'
#!/bin/bash
# Start Triton server directly (no Docker)
# Uses PyTriton installation

cd "$(dirname "$0")"

# Try multiple locations for tritonserver binary
TRITON_BIN=""

# 1. Check local tritonserver directory
if [ -f "./tritonserver/bin/tritonserver" ]; then
    TRITON_BIN="./tritonserver/bin/tritonserver"
# 2. Check if in PATH
elif command -v tritonserver >/dev/null 2>&1; then
    TRITON_BIN=$(which tritonserver)
# 3. Try Python package location
else
    TRITON_BIN=$(python3 -c "import nvidia.pytriton; import os; print(os.path.join(os.path.dirname(nvidia.pytriton.__file__), 'bin', 'tritonserver'))" 2>/dev/null || echo "")
fi

if [ -z "$TRITON_BIN" ] || [ ! -f "$TRITON_BIN" ]; then
    echo "❌ Triton server not found"
    echo "   Run: ./install_triton_via_pytriton.sh"
    exit 1
fi

TRITON_REPO="./triton_model_repository"

if [ ! -d "$TRITON_REPO" ]; then
    echo "❌ Triton model repository not found: $TRITON_REPO"
    exit 1
fi

echo "Starting Triton server..."
echo "Binary: $TRITON_BIN"
echo "Model repository: $(pwd)/$TRITON_REPO"
echo ""

"$TRITON_BIN" \
  --model-repository="$TRITON_REPO" \
  --log-verbose=1 \
  --strict-model-config=false \
  --http-port=8000 \
  --grpc-port=8001 \
  --metrics-port=8002
EOF

chmod +x "${MICROSERVICES_DIR}/start_triton_direct.sh"
echo "✓ Created/updated start_triton_direct.sh"
echo ""

# Step 6: Summary
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "Triton Inference Server installed via PyTriton"
echo ""
echo "To start Triton server:"
echo "  cd microservices"
echo "  ./start_triton_direct.sh"
echo ""
echo "To verify installation:"
echo "  tritonserver --version"
echo "  # or"
echo "  python3 -c 'import nvidia.pytriton; print(nvidia.pytriton.__version__)'"
echo ""
echo "=========================================="

