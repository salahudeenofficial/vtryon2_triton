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

# Extract from OCI layout
# OCI images store layers as tar files in blobs/sha256/ directories
ROOTFS="${TEMP_DIR}/rootfs"
mkdir -p "${ROOTFS}"

echo "Extracting from OCI layout..."

# Find all layer tar files in the OCI layout
LAYER_TARS=$(find "${TEMP_DIR}" -path "*/blobs/sha256/*.tar" -o -path "*/blobs/sha256/*.tar.gz" 2>/dev/null | sort)

if [ -z "$LAYER_TARS" ]; then
    # Try alternative OCI structure
    LAYER_TARS=$(find "${TEMP_DIR}" -type f \( -name "*.tar" -o -name "*.tar.gz" \) 2>/dev/null | sort)
fi

if [ -z "$LAYER_TARS" ]; then
    echo "❌ No layer tar files found in OCI layout"
    echo "   OCI layout structure:"
    find "${TEMP_DIR}" -type f | head -10
    rm -rf "${TEMP_DIR}"
    exit 1
fi

echo "Found $(echo "$LAYER_TARS" | wc -l) layer(s) to extract..."

# Extract all layers (they overlay each other)
for LAYER_TAR in $LAYER_TARS; do
    if [ -f "$LAYER_TAR" ]; then
        echo "  Extracting layer: $(basename "$LAYER_TAR")"
        # Extract, overwriting files from previous layers
        tar -xf "$LAYER_TAR" -C "${ROOTFS}" 2>/dev/null || {
            # Try gzip if tar fails
            if [[ "$LAYER_TAR" == *.gz ]]; then
                gunzip -c "$LAYER_TAR" | tar -xf - -C "${ROOTFS}" 2>/dev/null || true
            fi
        }
    fi
done

echo "✓ Layers extracted"

# Create target directory
mkdir -p "${TRITON_DIR}/bin"
mkdir -p "${TRITON_DIR}/lib"

# Extract tritonserver binary
echo "Extracting tritonserver binary..."
BINARY_FOUND=false

# Check expected locations
if [ -f "${ROOTFS}/opt/tritonserver/bin/tritonserver" ]; then
    mkdir -p "${TRITON_DIR}/bin"
    cp "${ROOTFS}/opt/tritonserver/bin/tritonserver" "${TRITON_DIR}/bin/tritonserver"
    echo "✓ Binary extracted from /opt/tritonserver/bin"
    BINARY_FOUND=true
elif [ -f "${ROOTFS}/usr/bin/tritonserver" ]; then
    mkdir -p "${TRITON_DIR}/bin"
    cp "${ROOTFS}/usr/bin/tritonserver" "${TRITON_DIR}/bin/tritonserver"
    echo "✓ Binary extracted from /usr/bin"
    BINARY_FOUND=true
else
    echo "⚠️  Binary not found in expected locations"
    echo "   Searching in extracted files..."
    
    # Search for tritonserver binary
    FOUND_BINARY=$(find "${ROOTFS}" -name "tritonserver" -type f -executable 2>/dev/null | head -1)
    
    if [ -n "$FOUND_BINARY" ] && [ -f "$FOUND_BINARY" ]; then
        mkdir -p "${TRITON_DIR}/bin"
        cp "$FOUND_BINARY" "${TRITON_DIR}/bin/tritonserver"
        echo "✓ Binary found and extracted: $FOUND_BINARY"
        BINARY_FOUND=true
    else
        echo "❌ Binary not found. Checking extracted structure..."
        echo "   Root directory contents:"
        ls -la "${ROOTFS}" 2>/dev/null | head -20
        echo ""
        echo "   /opt directory:"
        ls -la "${ROOTFS}/opt" 2>/dev/null | head -10 || echo "   /opt not found"
        echo ""
        echo "   /usr/bin directory:"
        ls -la "${ROOTFS}/usr/bin" 2>/dev/null | grep triton || echo "   /usr/bin/tritonserver not found"
    fi
fi

if [ "$BINARY_FOUND" = false ]; then
    echo "❌ Could not find tritonserver binary"
    rm -rf "${TEMP_DIR}"
    exit 1
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

