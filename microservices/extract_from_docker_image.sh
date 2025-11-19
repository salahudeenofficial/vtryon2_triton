#!/bin/bash
# Extract Triton from Docker image using podman (works without Docker daemon)
# This is the simplest workaround for containerized environments

set -e

echo "=========================================="
echo "Extract Triton from Docker Image (Podman)"
echo "=========================================="
echo ""

MICROSERVICES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${MICROSERVICES_DIR}"

# Check if podman is available
if ! command -v podman >/dev/null 2>&1; then
    echo "Installing podman (works without Docker daemon)..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq podman >/dev/null 2>&1 || {
        echo "⚠️  Could not install podman automatically"
        echo "   Try: sudo apt-get install podman"
        exit 1
    }
fi

echo "✓ Podman available"
echo ""

TRITON_IMAGE="nvcr.io/nvidia/tritonserver:25.10-py3"
TRITON_DIR="${MICROSERVICES_DIR}/tritonserver"

echo "=========================================="
echo "Step 1: Pulling Docker Image"
echo "=========================================="
echo "Pulling: ${TRITON_IMAGE}"
echo "This may take a few minutes..."
echo ""

# Try podman with different options to handle permission issues
PODMAN_PULL_SUCCESS=false

# Try 1: Standard pull
if podman pull "${TRITON_IMAGE}" 2>/dev/null; then
    PODMAN_PULL_SUCCESS=true
# Try 2: With docker:// prefix
elif podman pull "docker://${TRITON_IMAGE}" 2>/dev/null; then
    TRITON_IMAGE="docker://${TRITON_IMAGE}"
    PODMAN_PULL_SUCCESS=true
# Try 3: With rootless configuration
elif podman --root="${HOME}/.local/share/containers/storage" pull "${TRITON_IMAGE}" 2>/dev/null; then
    PODMAN_PULL_SUCCESS=true
# Try 4: Use sudo (if available)
elif sudo podman pull "${TRITON_IMAGE}" 2>/dev/null; then
    PODMAN_PULL_SUCCESS=true
fi

if [ "$PODMAN_PULL_SUCCESS" = false ]; then
    echo "❌ Failed to pull image with podman"
    echo ""
    echo "=========================================="
    echo "Alternative: Use PyTriton (Simpler)"
    echo "=========================================="
    echo ""
    echo "Since podman has permission issues, use PyTriton instead:"
    echo ""
    echo "  ./install_triton_via_pytriton.sh"
    echo ""
    echo "This installs Triton via pip and is much simpler."
    echo ""
    exit 1
fi

echo "✓ Image pulled successfully"
echo ""

echo "=========================================="
echo "Step 2: Extracting Triton Files"
echo "=========================================="

# Create temporary container (try with sudo if needed)
CONTAINER_ID=""
if podman create "${TRITON_IMAGE}" /bin/true 2>/dev/null; then
    CONTAINER_ID=$(podman create "${TRITON_IMAGE}" /bin/true 2>&1 | tail -1 | grep -oE '[a-f0-9]{64}' | head -1)
elif sudo podman create "${TRITON_IMAGE}" /bin/true 2>/dev/null; then
    CONTAINER_ID=$(sudo podman create "${TRITON_IMAGE}" /bin/true 2>&1 | tail -1 | grep -oE '[a-f0-9]{64}' | head -1)
    USE_SUDO="sudo"
else
    echo "❌ Could not create container"
    exit 1
fi

echo "Created container: ${CONTAINER_ID}"

# Create target directory
mkdir -p "${TRITON_DIR}/bin"
mkdir -p "${TRITON_DIR}/lib"

# Extract tritonserver binary (try with/without sudo)
EXTRACT_SUCCESS=false
if [ -n "$USE_SUDO" ]; then
    if sudo podman cp "${CONTAINER_ID}:/opt/tritonserver/bin/tritonserver" "${TRITON_DIR}/bin/tritonserver" 2>/dev/null; then
        EXTRACT_SUCCESS=true
    elif sudo podman cp "${CONTAINER_ID}:/usr/bin/tritonserver" "${TRITON_DIR}/bin/tritonserver" 2>/dev/null; then
        EXTRACT_SUCCESS=true
    fi
else
    if podman cp "${CONTAINER_ID}:/opt/tritonserver/bin/tritonserver" "${TRITON_DIR}/bin/tritonserver" 2>/dev/null; then
        EXTRACT_SUCCESS=true
    elif podman cp "${CONTAINER_ID}:/usr/bin/tritonserver" "${TRITON_DIR}/bin/tritonserver" 2>/dev/null; then
        EXTRACT_SUCCESS=true
    fi
fi

if [ "$EXTRACT_SUCCESS" = false ]; then
    echo "❌ Could not extract tritonserver binary"
    if [ -n "$USE_SUDO" ]; then
        sudo podman rm "${CONTAINER_ID}" 2>/dev/null
    else
        podman rm "${CONTAINER_ID}" 2>/dev/null
    fi
    echo ""
    echo "Try PyTriton method instead:"
    echo "  ./install_triton_via_pytriton.sh"
    exit 1
fi

echo "✓ Binary extracted"

# Extract libraries (optional but recommended)
echo "Extracting libraries..."
if [ -n "$USE_SUDO" ]; then
    sudo podman cp "${CONTAINER_ID}:/opt/tritonserver/lib" "${TRITON_DIR}/" 2>/dev/null || {
        echo "⚠️  Could not extract libraries (may still work)"
    }
else
    podman cp "${CONTAINER_ID}:/opt/tritonserver/lib" "${TRITON_DIR}/" 2>/dev/null || {
        echo "⚠️  Could not extract libraries (may still work)"
    }
fi

# Extract Python backend if present
echo "Extracting Python backend..."
if [ -n "$USE_SUDO" ]; then
    sudo podman cp "${CONTAINER_ID}:/opt/tritonserver/backends/python" "${TRITON_DIR}/backends/" 2>/dev/null || {
        echo "⚠️  Python backend not found or already available"
    }
else
    podman cp "${CONTAINER_ID}:/opt/tritonserver/backends/python" "${TRITON_DIR}/backends/" 2>/dev/null || {
        echo "⚠️  Python backend not found or already available"
    }
fi

# Cleanup
if [ -n "$USE_SUDO" ]; then
    sudo podman rm "${CONTAINER_ID}" 2>/dev/null
else
    podman rm "${CONTAINER_ID}" 2>/dev/null
fi
echo "✓ Container removed"

# Make binary executable
chmod +x "${TRITON_DIR}/bin/tritonserver"

# Verify
if [ -f "${TRITON_DIR}/bin/tritonserver" ]; then
    echo ""
    echo "=========================================="
    echo "Extraction Complete!"
    echo "=========================================="
    echo ""
    echo "Triton binary: ${TRITON_DIR}/bin/tritonserver"
    echo ""
    echo "Testing binary..."
    "${TRITON_DIR}/bin/tritonserver" --version || echo "  (version check skipped)"
    echo ""
    echo "✓ Ready to use!"
    echo ""
    echo "Start Triton with:"
    echo "  ./start_triton_direct.sh"
    echo ""
else
    echo "❌ Extraction failed"
    exit 1
fi

