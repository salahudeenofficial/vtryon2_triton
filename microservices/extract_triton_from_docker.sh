#!/bin/bash
# Extract Triton server from Docker image without Docker daemon
# This works by downloading the image tar and extracting files

set -e

echo "=========================================="
echo "Extract Triton from Docker Image"
echo "=========================================="
echo ""

MICROSERVICES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${MICROSERVICES_DIR}"

# Option 1: Use skopeo (if available) - best method
if command -v skopeo >/dev/null 2>&1; then
    echo "=========================================="
    echo "Option 1: Using skopeo (Recommended)"
    echo "=========================================="
    echo ""
    
    TRITON_IMAGE="docker://nvcr.io/nvidia/tritonserver:25.10-py3"
    EXTRACT_DIR="${MICROSERVICES_DIR}/triton_extract"
    
    echo "Copying Docker image to local directory..."
    mkdir -p "${EXTRACT_DIR}"
    skopeo copy "${TRITON_IMAGE}" "oci:${EXTRACT_DIR}:triton" || {
        echo "⚠️  skopeo copy failed, trying alternative..."
    }
    
    # Extract from OCI layout
    if [ -d "${EXTRACT_DIR}/blobs" ]; then
        echo "Extracting Triton binary from image..."
        # Find and extract the layer with tritonserver
        # This is complex, so we'll use a simpler approach below
    fi
fi

# Option 2: Download pre-extracted binary or use alternative
echo ""
echo "=========================================="
echo "Option 2: Download Docker Image and Extract"
echo "=========================================="
echo ""

# Check if we can use podman (works without daemon)
if command -v podman >/dev/null 2>&1; then
    echo "Using podman to extract..."
    TRITON_IMAGE="nvcr.io/nvidia/tritonserver:25.10-py3"
    
    echo "Pulling image..."
    podman pull "${TRITON_IMAGE}" || {
        echo "⚠️  podman pull failed"
    }
    
    echo "Creating container to extract files..."
    CONTAINER_ID=$(podman create "${TRITON_IMAGE}" /bin/true)
    
    echo "Extracting tritonserver binary..."
    mkdir -p "${MICROSERVICES_DIR}/tritonserver/bin"
    podman cp "${CONTAINER_ID}:/opt/tritonserver/bin/tritonserver" "${MICROSERVICES_DIR}/tritonserver/bin/tritonserver" || {
        echo "⚠️  Could not extract binary"
    }
    
    # Extract libraries if needed
    mkdir -p "${MICROSERVICES_DIR}/tritonserver/lib"
    podman cp "${CONTAINER_ID}:/opt/tritonserver/lib" "${MICROSERVICES_DIR}/tritonserver/lib" 2>/dev/null || true
    
    podman rm "${CONTAINER_ID}"
    
    if [ -f "${MICROSERVICES_DIR}/tritonserver/bin/tritonserver" ]; then
        chmod +x "${MICROSERVICES_DIR}/tritonserver/bin/tritonserver"
        echo "✓ Triton binary extracted successfully"
        "${MICROSERVICES_DIR}/tritonserver/bin/tritonserver" --version || true
        exit 0
    fi
fi

# Option 3: Manual download of image tar and extract
echo ""
echo "=========================================="
echo "Option 3: Manual Image Download"
echo "=========================================="
echo ""
echo "If the above methods don't work, you can:"
echo ""
echo "1. Download Docker image tar from a machine with Docker:"
echo "   docker pull nvcr.io/nvidia/tritonserver:25.10-py3"
echo "   docker save nvcr.io/nvidia/tritonserver:25.10-py3 -o tritonserver.tar"
echo ""
echo "2. Transfer to VastAI and extract:"
echo "   tar -xf tritonserver.tar"
echo "   # Then extract the layer containing /opt/tritonserver/bin/tritonserver"
echo ""

# Option 4: Use crane (Google's container tool)
if command -v crane >/dev/null 2>&1; then
    echo "=========================================="
    echo "Option 4: Using crane"
    echo "=========================================="
    echo ""
    
    TRITON_IMAGE="nvcr.io/nvidia/tritonserver:25.10-py3"
    EXTRACT_DIR="${MICROSERVICES_DIR}/triton_extract"
    
    echo "Pulling image manifest..."
    crane pull "${TRITON_IMAGE}" "${EXTRACT_DIR}/image.tar" || {
        echo "⚠️  crane pull failed"
    }
    
    if [ -f "${EXTRACT_DIR}/image.tar" ]; then
        echo "Extracting from tar..."
        tar -xf "${EXTRACT_DIR}/image.tar" -C "${EXTRACT_DIR}"
        # Extract tritonserver from layers
        # This requires parsing the manifest and extracting the right layer
    fi
fi

echo ""
echo "=========================================="
echo "Simplest Solution: Use PyTriton"
echo "=========================================="
echo ""
echo "The easiest method is to use PyTriton which includes Triton:"
echo "  ./install_triton_via_pytriton.sh"
echo ""
echo "Or if you have access to a machine with Docker:"
echo "  1. Pull image: docker pull nvcr.io/nvidia/tritonserver:25.10-py3"
echo "  2. Extract: docker run --rm -v \$(pwd):/output nvcr.io/nvidia/tritonserver:25.10-py3 cp -r /opt/tritonserver /output/"
echo "  3. Transfer the extracted directory to VastAI"
echo ""

exit 1

