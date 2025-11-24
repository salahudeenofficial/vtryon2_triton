#!/bin/bash
# Script to sync fixes from Vast AI container back to local code
# Usage: ./sync_fixes_from_vastai.sh <vast-ai-ip> [container-name]

set -e

VAST_AI_IP="${1:-}"
CONTAINER_NAME="${2:-vtryon-triton}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ -z "$VAST_AI_IP" ]; then
    echo -e "${RED}✗ Vast AI IP required${NC}"
    echo ""
    echo "Usage: $0 <vast-ai-ip> [container-name]"
    echo ""
    echo "Example:"
    echo "  $0 123.45.67.89"
    echo "  $0 123.45.67.89 my-container"
    exit 1
fi

echo "=========================================="
echo "Syncing Fixes from Vast AI"
echo "=========================================="
echo ""
echo "Vast AI IP: $VAST_AI_IP"
echo "Container: $CONTAINER_NAME"
echo ""

# Test SSH connection
echo "Testing SSH connection..."
if ! ssh -o ConnectTimeout=5 "root@${VAST_AI_IP}" "echo 'Connected'" > /dev/null 2>&1; then
    echo -e "${RED}✗ Cannot connect to Vast AI instance${NC}"
    echo ""
    echo "Make sure:"
    echo "1. SSH key is set up"
    echo "2. IP address is correct"
    echo "3. Instance is running"
    exit 1
fi
echo -e "${GREEN}✓ Connected${NC}"
echo ""

# Check if container exists
echo "Checking container..."
if ! ssh "root@${VAST_AI_IP}" "docker ps --format '{{.Names}}' | grep -q '^${CONTAINER_NAME}$'"; then
    echo -e "${YELLOW}⚠ Container '$CONTAINER_NAME' not found${NC}"
    echo ""
    echo "Available containers:"
    ssh "root@${VAST_AI_IP}" "docker ps --format '{{.Names}}'"
    echo ""
    read -p "Enter container name: " CONTAINER_NAME
    if [ -z "$CONTAINER_NAME" ]; then
        echo -e "${RED}✗ Container name required${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✓ Container found${NC}"
echo ""

# Models to sync
MODELS=("latent_encoder" "text_encoder" "sampling" "decoding")

echo "=========================================="
echo "Syncing Model Files"
echo "=========================================="
echo ""

SYNCED=0
FAILED=0

for model in "${MODELS[@]}"; do
    echo -e "${BLUE}Syncing $model...${NC}"
    
    MODEL_DIR="${SCRIPT_DIR}/triton_model_repository/${model}/1"
    
    # Create directory if it doesn't exist
    mkdir -p "$MODEL_DIR"
    
    # Sync model.py
    if ssh "root@${VAST_AI_IP}" "docker cp ${CONTAINER_NAME}:/models/${model}/1/model.py /tmp/${model}_model.py" 2>/dev/null; then
        if scp "root@${VAST_AI_IP}:/tmp/${model}_model.py" "${MODEL_DIR}/model.py" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓ model.py${NC}"
            SYNCED=$((SYNCED + 1))
        else
            echo -e "  ${RED}✗ Failed to copy model.py${NC}"
            FAILED=$((FAILED + 1))
        fi
        # Cleanup remote temp file
        ssh "root@${VAST_AI_IP}" "rm -f /tmp/${model}_model.py" 2>/dev/null || true
    else
        echo -e "  ${RED}✗ Failed to extract model.py from container${NC}"
        FAILED=$((FAILED + 1))
    fi
    
    # Sync service.py if exists
    if ssh "root@${VAST_AI_IP}" "docker exec ${CONTAINER_NAME} test -f /models/${model}/1/service.py" 2>/dev/null; then
        if ssh "root@${VAST_AI_IP}" "docker cp ${CONTAINER_NAME}:/models/${model}/1/service.py /tmp/${model}_service.py" 2>/dev/null; then
            if scp "root@${VAST_AI_IP}:/tmp/${model}_service.py" "${MODEL_DIR}/service.py" > /dev/null 2>&1; then
                echo -e "  ${GREEN}✓ service.py${NC}"
            else
                echo -e "  ${YELLOW}⚠ Failed to copy service.py${NC}"
            fi
            ssh "root@${VAST_AI_IP}" "rm -f /tmp/${model}_service.py" 2>/dev/null || true
        fi
    fi
    
    # Sync config.py if exists
    if ssh "root@${VAST_AI_IP}" "docker exec ${CONTAINER_NAME} test -f /models/${model}/1/config.py" 2>/dev/null; then
        if ssh "root@${VAST_AI_IP}" "docker cp ${CONTAINER_NAME}:/models/${model}/1/config.py /tmp/${model}_config.py" 2>/dev/null; then
            if scp "root@${VAST_AI_IP}:/tmp/${model}_config.py" "${MODEL_DIR}/config.py" > /dev/null 2>&1; then
                echo -e "  ${GREEN}✓ config.py${NC}"
            fi
            ssh "root@${VAST_AI_IP}" "rm -f /tmp/${model}_config.py" 2>/dev/null || true
        fi
    fi
    
    echo ""
done

echo "=========================================="
echo "Sync Summary"
echo "=========================================="
echo ""
echo -e "${GREEN}✓ Synced: $SYNCED models${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}✗ Failed: $FAILED models${NC}"
fi
echo ""

# Show changes
echo "=========================================="
echo "Changes Detected"
echo "=========================================="
echo ""

CHANGES=$(git status --short triton_model_repository/ 2>/dev/null | wc -l)
if [ "$CHANGES" -gt 0 ]; then
    git status --short triton_model_repository/
    echo ""
    echo "Review changes with:"
    echo "  git diff triton_model_repository/"
    echo ""
    read -p "Commit these changes? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git add triton_model_repository/
        read -p "Commit message: " msg
        if [ -n "$msg" ]; then
            git commit -m "$msg"
            echo -e "${GREEN}✓ Changes committed${NC}"
        else
            echo -e "${YELLOW}⚠ No commit message, changes staged but not committed${NC}"
        fi
    fi
else
    echo "No changes detected"
fi

echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "1. Review changes: git diff triton_model_repository/"
echo "2. Test locally if needed"
echo "3. Rebuild image: ./push_image.sh <registry>"
echo "4. Push to registry"
echo "5. Create new Vast AI instance with updated image"
echo ""


