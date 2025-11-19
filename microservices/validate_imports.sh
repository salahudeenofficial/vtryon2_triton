#!/bin/bash
# Script to validate imports in Triton model repository structure
# Run this after copying code to catch import errors early

set -e

TRITON_REPO="triton_model_repository"
SHARED_COMFYUI="$TRITON_REPO/shared_comfyui"

echo "=========================================="
echo "Validating Imports in Triton Structure"
echo "=========================================="

# Check if shared_comfyui exists
if [ ! -d "$SHARED_COMFYUI" ]; then
    echo "❌ Shared ComfyUI not found at $SHARED_COMFYUI"
    echo "   Run Phase 1.2 first to setup ComfyUI"
    exit 1
fi

# Test ComfyUI imports
echo ""
echo "Testing ComfyUI imports..."
cd "$SHARED_COMFYUI"
python3 -c "
import sys
sys.path.insert(0, '.')
try:
    import comfy
    print('✓ ComfyUI imports successful')
except ImportError as e:
    print(f'✗ ComfyUI import error: {e}')
    exit(1)
" || exit 1

cd - > /dev/null

# Test each service
SERVICES=("latent_encoder" "text_encoder" "sampling" "decoding")

for SERVICE in "${SERVICES[@]}"; do
    SERVICE_DIR="$TRITON_REPO/$SERVICE/1"
    
    if [ ! -d "$SERVICE_DIR" ]; then
        echo "⚠️  Service directory not found: $SERVICE_DIR"
        echo "   Skipping $SERVICE..."
        continue
    fi
    
    echo ""
    echo "Testing $SERVICE imports..."
    cd "$SERVICE_DIR"
    
    python3 -c "
import sys
import os

# Add paths (simulating Triton environment)
model_dir = os.getcwd()
comfyui_path = os.path.join(model_dir, '../../shared_comfyui')
sys.path.insert(0, comfyui_path)
sys.path.insert(0, model_dir)

# Test imports
errors = []
try:
    from config import Config
    print('  ✓ config imported')
except ImportError as e:
    errors.append(f'config: {e}')

try:
    from utils import *
    print('  ✓ utils imported')
except ImportError as e:
    errors.append(f'utils: {e}')

try:
    from errors import *
    print('  ✓ errors imported')
except ImportError as e:
    errors.append(f'errors: {e}')

try:
    from service import *
    print('  ✓ service imported')
except ImportError as e:
    errors.append(f'service: {e}')

if errors:
    print(f'✗ Import errors in $SERVICE:')
    for error in errors:
        print(f'  - {error}')
    exit(1)
else:
    print('✓ All imports successful for $SERVICE')
" || {
    echo "❌ Import validation failed for $SERVICE"
    cd - > /dev/null
    exit 1
}
    
    cd - > /dev/null
done

echo ""
echo "=========================================="
echo "✓ All imports validated successfully!"
echo "=========================================="

