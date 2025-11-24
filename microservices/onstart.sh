#!/bin/bash
# Vast AI onstart.sh - Ensures models are downloaded and Triton starts
# This script is called by Vast AI when the container starts

set +e  # Don't exit on error initially

echo "=========================================="
echo "Vast AI onstart.sh - Starting VTryon Triton"
echo "=========================================="
echo ""

# Check if models are already downloaded
MODELS_DIR="${MODEL_DIR:-/workspace/shared_models}"
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
        echo "Running download script..."
        if /workspace/download_triton_models.sh; then
            echo "✓ Download script completed successfully"
        else
            echo "WARNING: Download script failed, but continuing..."
            echo "Models might already be present or will be downloaded later"
        fi
    else
        echo "ERROR: Download script not found at /workspace/download_triton_models.sh"
        echo "Continuing anyway - models might already be present"
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
    echo "WARNING: Some required models are missing:"
    echo "VAE: $([ -f "$VAE_FILE" ] && echo "OK" || echo "MISSING")"
    echo "CLIP: $([ -f "$CLIP_FILE" ] && echo "OK" || echo "MISSING")"
    echo "UNET: $([ -f "$UNET_FILE" ] && echo "OK" || echo "MISSING")"
    echo ""
    echo "Triton will start but models may not load until downloads complete."
    echo "You can manually run: /workspace/download_triton_models.sh"
    echo ""
else
    echo "✓ All required models verified"
    echo ""
fi

# Start Triton server using entrypoint script
echo "=========================================="
echo "Starting Triton Inference Server..."
echo "=========================================="
echo ""

# Re-enable exit on error for Triton server
set -e

# Execute the entrypoint script which will start Triton
exec /workspace/entrypoint.sh "$@"


