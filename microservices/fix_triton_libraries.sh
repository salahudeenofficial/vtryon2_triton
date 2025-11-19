#!/bin/bash
# Fix missing Triton libraries by checking and installing DCGM if needed

set -e

echo "=========================================="
echo "Fix Triton Library Dependencies"
echo "=========================================="
echo ""

MICROSERVICES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${MICROSERVICES_DIR}"

# Check if tritonserver binary exists
if [ ! -f "./tritonserver/bin/tritonserver" ]; then
    echo "❌ Triton binary not found"
    echo "   Run extraction script first: ./extract_from_docker_skopeo.sh"
    exit 1
fi

echo "Checking for missing libraries..."
echo ""

# Check what libraries tritonserver needs
echo "Required libraries for tritonserver:"
ldd ./tritonserver/bin/tritonserver 2>/dev/null | grep "not found" || echo "  All libraries found!"
echo ""

# Check for libdcgm
if ! ldd ./tritonserver/bin/tritonserver 2>/dev/null | grep -q "libdcgm"; then
    echo "⚠️  libdcgm not found in dependencies (might be optional)"
else
    echo "Checking for libdcgm.so.4..."
    
    # Check in extracted lib directory
    if [ -f "./tritonserver/lib/libdcgm.so.4" ] || [ -f "./tritonserver/lib/libdcgm.so" ]; then
        echo "✓ Found libdcgm in extracted libraries"
    else
        echo "⚠️  libdcgm not found in extracted libraries"
        echo ""
        echo "Options:"
        echo "  1. Re-run extraction to get all libraries:"
        echo "     ./extract_from_docker_skopeo.sh"
        echo ""
        echo "  2. Install DCGM system package (if available):"
        echo "     sudo apt-get update"
        echo "     sudo apt-get install -y datacenter-gpu-manager"
        echo ""
        echo "  3. Check if DCGM is in system libraries:"
        echo "     find /usr -name '*dcgm*' 2>/dev/null"
        echo ""
        echo "  4. Try running with LD_LIBRARY_PATH set to system libs:"
        echo "     export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:\$LD_LIBRARY_PATH"
        echo "     ./start_triton_direct.sh"
    fi
fi

echo ""
echo "Current library locations:"
if [ -d "./tritonserver/lib" ]; then
    echo "  Extracted libs: ./tritonserver/lib ($(ls ./tritonserver/lib 2>/dev/null | wc -l) files)"
else
    echo "  ⚠️  No extracted lib directory found"
fi

# Check system locations
echo ""
echo "System library locations:"
for SYS_LIB in /usr/lib/x86_64-linux-gnu /usr/lib /opt/nvidia; do
    if [ -d "$SYS_LIB" ]; then
        DCGM_COUNT=$(find "$SYS_LIB" -name "*dcgm*" 2>/dev/null | wc -l)
        if [ "$DCGM_COUNT" -gt 0 ]; then
            echo "  ✓ Found DCGM in: $SYS_LIB"
            find "$SYS_LIB" -name "*dcgm*" 2>/dev/null | head -3
        fi
    fi
done

echo ""
echo "=========================================="
echo "Recommendation"
echo "=========================================="
echo ""
echo "If libraries are missing, try:"
echo "  1. Re-run extraction: ./extract_from_docker_skopeo.sh"
echo "  2. Use the updated start script: ./start_triton_direct.sh"
echo "     (It will check multiple library locations)"
echo ""

