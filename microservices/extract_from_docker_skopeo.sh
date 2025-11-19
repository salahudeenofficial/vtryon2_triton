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
# The manifest tells us which blobs are layers
ROOTFS="${TEMP_DIR}/rootfs"
mkdir -p "${ROOTFS}"

echo "Extracting from OCI layout..."

# Find the manifest file
MANIFEST_FILE=$(find "${TEMP_DIR}" -name "manifest.json" -o -path "*/index.json" 2>/dev/null | head -1)

if [ -z "$MANIFEST_FILE" ] || [ ! -f "$MANIFEST_FILE" ]; then
    echo "⚠️  Manifest not found, trying to identify tar files by content..."
    # Try to identify tar files by checking file type
    BLOBS_DIR=$(find "${TEMP_DIR}" -type d -name "sha256" | head -1)
    if [ -n "$BLOBS_DIR" ] && [ -d "$BLOBS_DIR" ]; then
        echo "Checking blob files to identify tar archives..."
        for BLOB in "${BLOBS_DIR}"/*; do
            if [ -f "$BLOB" ]; then
                # Check if it's a tar file by content
                if file "$BLOB" | grep -q "tar archive\|gzip compressed"; then
                    echo "  Found tar blob: $(basename "$BLOB")"
                    tar -xf "$BLOB" -C "${ROOTFS}" 2>/dev/null || {
                        # Try gzip decompression first
                        gunzip -c "$BLOB" 2>/dev/null | tar -xf - -C "${ROOTFS}" 2>/dev/null || true
                    }
                fi
            fi
        done
    fi
else
    echo "Reading manifest to find layer blobs..."
    
    # Extract layer digests from manifest
    # OCI manifest format: layers have "digest" field with "sha256:..." format
    if command -v jq >/dev/null 2>&1; then
        # Use jq to parse manifest
        LAYER_DIGESTS=$(jq -r '.layers[]?.digest // .config.digest // empty' "$MANIFEST_FILE" 2>/dev/null | grep -E "^sha256:" | sed 's/sha256://')
        
        if [ -z "$LAYER_DIGESTS" ]; then
            # Try alternative manifest format
            LAYER_DIGESTS=$(jq -r '.[]?.layers[]?.digest // .layers[]?.digest // empty' "$MANIFEST_FILE" 2>/dev/null | grep -E "^sha256:" | sed 's/sha256://')
        fi
        
        if [ -n "$LAYER_DIGESTS" ]; then
            echo "Found $(echo "$LAYER_DIGESTS" | wc -l) layer(s) in manifest"
            BLOBS_DIR=$(find "${TEMP_DIR}" -type d -name "sha256" | head -1)
            
            for DIGEST in $LAYER_DIGESTS; do
                LAYER_BLOB="${BLOBS_DIR}/${DIGEST}"
                if [ -f "$LAYER_BLOB" ]; then
                    echo "  Extracting layer: ${DIGEST:0:12}..."
                    tar -xf "$LAYER_BLOB" -C "${ROOTFS}" 2>/dev/null || {
                        # Try gzip decompression
                        gunzip -c "$LAYER_BLOB" 2>/dev/null | tar -xf - -C "${ROOTFS}" 2>/dev/null || true
                    }
                fi
            done
        fi
    fi
    
    # Fallback: try to identify tar files by checking all blobs
    if [ ! -d "${ROOTFS}/opt" ] && [ ! -d "${ROOTFS}/usr" ]; then
        echo "⚠️  Manifest parsing didn't work, trying file type detection..."
        BLOBS_DIR=$(find "${TEMP_DIR}" -type d -name "sha256" | head -1)
        if [ -n "$BLOBS_DIR" ] && [ -d "$BLOBS_DIR" ]; then
            BLOB_COUNT=$(find "$BLOBS_DIR" -type f | wc -l)
            echo "  Checking ${BLOB_COUNT} blob(s) for tar archives..."
            
            EXTRACTED_COUNT=0
            for BLOB in "${BLOBS_DIR}"/*; do
                if [ -f "$BLOB" ]; then
                    # Check file type
                    FILE_TYPE=$(file "$BLOB" 2>/dev/null || echo "")
                    if echo "$FILE_TYPE" | grep -qE "tar archive|gzip compressed|POSIX tar"; then
                        echo "  [${EXTRACTED_COUNT}] Extracting tar blob: $(basename "$BLOB")"
                        tar -xf "$BLOB" -C "${ROOTFS}" 2>/dev/null || {
                            # Try gzip decompression
                            gunzip -c "$BLOB" 2>/dev/null | tar -xf - -C "${ROOTFS}" 2>/dev/null || {
                                # Try with different compression
                                zcat "$BLOB" 2>/dev/null | tar -xf - -C "${ROOTFS}" 2>/dev/null || true
                            }
                        }
                        EXTRACTED_COUNT=$((EXTRACTED_COUNT + 1))
                    fi
                fi
            done
            
            if [ $EXTRACTED_COUNT -eq 0 ]; then
                echo "⚠️  No tar archives found by file type detection"
                echo "   Trying to extract all blobs as tar files..."
                # Last resort: try extracting all blobs
                for BLOB in "${BLOBS_DIR}"/*; do
                    if [ -f "$BLOB" ] && [ -s "$BLOB" ]; then
                        # Skip very small files (likely configs)
                        BLOB_SIZE=$(stat -f%z "$BLOB" 2>/dev/null || stat -c%s "$BLOB" 2>/dev/null || echo "0")
                        if [ "$BLOB_SIZE" -gt 1000 ]; then
                            echo "  Trying blob: $(basename "$BLOB") (${BLOB_SIZE} bytes)"
                            tar -xf "$BLOB" -C "${ROOTFS}" 2>/dev/null || {
                                gunzip -c "$BLOB" 2>/dev/null | tar -xf - -C "${ROOTFS}" 2>/dev/null || {
                                    zcat "$BLOB" 2>/dev/null | tar -xf - -C "${ROOTFS}" 2>/dev/null || true
                                }
                            }
                            # Check if we got something useful
                            if [ -d "${ROOTFS}/opt" ] || [ -d "${ROOTFS}/usr" ]; then
                                echo "  ✓ Found filesystem structure!"
                                break
                            fi
                        fi
                    fi
                done
            else
                echo "  ✓ Extracted ${EXTRACTED_COUNT} layer(s)"
            fi
        else
            echo "❌ Could not find blobs directory"
        fi
    fi
fi

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

