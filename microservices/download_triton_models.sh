#!/bin/bash

# Model Download Script for Triton Inference Server
# This script downloads all required models for the vtryon_pipeline ensemble
# 
# Usage:
#   1. Inside Docker container:
#      docker exec -it <container_name> /bin/bash /workspace/download_triton_models.sh
#   
#   2. Outside Docker (for volume mount):
#      ./download_triton_models.sh /path/to/models/directory
#
#   3. With custom models directory:
#      MODELS_DIR=/custom/path ./download_triton_models.sh

# Don't use set -e, we handle errors manually in download_model function
# set -e  # Exit on any error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Determine models directory
if [ -n "$1" ]; then
    # Use provided path
    MODELS_DIR="$1"
elif [ -n "$TRITON_MODEL_REPOSITORY" ]; then
    # Use MODEL_DIR if set, otherwise default to /workspace/shared_models
    MODELS_DIR="${MODEL_DIR:-/workspace/shared_models}"
elif [ -n "$MODEL_DIR" ]; then
    # Use MODEL_DIR environment variable
    MODELS_DIR="$MODEL_DIR"
else
    # Default: assume we're in the microservices directory
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )"
    MODELS_DIR="${SCRIPT_DIR}/triton_model_repository/shared_models"
fi

# Ensure MODELS_DIR is absolute
MODELS_DIR="$(cd "$(dirname "$MODELS_DIR")" && pwd)/$(basename "$MODELS_DIR")"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Triton Model Download Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Models directory: $MODELS_DIR"
echo ""

# Create necessary directories
echo "Creating model directories..."
mkdir -p "${MODELS_DIR}/vae"
mkdir -p "${MODELS_DIR}/clip"
mkdir -p "${MODELS_DIR}/diffusion_models"
mkdir -p "${MODELS_DIR}/loras"
echo -e "${GREEN}✓ Directories created${NC}"
echo ""

# Function to download with progress and error handling
download_model() {
    local url="$1"
    local output_path="$2"
    local model_name="$3"
    local file_size_mb="${4:-0}"  # Optional expected size in MB
    
    # Check if file already exists
    if [ -f "$output_path" ]; then
        local existing_size=$(stat -f%z "$output_path" 2>/dev/null || stat -c%s "$output_path" 2>/dev/null || echo "0")
        if [ "$existing_size" -gt 1000000 ]; then  # At least 1MB
            echo -e "${GREEN}✓ $model_name already exists (${existing_size} bytes), skipping...${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ $model_name exists but seems incomplete, re-downloading...${NC}"
            rm -f "$output_path"
        fi
    fi
    
    echo -e "${YELLOW}Downloading $model_name...${NC}"
    echo "  URL: $url"
    echo "  Output: $output_path"
    if [ "$file_size_mb" -gt 0 ]; then
        echo "  Expected size: ~${file_size_mb} MB"
    fi
    echo ""
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$output_path")"
    
    # Use wget if available (better progress display)
    if command -v wget >/dev/null 2>&1; then
        # Download with wget, capture exit code
        wget -c --timeout=60 --tries=3 --progress=bar:force:noscroll \
            -O "$output_path" "$url" 2>&1 || wget_exit=$?
        
        # Check if download completed (file exists and has reasonable size)
        if [ -f "$output_path" ]; then
            file_size=$(stat -f%z "$output_path" 2>/dev/null || stat -c%s "$output_path" 2>/dev/null || echo "0")
            if [ "$file_size" -gt 1000000 ]; then
                echo -e "${GREEN}✓ Successfully downloaded $model_name${NC}"
                return 0
            else
                echo -e "${YELLOW}⚠ Downloaded file seems too small (${file_size} bytes), retrying...${NC}"
                rm -f "$output_path"
            fi
        fi
        
        # If we get here, download failed
        echo -e "${RED}❌ Failed to download $model_name with wget${NC}"
        rm -f "$output_path"
        return 1
    # Fallback to curl
    elif command -v curl >/dev/null 2>&1; then
        if curl -L --retry 3 --connect-timeout 30 --max-time 3600 \
            -o "$output_path" --progress-bar "$url"; then
            # Verify file was downloaded
            if [ -f "$output_path" ] && [ "$(stat -f%z "$output_path" 2>/dev/null || stat -c%s "$output_path" 2>/dev/null || echo "0")" -gt 1000000 ]; then
                echo -e "${GREEN}✓ Successfully downloaded $model_name${NC}"
                return 0
            else
                echo -e "${RED}❌ Downloaded file seems incomplete${NC}"
                rm -f "$output_path"
                return 1
            fi
        else
            echo -e "${RED}❌ Failed to download $model_name with curl${NC}"
            rm -f "$output_path"
            return 1
        fi
    else
        echo -e "${RED}❌ Neither wget nor curl found. Please install one of them.${NC}"
        return 1
    fi
}

