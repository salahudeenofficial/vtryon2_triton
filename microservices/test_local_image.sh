#!/bin/bash
# Comprehensive local test script for Triton Docker image
# This script builds, runs, and verifies the image locally

set -e

IMAGE_NAME="${IMAGE_NAME:-vtryon-triton}"
CONTAINER_NAME="${CONTAINER_NAME:-vtryon-test-local}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_DIR="${MODELS_DIR:-${SCRIPT_DIR}/triton_models_persistent}"

echo "=========================================="
echo "Local Triton Image Test"
echo "=========================================="
echo ""
echo "Image: $IMAGE_NAME"
echo "Container: $CONTAINER_NAME"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check for cleanup flag
if [ "$1" = "--cleanup-models" ] || [ "$1" = "-c" ]; then
    echo "=========================================="
    echo "Cleaning up persistent models..."
    echo "=========================================="
    echo ""
    echo "Models directory: $MODELS_DIR"
    echo ""
    read -p "This will delete all downloaded models (~10.6 GB). Continue? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
        if [ -d "$MODELS_DIR" ]; then
            rm -rf "$MODELS_DIR"
            echo -e "${GREEN}✓ Models directory deleted${NC}"
        else
            echo -e "${YELLOW}⚠ Models directory not found: $MODELS_DIR${NC}"
        fi
        echo ""
        echo "To check disk space freed:"
        echo "  du -sh $MODELS_DIR"
        exit 0
    else
        echo "Cancelled."
        exit 0
    fi
fi

# Cleanup function (only stops container, keeps models)
cleanup() {
    echo ""
    echo "=========================================="
    echo "Cleaning up container..."
    echo "=========================================="
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    echo "✓ Container cleanup complete"
    echo ""
    echo "Note: Models are preserved in: $MODELS_DIR"
    echo "To delete models and free space, run:"
    echo "  $0 --cleanup-models"
}

trap cleanup EXIT

# Step 1: Build the image
echo "=========================================="
echo "Step 1: Building Docker Image"
echo "=========================================="
echo ""

cd "$SCRIPT_DIR"

if docker build -f Dockerfile.triton -t "$IMAGE_NAME" .; then
    echo -e "${GREEN}✓ Image built successfully${NC}"
else
    echo -e "${RED}✗ Image build failed${NC}"
    exit 1
fi

echo ""

# Step 2: Prepare models directory and container
echo "=========================================="
echo "Step 2: Preparing Container and Models Directory"
echo "=========================================="
echo ""

# Create models directory structure if it doesn't exist
mkdir -p "$MODELS_DIR"/{vae,clip,diffusion_models,loras}
echo "Models directory: $MODELS_DIR"
echo "  (mounted to /models/shared_models in container)"
echo ""

# Check if models already exist
if [ -d "$MODELS_DIR/vae" ] && \
   [ -d "$MODELS_DIR/clip" ] && \
   [ -d "$MODELS_DIR/diffusion_models" ] && \
   [ -d "$MODELS_DIR/loras" ]; then
    echo -e "${GREEN}✓ Models directory exists - models will persist across restarts${NC}"
    echo ""
    # Show disk usage
    if command -v du >/dev/null 2>&1; then
        echo "Current models directory size:"
        du -sh "$MODELS_DIR" 2>/dev/null || echo "  (checking...)"
    fi
else
    echo -e "${YELLOW}⚠ Models directory is new - models will be downloaded on first run${NC}"
fi
echo ""

docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true
echo "✓ Container prepared"

echo ""

# Step 3: Run the container
echo "=========================================="
echo "Step 3: Starting Container"
echo "=========================================="
echo ""

docker run -d \
    --name "$CONTAINER_NAME" \
    --gpus all \
    --shm-size=2g \
    -p 8000:8000 \
    -p 8001:8001 \
    -p 8002:8002 \
    -v "$MODELS_DIR:/workspace/shared_models" \
    "$IMAGE_NAME"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Container started${NC}"
else
    echo -e "${RED}✗ Failed to start container${NC}"
    exit 1
fi

echo ""
echo "Container logs (first 20 lines):"
docker logs --tail 20 "$CONTAINER_NAME"
echo ""

# Step 4: Monitor model downloads
echo "=========================================="
echo "Step 4: Monitoring Model Downloads"
echo "=========================================="
echo ""

MAX_WAIT=1800  # 30 minutes
ELAPSED=0
INTERVAL=10
CHECK_INTERVAL=30

REQUIRED_MODELS=(
    "/workspace/shared_models/vae/qwen_image_vae.safetensors"
    "/workspace/shared_models/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors"
    "/workspace/shared_models/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors"
    "/workspace/shared_models/loras/Qwen-Image-Lightning-4steps-V2.0.safetensors"
)

echo "Waiting for models to download..."
echo "This may take 10-20 minutes depending on your connection speed."
echo ""

