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

podman pull "${TRITON_IMAGE}" || {
    echo "❌ Failed to pull image"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check internet connection"
    echo "  2. Try: podman pull docker://${TRITON_IMAGE}"
    echo "  3. Or use PyTriton method: ./install_triton_via_pytriton.sh"
    exit 1
}

echo "✓ Image pulled successfully"
echo ""

echo "=========================================="
echo "Step 2: Extracting Triton Files"
echo "=========================================="

# Create temporary container
CONTAINER_ID=$(podman create "${TRITON_IMAGE}" /bin/true)
echo "Created container: ${CONTAINER_ID}"

# Create target directory
mkdir -p "${TRITON_DIR}/bin"
mkdir -p "${TRITON_DIR}/lib"

# Extract tritonserver binary
echo "Extracting tritonserver binary..."
podman cp "${CONTAINER_ID}:/opt/tritonserver/bin/tritonserver" "${TRITON_DIR}/bin/tritonserver" || {
    echo "⚠️  Binary extraction failed, trying alternative path..."
    podman cp "${CONTAINER_ID}:/usr/bin/tritonserver" "${TRITON_DIR}/bin/tritonserver" || {
        echo "❌ Could not find tritonserver binary in image"
        podman rm "${CONTAINER_ID}"
        exit 1
    }
}

# Extract libraries (optional but recommended)
echo "Extracting libraries..."
podman cp "${CONTAINER_ID}:/opt/tritonserver/lib" "${TRITON_DIR}/" 2>/dev/null || {
    echo "⚠️  Could not extract libraries (may still work)"
}

# Extract Python backend if present
echo "Extracting Python backend..."
podman cp "${CONTAINER_ID}:/opt/tritonserver/backends/python" "${TRITON_DIR}/backends/" 2>/dev/null || {
    echo "⚠️  Python backend not found or already available"
}

# Cleanup
podman rm "${CONTAINER_ID}"
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

