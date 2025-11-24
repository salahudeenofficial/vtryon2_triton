#!/bin/bash
# Helper script for debugging Triton models on Vast AI
# Usage: ./debug_helper.sh [model_name] [action]

set -e

CONTAINER_NAME="${CONTAINER_NAME:-vtryon-test-local}"
MODEL_NAME="${1:-latent_encoder}"
ACTION="${2:-copy}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_DIR="${SCRIPT_DIR}/triton_model_repository/${MODEL_NAME}/1"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

case "$ACTION" in
    copy)
        echo "=== Copying $MODEL_NAME from container ==="
        
        # Check container exists
        if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            echo -e "${RED}✗ Container $CONTAINER_NAME not running${NC}"
            exit 1
        fi
        
        # Copy model.py
        echo "Copying model.py..."
        docker cp "${CONTAINER_NAME}:/models/${MODEL_NAME}/1/model.py" \
            "${MODEL_DIR}/model.py" 2>/dev/null || {
            echo -e "${RED}✗ Failed to copy model.py${NC}"
            exit 1
        }
        
        # Copy service.py if exists
        if docker exec "${CONTAINER_NAME}" test -f "/models/${MODEL_NAME}/1/service.py" 2>/dev/null; then
            echo "Copying service.py..."
            docker cp "${CONTAINER_NAME}:/models/${MODEL_NAME}/1/service.py" \
                "${MODEL_DIR}/service.py" 2>/dev/null || echo -e "${YELLOW}⚠ Failed to copy service.py${NC}"
        fi
        
        echo -e "${GREEN}✓ Files copied${NC}"
        
        # Show diff
        if git diff --quiet "${MODEL_DIR}/model.py" 2>/dev/null; then
            echo "No changes detected"
        else
            echo ""
            echo "=== Changes detected ==="
            git diff "${MODEL_DIR}/model.py" | head -50
        fi
        ;;
        
    test)
        echo "=== Testing $MODEL_NAME in container ==="
        
        # Test imports
        echo "Testing imports..."
        docker exec "${CONTAINER_NAME}" python3 -c "
import sys
sys.path.insert(0, '/workspace/shared_comfyui')
sys.path.insert(0, '/models/${MODEL_NAME}/1')
try:
    from service import *
    print('✓ Imports successful')
except Exception as e:
    print(f'✗ Import error: {e}')
    import traceback
    traceback.print_exc()
" 2>&1
        ;;
        
    logs)
        echo "=== Recent logs for $MODEL_NAME ==="
        docker logs "${CONTAINER_NAME}" 2>&1 | grep -i "${MODEL_NAME}" | tail -20
        ;;
        
    status)
        echo "=== Status check ==="
        echo "Container: $CONTAINER_NAME"
        echo "Model: $MODEL_NAME"
        echo ""
        
        # Container status
        if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            echo -e "${GREEN}✓ Container running${NC}"
        else
            echo -e "${RED}✗ Container not running${NC}"
            exit 1
        fi
        
        # Model ready status
        echo ""
        echo "Model ready status:"
        curl -s "http://localhost:8000/v2/models/${MODEL_NAME}/ready" 2>/dev/null | python3 -m json.tool 2>/dev/null || \
            echo "Could not check model status"
        ;;
        
    sync)
        echo "=== Syncing all changes from container ==="
        
        for model in latent_encoder text_encoder sampling decoding; do
            echo "Syncing $model..."
            "$0" "$model" copy
        done
        
        echo ""
        echo "=== Summary ==="
        git status --short triton_model_repository/ | head -20
        ;;
        
    *)
        echo "Usage: $0 [model_name] [action]"
        echo ""
        echo "Actions:"
        echo "  copy   - Copy files from container to local (default)"
        echo "  test   - Test imports in container"
        echo "  logs   - Show recent logs for model"
        echo "  status - Check container and model status"
        echo "  sync   - Sync all models from container"
        echo ""
        echo "Examples:"
        echo "  $0 latent_encoder copy"
        echo "  $0 text_encoder test"
        echo "  $0 sync"
        exit 1
        ;;
esac


