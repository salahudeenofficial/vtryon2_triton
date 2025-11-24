#!/bin/bash
# Monitor container status - model downloads and Triton server

CONTAINER_NAME="${1:-vtryon-test-local}"

echo "=========================================="
echo "Monitoring Container: $CONTAINER_NAME"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo -e "${RED}✗ Container $CONTAINER_NAME is not running${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Container is running${NC}"
echo ""

# Model sizes (expected)
declare -A EXPECTED_SIZES=(
    ["vae"]=253806246
    ["clip"]=9384670680
    ["diffusion_models"]=3000000000
    ["loras"]=100000000
)

# Check model download progress
echo "=========================================="
echo "Model Download Status"
echo "=========================================="
echo ""

ALL_DOWNLOADED=true
for model_dir in vae clip diffusion_models loras; do
    model_path="/models/shared_models/$model_dir"
    
    # Get the actual file in the directory
    if [ "$model_dir" = "vae" ]; then
        file_path="$model_path/qwen_image_vae.safetensors"
    elif [ "$model_dir" = "clip" ]; then
        file_path="$model_path/qwen_2.5_vl_7b_fp8_scaled.safetensors"
    elif [ "$model_dir" = "diffusion_models" ]; then
        file_path="$model_path/qwen_image_edit_2509_fp8_e4m3fn.safetensors"
    elif [ "$model_dir" = "loras" ]; then
        file_path="$model_path/Qwen-Image-Lightning-4steps-V2.0.safetensors"
    fi
    
    size=$(docker exec "$CONTAINER_NAME" sh -c "stat -c%s '$file_path' 2>/dev/null || echo '0'")
    expected_size="${EXPECTED_SIZES[$model_dir]}"
    
    if [ "$size" -gt 1000000 ]; then  # At least 1MB
        size_mb=$((size / 1024 / 1024))
        if [ "$size" -ge $((expected_size * 95 / 100)) ]; then  # 95% of expected
            echo -e "${GREEN}✓ $model_dir: ${size_mb} MB (complete)${NC}"
        else
            percent=$((size * 100 / expected_size))
            echo -e "${YELLOW}⏳ $model_dir: ${size_mb} MB (${percent}%)${NC}"
            ALL_DOWNLOADED=false
        fi
    else
        echo -e "${YELLOW}⏳ $model_dir: Downloading...${NC}"
        ALL_DOWNLOADED=false
    fi
done

echo ""

# Check Triton server status
echo "=========================================="
echo "Triton Server Status"
echo "=========================================="
echo ""

# Check if Triton process is running
if docker exec "$CONTAINER_NAME" pgrep -f tritonserver > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Triton server process is running${NC}"
    
    # Check health endpoint
    if curl -s -f http://localhost:8000/v2/health/ready > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Triton server is ready${NC}"
        
        # List models
        echo ""
        echo "Loaded Models:"
        MODELS_JSON=$(curl -s http://localhost:8000/v2/models 2>/dev/null || echo "{}")
        if [ "$MODELS_JSON" != "{}" ] && [ -n "$MODELS_JSON" ]; then
            echo "$MODELS_JSON" | python3 -m json.tool 2>/dev/null | grep -E '"name"|"version"|"state"' || echo "$MODELS_JSON"
        else
            echo -e "${YELLOW}  No models loaded yet${NC}"
        fi
    else
        echo -e "${YELLOW}⏳ Triton server is starting...${NC}"
    fi
else
    echo -e "${YELLOW}⏳ Triton server not started yet (waiting for models)${NC}"
fi

echo ""

# Summary
echo "=========================================="
if [ "$ALL_DOWNLOADED" = true ] && docker exec "$CONTAINER_NAME" pgrep -f tritonserver > /dev/null 2>&1 && curl -s -f http://localhost:8000/v2/health/ready > /dev/null 2>&1; then
    echo -e "${GREEN}✓ All models downloaded and Triton is ready!${NC}"
    echo ""
    echo "Test endpoints:"
    echo "  Health: curl http://localhost:8000/v2/health/ready"
    echo "  Models: curl http://localhost:8000/v2/models"
    exit 0
else
    echo -e "${YELLOW}⏳ Still in progress...${NC}"
    echo ""
    echo "Run this script again to check status:"
    echo "  ./monitor_container.sh"
    exit 1
fi