# Model definitions
# Format: URL | OUTPUT_PATH | MODEL_NAME | EXPECTED_SIZE_MB
declare -a MODELS=(
    "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors|${MODELS_DIR}/vae/qwen_image_vae.safetensors|Qwen VAE Model|500"
    "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors|${MODELS_DIR}/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors|Qwen CLIP Model|7000"
    "https://huggingface.co/theunlikely/Qwen-Image-Edit-2509/resolve/main/qwen_image_edit_2509_fp8_e4m3fn.safetensors|${MODELS_DIR}/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors|Qwen UNET Model|3000"
    "https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Lightning-4steps-V2.0.safetensors|${MODELS_DIR}/loras/Qwen-Image-Lightning-4steps-V2.0.safetensors|Qwen Lightning LoRA Model|100"
)

# Download all models
echo -e "${GREEN}Starting model downloads...${NC}"
echo "=========================================="
echo ""

FAILED_DOWNLOADS=0
SUCCESSFUL_DOWNLOADS=0

for model_info in "${MODELS[@]}"; do
    IFS='|' read -r url output_path model_name expected_size <<< "$model_info"
    
    # Continue even if one download fails
    if download_model "$url" "$output_path" "$model_name" "$expected_size"; then
        SUCCESSFUL_DOWNLOADS=$((SUCCESSFUL_DOWNLOADS + 1))
    else
        FAILED_DOWNLOADS=$((FAILED_DOWNLOADS + 1))
        echo -e "${RED}Failed to download: $model_name${NC}"
        echo -e "${YELLOW}Continuing with other models...${NC}"
    fi
    echo ""
done

# Summary
echo "=========================================="
echo -e "${GREEN}Download Summary${NC}"
echo "=========================================="
echo -e "${GREEN}✓ Successful: $SUCCESSFUL_DOWNLOADS${NC}"
if [ $FAILED_DOWNLOADS -gt 0 ]; then
    echo -e "${RED}✗ Failed: $FAILED_DOWNLOADS${NC}"
fi
echo ""

# Verify all required models are present
echo "Verifying downloaded models..."
echo "=========================================="

ALL_PRESENT=true
REQUIRED_MODELS=(
    "${MODELS_DIR}/vae/qwen_image_vae.safetensors"
    "${MODELS_DIR}/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors"
    "${MODELS_DIR}/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors"
    "${MODELS_DIR}/loras/Qwen-Image-Lightning-4steps-V2.0.safetensors"
)

for model_path in "${REQUIRED_MODELS[@]}"; do
    if [ -f "$model_path" ]; then
        size=$(stat -f%z "$model_path" 2>/dev/null || stat -c%s "$model_path" 2>/dev/null || echo "0")
        size_mb=$((size / 1024 / 1024))
        echo -e "${GREEN}✓ $(basename "$model_path") (${size_mb} MB)${NC}"
    else
        echo -e "${RED}✗ Missing: $(basename "$model_path")${NC}"
        ALL_PRESENT=false
    fi
done

echo ""

if [ "$ALL_PRESENT" = true ] && [ $FAILED_DOWNLOADS -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ All models downloaded successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Models are ready for use in Triton Inference Server."
    echo ""
    echo "Next steps:"
    echo "1. If running in Docker, restart the container or ensure Triton can access:"
    echo "   $MODELS_DIR"
    echo ""
    echo "2. If using volume mounts, ensure this directory is mounted:"
    echo "   docker run ... -v $MODELS_DIR:/models/shared_models ..."
    echo ""
    echo "3. Verify Triton can see the models:"
    echo "   curl http://localhost:8000/v2/models"
    echo ""
    exit 0
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}✗ Some models are missing or failed to download${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    echo "Please check the errors above and retry the download."
    echo "You can run this script again - it will skip already downloaded models."
    echo ""
    exit 1
fi