while [ $ELAPSED -lt $MAX_WAIT ]; do
    ALL_DOWNLOADED=true
    
    for model_path in "${REQUIRED_MODELS[@]}"; do
        model_name=$(basename "$model_path")
        size=$(docker exec "$CONTAINER_NAME" sh -c "stat -c%s '$model_path' 2>/dev/null || echo '0'")
        
        if [ "$size" -lt 1000000 ]; then  # Less than 1MB means not downloaded
            ALL_DOWNLOADED=false
            size_mb=$((size / 1024 / 1024))
            echo -e "${YELLOW}  $model_name: ${size_mb} MB (downloading...)${NC}"
        fi
    done
    ic
    if [ "$ALL_DOWNLOADED" = true ]; then
        echo ""
        echo -e "${GREEN}✓ All models downloaded!${NC}"
        echo ""
        for model_path in "${REQUIRED_MODELS[@]}"; do
            model_name=$(basename "$model_path")
            size=$(docker exec "$CONTAINER_NAME" stat -c%s "$model_path" 2>/dev/null || echo "0")
            size_mb=$((size / 1024 / 1024))
            echo -e "${GREEN}  ✓ $model_name: ${size_mb} MB${NC}"
        done
        break
    fi
    
    if [ $((ELAPSED % CHECK_INTERVAL)) -eq 0 ]; then
        echo "  Progress check at ${ELAPSED}s..."
    fi
    
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ "$ALL_DOWNLOADED" != true ]; then
    echo -e "${RED}✗ Models did not finish downloading within timeout${NC}"
    echo "Check logs: docker logs $CONTAINER_NAME"
    exit 1
fi

echo ""

# Step 5: Wait for Triton server to start
echo "=========================================="
echo "Step 5: Waiting for Triton Server"
echo "=========================================="
echo ""

MAX_WAIT=300  # 5 minutes
ELAPSED=0
INTERVAL=5

echo "Waiting for Triton server to be ready..."
echo ""

while [ $ELAPSED -lt $MAX_WAIT ]; do
    # Check if Triton process is running
    if docker exec "$CONTAINER_NAME" pgrep -f tritonserver > /dev/null 2>&1; then
        # Check if health endpoint responds
        if curl -s -f http://localhost:8000/v2/health/ready > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Triton server is ready!${NC}"
            break
        fi
    fi
    
    if [ $((ELAPSED % 10)) -eq 0 ]; then
        echo "  Waiting... (${ELAPSED}s elapsed)"
    fi
    
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo -e "${RED}✗ Triton server did not become ready within timeout${NC}"
    echo ""
    echo "Container logs:"
    docker logs --tail 50 "$CONTAINER_NAME"
    exit 1
fi

echo ""

# Step 6: Verify all models are loaded
echo "=========================================="
echo "Step 6: Verifying Models"
echo "=========================================="
echo ""

sleep 5  # Give Triton a moment to fully initialize

# Get model list
MODELS_JSON=$(curl -s http://localhost:8000/v2/models || echo "{}")

if [ "$MODELS_JSON" = "{}" ] || [ -z "$MODELS_JSON" ]; then
    echo -e "${RED}✗ Failed to get model list${NC}"
    echo "Check logs: docker logs $CONTAINER_NAME"
    exit 1
fi

echo "Models endpoint response:"
echo "$MODELS_JSON" | python3 -m json.tool 2>/dev/null || echo "$MODELS_JSON"
echo ""

# Check for required models
REQUIRED_MODEL_NAMES=("latent_encoder" "text_encoder" "sampling" "decoding" "vtryon_pipeline")
MISSING_MODELS=()

for model in "${REQUIRED_MODEL_NAMES[@]}"; do
    if echo "$MODELS_JSON" | grep -q "\"$model\""; then
        # Check if model is ready
        READY_RESPONSE=$(curl -s http://localhost:8000/v2/models/$model/ready || echo "")
        if echo "$READY_RESPONSE" | grep -q "ready"; then
            echo -e "${GREEN}✓ $model is loaded and ready${NC}"
        else
            echo -e "${YELLOW}⚠ $model is loaded but not ready${NC}"
            MISSING_MODELS+=("$model")
        fi
    else
        echo -e "${RED}✗ $model is missing${NC}"
        MISSING_MODELS+=("$model")
    fi
done

echo ""

if [ ${#MISSING_MODELS[@]} -gt 0 ]; then
    echo -e "${RED}✗ Some models are missing or not ready: ${MISSING_MODELS[*]}${NC}"
    echo ""
    echo "Container logs (last 100 lines):"
    docker logs --tail 100 "$CONTAINER_NAME"
    exit 1
fi

# Step 7: Check for errors in logs
echo "=========================================="
echo "Step 7: Checking for Errors"
echo "=========================================="
echo ""

ERRORS=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -iE "error|exception|failed|traceback" | tail -20 || true)

if [ -n "$ERRORS" ]; then
    echo -e "${YELLOW}⚠ Found potential errors in logs:${NC}"
    echo "$ERRORS"
    echo ""
else
    echo -e "${GREEN}✓ No errors found in logs${NC}"
    echo ""
fi

# Final summary
echo "=========================================="
echo -e "${GREEN}✓ All Tests Passed!${NC}"
echo "=========================================="
echo ""
echo "Container is running and ready!"
echo ""
echo "Endpoints:"
echo "  Health: http://localhost:8000/v2/health/ready"
echo "  Models: http://localhost:8000/v2/models"
echo "  Metrics: http://localhost:8000/v2/metrics"
echo ""
echo "To view logs:"
echo "  docker logs -f $CONTAINER_NAME"
echo ""
echo "To stop container:"
echo "  docker stop $CONTAINER_NAME"
echo ""
echo "Models are persisted in:"
echo "  $MODELS_DIR"
echo ""
echo "To delete models and free space (~10.6 GB):"
echo "  $0 --cleanup-models"
echo "  # or"
echo "  rm -rf $MODELS_DIR"
echo ""
echo "To check models directory size:"
echo "  du -sh $MODELS_DIR"
echo ""

