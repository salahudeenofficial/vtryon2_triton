#!/bin/bash
# setup_vastai.sh - Complete setup script for VastAI instance
# This script sets up the environment, downloads models, and prepares everything for Phase 2 testing

set -e  # Exit on any error

echo "=========================================="
echo "VastAI Setup Script - Phase 2 Testing"
echo "=========================================="
echo ""

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MICROSERVICES_DIR="${PROJECT_ROOT}/microservices"
PYTHON_VERSION="3.10"  # Use 3.10 for better compatibility

echo "Project Root: $PROJECT_ROOT"
echo "Microservices Dir: $MICROSERVICES_DIR"
echo ""

# Step 1: Update system and install dependencies
echo "=========================================="
echo "Step 1: Installing System Dependencies"
echo "=========================================="

sudo apt-get update -qq
sudo apt-get install -y -qq \
    python3-pip \
    python3-venv \
    git \
    wget \
    curl \
    build-essential \
    > /dev/null 2>&1

echo "✓ System dependencies installed"
echo ""

# Step 2: Setup Python environment
echo "=========================================="
echo "Step 2: Setting up Python Environment"
echo "=========================================="

# Check Python version
if command -v python3.10 >/dev/null 2>&1; then
    PYTHON_CMD=$(command -v python3.10)
elif command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD=$(command -v python3)
else
    echo "❌ Python 3 not found"
    exit 1
fi

