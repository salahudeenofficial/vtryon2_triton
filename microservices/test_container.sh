#!/bin/bash
# Test script to verify container is working properly

set -e

CONTAINER_NAME="${1:-vtryon-test}"

echo "=========================================="
echo "Testing Triton Container"
echo "=========================================="
echo ""

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "ERROR: Container $CONTAINER_NAME is not running"
    exit 1
fi

echo "✓ Container is running"
echo ""

# Wait for models to download (check every 30 seconds)
echo "Waiting for models to download..."
MAX_WAIT=1800  # 30 minutes
ELAPSED=0
INTERVAL=30

while [ $ELAPSED -lt $MAX_WAIT ]; do
    # Check if download is complete
    VAE_SIZE=$(docker exec "$CONTAINER_NAME" du -sb /models/shared_models/vae/qwen_image_vae.safetensors 2>/dev/null | cut -f1 || echo "0")
    
    if [ "$VAE_SIZE" -gt 200000000 ]; then  # > 200MB means mostly done
        # Check if Triton is running
        if docker exec "$CONTAINER_NAME" pgrep -f tritonserver > /dev/null 2>&1; then
            echo "✓ Models downloaded and Triton is running"
            break
        fi
    fi
    
    echo "  Waiting... ($ELAPSED seconds elapsed)"
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

echo ""
echo "=========================================="
echo "Testing Triton Server"
echo "=========================================="
echo ""

# Test health endpoint
echo "1. Testing health endpoint..."
for i in {1..10}; do
    if curl -s http://localhost:8000/v2/health/ready | grep -q "ready"; then
        echo "   ✓ Server is ready"
        break
    else
        if [ $i -eq 10 ]; then
            echo "   ✗ Server not ready after 10 attempts"
            echo "   Check logs: docker logs $CONTAINER_NAME"
            exit 1
        fi
        echo "   Waiting for server to be ready... (attempt $i/10)"
        sleep 10
    fi
done

echo ""

# List models
echo "2. Listing models..."
MODELS=$(curl -s http://localhost:8000/v2/models)
echo "$MODELS" | python3 -m json.tool 2>/dev/null || echo "$MODELS"
echo ""

# Check for all required models
REQUIRED_MODELS=("latent_encoder" "text_encoder" "sampling" "decoding" "vtryon_pipeline")
MISSING_MODELS=()

for model in "${REQUIRED_MODELS[@]}"; do
    if echo "$MODELS" | grep -q "\"$model\""; then
        echo "   ✓ $model is loaded"
    else
        echo "   ✗ $model is missing"
        MISSING_MODELS+=("$model")
    fi
done

echo ""

if [ ${#MISSING_MODELS[@]} -gt 0 ]; then
    echo "ERROR: Missing models: ${MISSING_MODELS[*]}"
    echo "Check logs: docker logs $CONTAINER_NAME"
    exit 1
fi

echo "=========================================="
echo "✓ All Tests Passed!"
echo "=========================================="
echo ""
echo "Container is ready for use!"
echo ""
echo "Health: http://localhost:8000/v2/health/ready"
echo "Models: http://localhost:8000/v2/models"
echo ""

