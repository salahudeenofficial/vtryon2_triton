#!/bin/bash
# Extract Triton from Docker image using skopeo (works without Docker daemon)
# Alternative to podman for containerized environments

set -e

echo "=========================================="
echo "Extract Triton from Docker Image (Skopeo)"
echo "=========================================="
echo ""

MICROSERVICES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${MICROSERVICES_DIR}"

# Check if skopeo is available
if ! command -v skopeo >/dev/null 2>&1; then
    echo "Installing skopeo (works without Docker daemon)..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq skopeo >/dev/null 2>&1 || {
        echo "⚠️  Could not install skopeo automatically"
        echo "   Try: sudo apt-get install skopeo"
        exit 1
    }
fi

echo "✓ Skopeo available"
echo ""

TRITON_IMAGE="nvcr.io/nvidia/tritonserver:25.10-py3"
TRITON_DIR="${MICROSERVICES_DIR}/tritonserver"
TEMP_DIR=$(mktemp -d)

echo "=========================================="
echo "Step 1: Copying Image to OCI Format"
echo "=========================================="
echo "Image: ${TRITON_IMAGE}"
echo "This may take a few minutes..."
echo ""

# Copy image to OCI format (no daemon needed)
skopeo copy "docker://${TRITON_IMAGE}" "oci:${TEMP_DIR}/triton-image:latest" || {
    echo "❌ Failed to copy image"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check internet connection"
    echo "  2. Try: skopeo copy docker://${TRITON_IMAGE} oci:${TEMP_DIR}/triton-image:latest"
    rm -rf "${TEMP_DIR}"
    exit 1
}

echo "✓ Image copied to OCI format"
echo ""

echo "=========================================="
echo "Step 2: Extracting Files"
echo "=========================================="

# Extract using umoci or directly from OCI layout
if command -v umoci >/dev/null 2>&1; then
    # Use umoci to extract
    umoci unpack --image "${TEMP_DIR}/triton-image:latest" "${TEMP_DIR}/rootfs" || {
        echo "⚠️  umoci unpack failed, trying alternative method..."
    }
    ROOTFS="${TEMP_DIR}/rootfs/rootfs"
else
    # Manual extraction from OCI layout
    # OCI images are stored in blobs, we need to extract the layer
    echo "Extracting from OCI layout..."
    # Find the layer blob
    LAYER_BLOB=$(find "${TEMP_DIR}" -name "*.tar" -o -name "*.tar.gz" | head -1)
    if [ -n "$LAYER_BLOB" ]; then
        mkdir -p "${TEMP_DIR}/rootfs"
        tar -xf "${LAYER_BLOB}" -C "${TEMP_DIR}/rootfs" 2>/dev/null || true
    fi
    ROOTFS="${TEMP_DIR}/rootfs"
fi

# Create target directory
mkdir -p "${TRITON_DIR}/bin"
mkdir -p "${TRITON_DIR}/lib"

# Extract tritonserver binary
echo "Extracting tritonserver binary..."
if [ -f "${ROOTFS}/opt/tritonserver/bin/tritonserver" ]; then
    cp "${ROOTFS}/opt/tritonserver/bin/tritonserver" "${TRITON_DIR}/bin/tritonserver"
    echo "✓ Binary extracted from /opt/tritonserver/bin"
elif [ -f "${ROOTFS}/usr/bin/tritonserver" ]; then
    cp "${ROOTFS}/usr/bin/tritonserver" "${TRITON_DIR}/bin/tritonserver"
    echo "✓ Binary extracted from /usr/bin"
else
    echo "⚠️  Binary not found in expected locations"
    echo "   Searching..."
    find "${ROOTFS}" -name "tritonserver" -type f 2>/dev/null | head -1 | while read BINARY; do
        if [ -n "$BINARY" ]; then
            cp "$BINARY" "${TRITON_DIR}/bin/tritonserver"
            echo "✓ Binary found and extracted: $BINARY"
        fi
    done
fi

# Extract libraries
echo "Extracting libraries..."
if [ -d "${ROOTFS}/opt/tritonserver/lib" ]; then
    cp -r "${ROOTFS}/opt/tritonserver/lib" "${TRITON_DIR}/" 2>/dev/null || {
        echo "⚠️  Could not extract libraries (may still work)"
    }
fi

# Extract Python backend if present
echo "Extracting Python backend..."
if [ -d "${ROOTFS}/opt/tritonserver/backends/python" ]; then
    mkdir -p "${TRITON_DIR}/backends"
    cp -r "${ROOTFS}/opt/tritonserver/backends/python" "${TRITON_DIR}/backends/" 2>/dev/null || {
        echo "⚠️  Python backend not found or already available"
    }
fi

# Cleanup
rm -rf "${TEMP_DIR}"
echo "✓ Temporary files removed"

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
    echo "❌ Extraction failed - binary not found"
    exit 1
fi

