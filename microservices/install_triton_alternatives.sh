#!/bin/bash
# Alternative Triton installation methods
# Use this if direct download fails

set -e

echo "=========================================="
echo "Triton Alternative Installation Methods"
echo "=========================================="
echo ""

MICROSERVICES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${MICROSERVICES_DIR}"

echo "Since direct download links are not working, here are alternatives:"
echo ""

echo "=========================================="
echo "Option 1: Try Specific Known Working URLs"
echo "=========================================="
echo ""

# Try to find working URLs by checking multiple versions
VERSIONS=("2.47.0" "2.46.0" "2.45.0" "2.44.0" "2.43.0" "2.42.0" "2.41.0" "2.40.0")
SUFFIXES=("ubuntu22.04" "ubuntu2204" "ubuntu20.04" "ubuntu2004")

FOUND=false
for VERSION in "${VERSIONS[@]}"; do
    for SUFFIX in "${SUFFIXES[@]}"; do
        URL="https://github.com/triton-inference-server/server/releases/download/v${VERSION}/tritonserver-${VERSION}-${SUFFIX}.tar.gz"
        echo "Checking: ${URL}"
        if curl -s --head "${URL}" | head -n 1 | grep -q "200 OK"; then
            echo "✓ Found working URL: ${URL}"
            echo "Downloading..."
            if wget -q --show-progress "${URL}"; then
                echo "✓ Download successful"
                tar -xzf "tritonserver-${VERSION}-${SUFFIX}.tar.gz"
                EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "tritonserver-*" | head -1)
                if [ -n "$EXTRACTED_DIR" ]; then
                    mv "$EXTRACTED_DIR" tritonserver
                    rm -f "tritonserver-${VERSION}-${SUFFIX}.tar.gz"
                    echo "✓ Triton installed successfully"
                    FOUND=true
                    exit 0
                fi
            fi
        fi
    done
done

if [ "$FOUND" = false ]; then
    echo "❌ No working download URLs found"
    echo ""
fi

echo ""
echo "=========================================="
echo "Option 2: Build from Source"
echo "=========================================="
echo ""
echo "If downloads fail, you can build Triton from source:"
echo ""
echo "1. Install build dependencies:"
echo "   sudo apt-get update"
echo "   sudo apt-get install -y build-essential cmake git python3-dev"
echo ""
echo "2. Clone and build:"
echo "   cd /tmp"
echo "   git clone https://github.com/triton-inference-server/server.git"
echo "   cd server"
echo "   git checkout r2.47.0  # Use stable version"
echo "   mkdir build && cd build"
echo "   cmake -DCMAKE_BUILD_TYPE=Release -DTRITON_ENABLE_PYTHON=ON .."
echo "   make -j\$(nproc)"
echo ""
echo "3. Copy to microservices directory:"
echo "   cp -r /tmp/server/build/install/tritonserver ${MICROSERVICES_DIR}/tritonserver"
echo ""
echo "⚠️  Note: Building from source can take 30-60 minutes and requires significant disk space"
echo ""

echo "=========================================="
echo "Option 3: Use Pre-built Binary from Different Source"
echo "=========================================="
echo ""
echo "Check if VastAI has Triton pre-installed:"
echo "   which tritonserver"
echo "   tritonserver --version"
echo ""

echo "=========================================="
echo "Option 4: Skip Triton for Now"
echo "=========================================="
echo ""
echo "You can test your models directly without Triton:"
echo "   cd microservices"
echo "   python test_latent_encoder.py"
echo "   python test_text_encoder.py"
echo "   # etc."
echo ""
echo "Triton is only needed for Phase 5+ (production deployment)"
echo ""

exit 1

