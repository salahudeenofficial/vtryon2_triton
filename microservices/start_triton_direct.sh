#!/bin/bash
# Start Triton server directly (no Docker)
# Uses extracted Triton installation

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
    echo "   Run: ./install_triton_via_pytriton.sh or ./extract_from_docker_skopeo.sh"
    exit 1
fi

TRITON_REPO="./triton_model_repository"

if [ ! -d "$TRITON_REPO" ]; then
    echo "❌ Triton model repository not found: $TRITON_REPO"
    exit 1
fi

# Set up library path for Triton
# Try multiple possible library locations
TRITON_LIB_DIR="$(dirname "$(dirname "$TRITON_BIN")")/lib"
TRITON_BASE_DIR="$(dirname "$(dirname "$TRITON_BIN")")"

# Build LD_LIBRARY_PATH with all possible library locations
LIB_PATHS=""

# 1. Local tritonserver/lib
if [ -d "$TRITON_LIB_DIR" ]; then
    LIB_PATHS="${TRITON_LIB_DIR}:${LIB_PATHS}"
fi

# 2. System CUDA libraries (if available)
if [ -d "/usr/local/cuda/lib64" ]; then
    LIB_PATHS="${LIB_PATHS}/usr/local/cuda/lib64:"
fi

# 3. System libraries
if [ -d "/usr/lib/x86_64-linux-gnu" ]; then
    LIB_PATHS="${LIB_PATHS}/usr/lib/x86_64-linux-gnu:"
fi

# 4. DCGM libraries (often in /usr/lib or /opt/nvidia)
if [ -d "/usr/lib" ]; then
    LIB_PATHS="${LIB_PATHS}/usr/lib:"
fi

# 5. NVIDIA libraries
if [ -d "/opt/nvidia" ]; then
    find /opt/nvidia -type d -name "lib" 2>/dev/null | while read NVIDIA_LIB; do
        LIB_PATHS="${LIB_PATHS}${NVIDIA_LIB}:"
    done
fi

# Export LD_LIBRARY_PATH
if [ -n "$LIB_PATHS" ]; then
    export LD_LIBRARY_PATH="${LIB_PATHS}${LD_LIBRARY_PATH}"
    echo "Set LD_LIBRARY_PATH to include:"
    echo "$LIB_PATHS" | tr ':' '\n' | grep -v '^$' | sed 's/^/  - /'
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

