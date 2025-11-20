#!/bin/bash
# Entrypoint script for Triton container
# Downloads models on startup if not present, then starts Triton server

set -e

echo "=========================================="
echo "Triton Inference Server Startup"
echo "=========================================="
echo ""

# Check if models are already downloaded
MODELS_DIR="${MODEL_DIR:-/models/shared_models}"
VAE_FILE="${MODELS_DIR}/vae/qwen_image_vae.safetensors"
CLIP_FILE="${MODELS_DIR}/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors"
UNET_FILE="${MODELS_DIR}/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors"
LORA_FILE="${MODELS_DIR}/loras/Qwen-Image-Lightning-4steps-V2.0.safetensors"

ALL_MODELS_PRESENT=true

if [ ! -f "$VAE_FILE" ] || [ ! -s "$VAE_FILE" ]; then
    echo "⚠ VAE model not found or empty"
    ALL_MODELS_PRESENT=false
fi

if [ ! -f "$CLIP_FILE" ] || [ ! -s "$CLIP_FILE" ]; then
    echo "⚠ CLIP model not found or empty"
    ALL_MODELS_PRESENT=false
fi

if [ ! -f "$UNET_FILE" ] || [ ! -s "$UNET_FILE" ]; then
    echo "⚠ UNET model not found or empty"
    ALL_MODELS_PRESENT=false
fi

if [ ! -f "$LORA_FILE" ] || [ ! -s "$LORA_FILE" ]; then
    echo "⚠ LoRA model not found or empty"
    ALL_MODELS_PRESENT=false
fi

# Download models if needed
if [ "$ALL_MODELS_PRESENT" = false ]; then
    echo ""
    echo "=========================================="
    echo "Downloading missing models..."
    echo "=========================================="
    echo ""
    
    # Run download script
    if [ -f "/workspace/download_triton_models.sh" ]; then
        /workspace/download_triton_models.sh
    else
        echo "ERROR: Download script not found at /workspace/download_triton_models.sh"
        exit 1
    fi
    
    echo ""
    echo "=========================================="
    echo "Model download complete"
    echo "=========================================="
    echo ""
else
    echo "✓ All models already present, skipping download"
    echo ""
fi

# Verify models are present before starting Triton
echo "Verifying models..."
if [ ! -f "$VAE_FILE" ] || [ ! -f "$CLIP_FILE" ] || [ ! -f "$UNET_FILE" ]; then
    echo "ERROR: Required models are missing after download attempt"
    echo "VAE: $([ -f "$VAE_FILE" ] && echo "OK" || echo "MISSING")"
    echo "CLIP: $([ -f "$CLIP_FILE" ] && echo "OK" || echo "MISSING")"
    echo "UNET: $([ -f "$UNET_FILE" ] && echo "OK" || echo "MISSING")"
    exit 1
fi

echo "✓ All required models verified"
echo ""

# Start Triton server
echo "=========================================="
echo "Starting Triton Inference Server..."
echo "=========================================="
echo ""

exec tritonserver \
    --model-repository=/models \
    --log-verbose=1 \
    "$@"