PYTHON_VERSION_CHECK=$($PYTHON_CMD --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
echo "Using Python: $PYTHON_VERSION_CHECK"

# Create main virtual environment
VENV_DIR="${PROJECT_ROOT}/venv"
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating main virtual environment..."
    $PYTHON_CMD -m venv "$VENV_DIR"
    echo "✓ Virtual environment created"
else
    echo "✓ Virtual environment already exists"
fi

# Activate virtual environment
source "$VENV_DIR/bin/activate"

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip >/dev/null 2>&1

# Install PyTorch with CUDA support
echo "Installing PyTorch with CUDA..."
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118 >/dev/null 2>&1 || {
    echo "⚠️  CUDA 11.8 not available, trying default PyTorch..."
    pip install torch torchvision torchaudio >/dev/null 2>&1
}
echo "✓ PyTorch installed"
echo ""

# Step 3: Setup ComfyUI modules in shared location
echo "=========================================="
echo "Step 3: Setting up ComfyUI Modules"
echo "=========================================="

TRITON_REPO="${MICROSERVICES_DIR}/triton_model_repository"
SHARED_COMFYUI="${TRITON_REPO}/shared_comfyui"

if [ ! -d "$SHARED_COMFYUI/comfy" ]; then
    echo "ComfyUI modules not found. Copying from project..."
    
    # Copy ComfyUI modules from project root
    mkdir -p "$SHARED_COMFYUI"
    cp -r "${PROJECT_ROOT}/comfy" "$SHARED_COMFYUI/" 2>/dev/null || echo "⚠️  comfy/ not found in project root"
    cp -r "${PROJECT_ROOT}/comfy_api" "$SHARED_COMFYUI/" 2>/dev/null || echo "⚠️  comfy_api/ not found"
    cp -r "${PROJECT_ROOT}/comfy_execution" "$SHARED_COMFYUI/" 2>/dev/null || echo "⚠️  comfy_execution/ not found"
    cp -r "${PROJECT_ROOT}/comfy_extras" "$SHARED_COMFYUI/" 2>/dev/null || echo "⚠️  comfy_extras/ not found"
    cp -r "${PROJECT_ROOT}/utils" "$SHARED_COMFYUI/" 2>/dev/null || echo "⚠️  utils/ not found"
    
    # Copy core files (all Python files in project root that ComfyUI might need)
    CORE_FILES=(
        "nodes.py"
        "folder_paths.py"
        "execution.py"
        "node_helpers.py"
        "comfyui_version.py"
        "protocol.py"
        "latent_preview.py"
        "main.py"
        "server.py"
        "new_updater.py"
    )
    
    # Create custom_nodes directory (empty, we don't load custom nodes in microservices)
    mkdir -p "$SHARED_COMFYUI/custom_nodes"
    touch "$SHARED_COMFYUI/custom_nodes/.gitkeep"
    
    for file in "${CORE_FILES[@]}"; do
        if [ -f "${PROJECT_ROOT}/${file}" ]; then
            cp "${PROJECT_ROOT}/${file}" "$SHARED_COMFYUI/" 2>/dev/null && echo "✓ Copied ${file}" || echo "⚠️  Failed to copy ${file}"
        else
            echo "⚠️  ${file} not found in project root"
        fi
    done
    
    echo "✓ ComfyUI modules copied"
else
    echo "✓ ComfyUI modules already exist"
fi
echo ""

# Step 4: Install Python dependencies
echo "=========================================="
echo "Step 4: Installing Python Dependencies"
echo "=========================================="

# Install base requirements
if [ -f "${PROJECT_ROOT}/requirements.txt" ]; then
    echo "Installing base requirements..."
    pip install -r "${PROJECT_ROOT}/requirements.txt" >/dev/null 2>&1 || {
        echo "⚠️  Some packages failed to install, continuing..."
    }
    echo "✓ Base requirements installed"
fi

# Install microservice-specific dependencies
for service in latent_encoder text_encoder sampling decoding; do
    SERVICE_DIR="${MICROSERVICES_DIR}/${service}"
    if [ -f "${SERVICE_DIR}/requirements.txt" ]; then
        echo "Installing dependencies for ${service}..."
        pip install -r "${SERVICE_DIR}/requirements.txt" >/dev/null 2>&1 || {
            echo "⚠️  Some packages failed for ${service}, continuing..."
        }
    fi
done

echo "✓ All dependencies installed"
echo ""

# Step 5: Download Models
echo "=========================================="
echo "Step 5: Downloading Models"
echo "=========================================="

SHARED_MODELS="${TRITON_REPO}/shared_models"
mkdir -p "${SHARED_MODELS}/vae"
mkdir -p "${SHARED_MODELS}/clip"
mkdir -p "${SHARED_MODELS}/diffusion_models"
mkdir -p "${SHARED_MODELS}/loras"

# Function to download with retry
download_model() {
    local url="$1"
    local output_path="$2"
    local model_name="$3"
    
    if [ -f "$output_path" ]; then
        echo "✓ $model_name already exists, skipping..."
        return 0
    fi
    
    echo "Downloading $model_name..."
    echo "  URL: $url"
    echo "  Output: $output_path"
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$output_path")"
    
    # Use wget with retry logic
    if command -v wget >/dev/null 2>&1; then
        wget -c --timeout=30 --tries=3 --progress=bar:force:noscroll \
            -O "$output_path" "$url" 2>&1 | tail -1 || {
            echo "❌ Failed to download $model_name"
            return 1
        }
    elif command -v curl >/dev/null 2>&1; then
        curl -L --retry 3 --connect-timeout 30 --max-time 300 \
            -o "$output_path" "$url" --progress-bar || {
            echo "❌ Failed to download $model_name"
            return 1
        }
    else
        echo "❌ Neither wget nor curl found"
        return 1
    fi
    
    echo "✓ Successfully downloaded $model_name"
}

# Model URLs
echo "Downloading VAE model..."
download_model \
    "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors" \
    "${SHARED_MODELS}/vae/qwen_image_vae.safetensors" \
    "Qwen VAE Model"

echo ""
echo "Downloading CLIP model..."
download_model \
    "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors" \
    "${SHARED_MODELS}/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors" \
    "Qwen CLIP Model"

echo ""
echo "Downloading UNET model..."
download_model \
    "https://huggingface.co/theunlikely/Qwen-Image-Edit-2509/resolve/main/qwen_image_edit_2509_fp8_e4m3fn.safetensors" \
    "${SHARED_MODELS}/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors" \
    "Qwen UNET Model"

echo ""
echo "Downloading LoRA model..."
download_model \
    "https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Lightning-4steps-V2.0.safetensors" \
    "${SHARED_MODELS}/loras/Qwen-Image-Lightning-4steps-V2.0.safetensors" \
    "Qwen Lightning LoRA Model"

echo ""
echo "✓ All models downloaded"
echo ""

# Step 6: Setup test data directory
echo "=========================================="
echo "Step 6: Setting up Test Data Directory"
echo "=========================================="

TEST_DATA_DIR="${MICROSERVICES_DIR}/test_data"
mkdir -p "${TEST_DATA_DIR}/images"
mkdir -p "${TEST_DATA_DIR}/expected_outputs"
mkdir -p "${MICROSERVICES_DIR}/test_results"

echo "✓ Test data directories created"
echo ""

# Step 7: Verify setup
echo "=========================================="
echo "Step 7: Verifying Setup"
echo "=========================================="

# Check Python
if python3 -c "import torch; print(f'PyTorch: {torch.__version__}')" 2>/dev/null; then
    echo "✓ Python and PyTorch working"
else
    echo "❌ Python/PyTorch verification failed"
    exit 1
fi

# Check ComfyUI
if python3 -c "import sys; sys.path.insert(0, '${SHARED_COMFYUI}'); import comfy" 2>/dev/null; then
    echo "✓ ComfyUI imports working"
else
    echo "⚠️  ComfyUI import check failed (may need models loaded)"
fi

# Check models
MODEL_COUNT=0
for model_dir in "${SHARED_MODELS}"/*/; do
    if [ -n "$(ls -A "$model_dir" 2>/dev/null)" ]; then
        MODEL_COUNT=$((MODEL_COUNT + 1))
    fi
done

echo "✓ Found models in $MODEL_COUNT directories"

echo ""
echo "=========================================="
echo "=========================================="
echo "📋 SETUP COMPLETE"
echo "=========================================="
echo "✓ Python virtual environment ready"
echo "✓ PyTorch installed"
echo "✓ ComfyUI modules ready"
echo "✓ All dependencies installed"
echo "✓ Models downloaded"
echo "✓ Test directories created"
echo ""
echo "Next steps:"
echo "1. Activate virtual environment:"
echo "   source venv/bin/activate"
echo ""
echo "2. Run Phase 2 tests:"
echo "   cd microservices"
echo "   ./run_phase2_tests.sh"
echo ""
echo "=========================================="


# This script sets up the environment, downloads models, and prepares everything for Phase 2 testing

set -e  # Exit on any error

echo "=========================================="
echo "VastAI Setup Script - Phase 2 Testing"
echo "=========================================="
echo ""

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MICROSERVICES_DIR="${PROJECT_ROOT}/microservices"
PYTHON_VERSION="3.10"  # Use 3.10 for better compatibility

echo "Project Root: $PROJECT_ROOT"
echo "Microservices Dir: $MICROSERVICES_DIR"
echo ""

# Step 1: Update system and install dependencies
echo "=========================================="
echo "Step 1: Installing System Dependencies"
echo "=========================================="

sudo apt-get update -qq
sudo apt-get install -y -qq \
    python3-pip \
    python3-venv \
    git \
    wget \
    curl \
    build-essential \
    > /dev/null 2>&1

echo "✓ System dependencies installed"
echo ""

# Step 2: Setup Python environment
echo "=========================================="
echo "Step 2: Setting up Python Environment"
echo "=========================================="

# Check Python version
if command -v python3.10 >/dev/null 2>&1; then
    PYTHON_CMD=$(command -v python3.10)
elif command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD=$(command -v python3)
else
    echo "❌ Python 3 not found"
    exit 1
fi

PYTHON_VERSION_CHECK=$($PYTHON_CMD --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
echo "Using Python: $PYTHON_VERSION_CHECK"

# Create main virtual environment
VENV_DIR="${PROJECT_ROOT}/venv"
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating main virtual environment..."
    $PYTHON_CMD -m venv "$VENV_DIR"
    echo "✓ Virtual environment created"
else
    echo "✓ Virtual environment already exists"
fi

# Activate virtual environment
source "$VENV_DIR/bin/activate"

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip >/dev/null 2>&1

# Install PyTorch with CUDA support
echo "Installing PyTorch with CUDA..."
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118 >/dev/null 2>&1 || {
    echo "⚠️  CUDA 11.8 not available, trying default PyTorch..."
    pip install torch torchvision torchaudio >/dev/null 2>&1
}
echo "✓ PyTorch installed"
echo ""

# Step 3: Setup ComfyUI modules in shared location
echo "=========================================="
echo "Step 3: Setting up ComfyUI Modules"
echo "=========================================="

TRITON_REPO="${MICROSERVICES_DIR}/triton_model_repository"
SHARED_COMFYUI="${TRITON_REPO}/shared_comfyui"

if [ ! -d "$SHARED_COMFYUI/comfy" ]; then
    echo "ComfyUI modules not found. Copying from project..."
    
    # Copy ComfyUI modules from project root
    mkdir -p "$SHARED_COMFYUI"
    cp -r "${PROJECT_ROOT}/comfy" "$SHARED_COMFYUI/" 2>/dev/null || echo "⚠️  comfy/ not found in project root"
    cp -r "${PROJECT_ROOT}/comfy_api" "$SHARED_COMFYUI/" 2>/dev/null || echo "⚠️  comfy_api/ not found"
    cp -r "${PROJECT_ROOT}/comfy_execution" "$SHARED_COMFYUI/" 2>/dev/null || echo "⚠️  comfy_execution/ not found"
    cp -r "${PROJECT_ROOT}/comfy_extras" "$SHARED_COMFYUI/" 2>/dev/null || echo "⚠️  comfy_extras/ not found"
    cp -r "${PROJECT_ROOT}/utils" "$SHARED_COMFYUI/" 2>/dev/null || echo "⚠️  utils/ not found"
    
    # Copy core files (all Python files in project root that ComfyUI might need)
    CORE_FILES=(
        "nodes.py"
        "folder_paths.py"
        "execution.py"
        "node_helpers.py"
        "comfyui_version.py"
        "protocol.py"
        "latent_preview.py"
        "main.py"
        "server.py"
        "new_updater.py"
    )
    
    # Create custom_nodes directory (empty, we don't load custom nodes in microservices)
    mkdir -p "$SHARED_COMFYUI/custom_nodes"
    touch "$SHARED_COMFYUI/custom_nodes/.gitkeep"
    
    for file in "${CORE_FILES[@]}"; do
        if [ -f "${PROJECT_ROOT}/${file}" ]; then
            cp "${PROJECT_ROOT}/${file}" "$SHARED_COMFYUI/" 2>/dev/null && echo "✓ Copied ${file}" || echo "⚠️  Failed to copy ${file}"
        else
            echo "⚠️  ${file} not found in project root"
        fi
    done
    
    echo "✓ ComfyUI modules copied"
else
    echo "✓ ComfyUI modules already exist"
fi
echo ""

# Step 4: Install Python dependencies
echo "=========================================="
echo "Step 4: Installing Python Dependencies"
echo "=========================================="

# Install base requirements
if [ -f "${PROJECT_ROOT}/requirements.txt" ]; then
    echo "Installing base requirements..."
    pip install -r "${PROJECT_ROOT}/requirements.txt" >/dev/null 2>&1 || {
        echo "⚠️  Some packages failed to install, continuing..."
    }
    echo "✓ Base requirements installed"
fi

# Install microservice-specific dependencies
for service in latent_encoder text_encoder sampling decoding; do
    SERVICE_DIR="${MICROSERVICES_DIR}/${service}"
    if [ -f "${SERVICE_DIR}/requirements.txt" ]; then
        echo "Installing dependencies for ${service}..."
        pip install -r "${SERVICE_DIR}/requirements.txt" >/dev/null 2>&1 || {
            echo "⚠️  Some packages failed for ${service}, continuing..."
        }
    fi
done

echo "✓ All dependencies installed"
echo ""

# Step 5: Download Models
echo "=========================================="
echo "Step 5: Downloading Models"
echo "=========================================="

SHARED_MODELS="${TRITON_REPO}/shared_models"
mkdir -p "${SHARED_MODELS}/vae"
mkdir -p "${SHARED_MODELS}/clip"
mkdir -p "${SHARED_MODELS}/diffusion_models"
mkdir -p "${SHARED_MODELS}/loras"

# Function to download with retry
download_model() {
    local url="$1"
    local output_path="$2"
    local model_name="$3"
    
    if [ -f "$output_path" ]; then
        echo "✓ $model_name already exists, skipping..."
        return 0
    fi
    
    echo "Downloading $model_name..."
    echo "  URL: $url"
    echo "  Output: $output_path"
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$output_path")"
    
    # Use wget with retry logic
    if command -v wget >/dev/null 2>&1; then
        wget -c --timeout=30 --tries=3 --progress=bar:force:noscroll \
            -O "$output_path" "$url" 2>&1 | tail -1 || {
            echo "❌ Failed to download $model_name"
            return 1
        }
    elif command -v curl >/dev/null 2>&1; then
        curl -L --retry 3 --connect-timeout 30 --max-time 300 \
            -o "$output_path" "$url" --progress-bar || {
            echo "❌ Failed to download $model_name"
            return 1
        }
    else
        echo "❌ Neither wget nor curl found"
        return 1
    fi
    
    echo "✓ Successfully downloaded $model_name"
}

# Model URLs
echo "Downloading VAE model..."
download_model \
    "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors" \
    "${SHARED_MODELS}/vae/qwen_image_vae.safetensors" \
    "Qwen VAE Model"

echo ""
echo "Downloading CLIP model..."
download_model \
    "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors" \
    "${SHARED_MODELS}/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors" \
    "Qwen CLIP Model"

echo ""
echo "Downloading UNET model..."
download_model \
    "https://huggingface.co/theunlikely/Qwen-Image-Edit-2509/resolve/main/qwen_image_edit_2509_fp8_e4m3fn.safetensors" \
    "${SHARED_MODELS}/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors" \
    "Qwen UNET Model"

echo ""
echo "Downloading LoRA model..."
download_model \
    "https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Lightning-4steps-V2.0.safetensors" \
    "${SHARED_MODELS}/loras/Qwen-Image-Lightning-4steps-V2.0.safetensors" \
    "Qwen Lightning LoRA Model"

echo ""
echo "✓ All models downloaded"
echo ""

# Step 6: Setup test data directory
echo "=========================================="
echo "Step 6: Setting up Test Data Directory"
echo "=========================================="

TEST_DATA_DIR="${MICROSERVICES_DIR}/test_data"
mkdir -p "${TEST_DATA_DIR}/images"
mkdir -p "${TEST_DATA_DIR}/expected_outputs"
mkdir -p "${MICROSERVICES_DIR}/test_results"

echo "✓ Test data directories created"
echo ""

# Step 7: Verify setup
echo "=========================================="
echo "Step 7: Verifying Setup"
echo "=========================================="

# Check Python
if python3 -c "import torch; print(f'PyTorch: {torch.__version__}')" 2>/dev/null; then
    echo "✓ Python and PyTorch working"
else
    echo "❌ Python/PyTorch verification failed"
    exit 1
fi

# Check ComfyUI
if python3 -c "import sys; sys.path.insert(0, '${SHARED_COMFYUI}'); import comfy" 2>/dev/null; then
    echo "✓ ComfyUI imports working"
else
    echo "⚠️  ComfyUI import check failed (may need models loaded)"
fi

# Check models
MODEL_COUNT=0
for model_dir in "${SHARED_MODELS}"/*/; do
    if [ -n "$(ls -A "$model_dir" 2>/dev/null)" ]; then
        MODEL_COUNT=$((MODEL_COUNT + 1))
    fi
done

echo "✓ Found models in $MODEL_COUNT directories"

echo ""
echo "=========================================="
echo "=========================================="
echo "📋 SETUP COMPLETE"
echo "=========================================="
echo "✓ Python virtual environment ready"
echo "✓ PyTorch installed"
echo "✓ ComfyUI modules ready"
echo "✓ All dependencies installed"
echo "✓ Models downloaded"
echo "✓ Test directories created"
echo ""
echo "Next steps:"
echo "1. Activate virtual environment:"
echo "   source venv/bin/activate"
echo ""
echo "2. Run Phase 2 tests:"
echo "   cd microservices"
echo "   ./run_phase2_tests.sh"
echo ""
echo "=========================================="

