#!/bin/bash
# setup_triton_vastai.sh - Setup script for Triton deployment on VastAI
# This extends setup_vastai.sh to prepare for Phases 3-8 (Triton deployment)

set -e  # Exit on any error

echo "=========================================="
echo "Triton Deployment Setup - VastAI"
echo "Phases 3-8: Complete Repository Setup"
echo "=========================================="
echo ""

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MICROSERVICES_DIR="${PROJECT_ROOT}/microservices"
TRITON_REPO="${MICROSERVICES_DIR}/triton_model_repository"

echo "Project Root: $PROJECT_ROOT"
echo "Triton Repository: $TRITON_REPO"
echo ""

# Step 1: Verify Phase 2 is complete
echo "=========================================="
echo "Step 1: Verifying Phase 2 Completion"
echo "=========================================="

if [ ! -d "${MICROSERVICES_DIR}/test_results" ]; then
    echo "⚠️  Warning: test_results directory not found"
    echo "   Make sure Phase 2 test results are available"
fi

if [ ! -f "${TRITON_REPO}/latent_encoder/config.pbtxt" ]; then
    echo "⚠️  Warning: config.pbtxt files not found"
    echo "   Generating config files..."
    cd "${MICROSERVICES_DIR}"
    python3 generate_triton_configs.py || {
        echo "❌ Failed to generate config files"
        exit 1
    }
fi

echo "✓ Phase 2 verification complete"
echo ""

# Step 2: Ensure models are downloaded
echo "=========================================="
echo "Step 2: Verifying Models"
echo "=========================================="

SHARED_MODELS="${TRITON_REPO}/shared_models"
REQUIRED_MODELS=(
    "vae/qwen_image_vae.safetensors"
    "clip/qwen_2.5_vl_7b_fp8_scaled.safetensors"
    "diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors"
    "loras/Qwen-Image-Lightning-4steps-V2.0.safetensors"
)

MISSING_MODELS=0
for model_path in "${REQUIRED_MODELS[@]}"; do
    full_path="${SHARED_MODELS}/${model_path}"
    if [ -f "$full_path" ]; then
        size=$(du -h "$full_path" | cut -f1)
        echo "✓ Found: $model_path ($size)"
    else
        echo "✗ Missing: $model_path"
        MISSING_MODELS=$((MISSING_MODELS + 1))
    fi
done

if [ $MISSING_MODELS -gt 0 ]; then
    echo ""
    echo "⚠️  Some models are missing. Run setup_vastai.sh first to download models."
    echo "   Or manually download models to: ${SHARED_MODELS}/"
    exit 1
fi

echo "✓ All models present"
echo ""

# Step 3: Verify ComfyUI
echo "=========================================="
echo "Step 3: Verifying ComfyUI"
echo "=========================================="

SHARED_COMFYUI="${TRITON_REPO}/shared_comfyui"
if [ -d "${SHARED_COMFYUI}/comfy" ]; then
    echo "✓ ComfyUI found at: ${SHARED_COMFYUI}"
else
    echo "⚠️  ComfyUI not found. Setting up..."
    
    # Copy ComfyUI from project root if available
    if [ -d "${PROJECT_ROOT}/comfy" ]; then
        mkdir -p "${SHARED_COMFYUI}"
        cp -r "${PROJECT_ROOT}/comfy" "${SHARED_COMFYUI}/"
        echo "✓ ComfyUI copied from project root"
    else
        echo "❌ ComfyUI not found. Please run setup_vastai.sh first."
        exit 1
    fi
fi
echo ""

# Step 4: Copy service code to model directories
echo "=========================================="
echo "Step 4: Copying Service Code to Model Directories"
echo "=========================================="

SERVICES=("latent_encoder" "text_encoder" "sampling" "decoding")

for service in "${SERVICES[@]}"; do
    SERVICE_DIR="${MICROSERVICES_DIR}/${service}"
    MODEL_DIR="${TRITON_REPO}/${service}/1"
    
    if [ ! -d "$SERVICE_DIR" ]; then
        echo "⚠️  Service directory not found: $SERVICE_DIR"
        continue
    fi
    
    mkdir -p "$MODEL_DIR"
    
    # Copy service files
    for file in service.py config.py utils.py errors.py; do
        if [ -f "${SERVICE_DIR}/${file}" ]; then
            cp "${SERVICE_DIR}/${file}" "${MODEL_DIR}/"
            echo "✓ Copied ${service}/${file}"
        fi
    done
    
    # Copy __init__.py if exists
    if [ -f "${SERVICE_DIR}/__init__.py" ]; then
        cp "${SERVICE_DIR}/__init__.py" "${MODEL_DIR}/"
    fi
done

echo "✓ Service code copied"
echo ""

# Step 5: Create version directories structure
echo "=========================================="
echo "Step 5: Creating Directory Structure"
echo "=========================================="

# Ensure all version directories exist
for service in "${SERVICES[@]}"; do
    mkdir -p "${TRITON_REPO}/${service}/1"
    echo "✓ Created ${service}/1/"
done

# Create templates directory
mkdir -p "${TRITON_REPO}/_templates"
echo "✓ Created _templates/"

echo "✓ Directory structure ready"
echo ""

# Step 6: Install Docker (if not installed)
echo "=========================================="
echo "Step 6: Checking Docker"
echo "=========================================="

if command -v docker >/dev/null 2>&1; then
    echo "✓ Docker is installed"
    docker --version
    
    # Check if we can access Docker daemon
    if docker ps >/dev/null 2>&1; then
        echo "✓ Docker daemon is accessible"
    else
        echo "⚠️  Warning: Cannot access Docker daemon"
        echo "   You may need to:"
        echo "   - Add user to docker group: sudo usermod -aG docker \$USER"
        echo "   - Or run with sudo (not recommended)"
        echo "   - Or if VastAI is a container, see TRITON_DOCKER_SETUP.md"
    fi
    
    # Check GPU access
    if command -v nvidia-smi >/dev/null 2>&1; then
        echo "✓ nvidia-smi available (GPU access should work)"
    else
        echo "⚠️  Warning: nvidia-smi not found - GPU access may not work"
    fi
    
    # Check if we're in a container
    if [ -f /proc/1/cgroup ] && grep -q docker /proc/1/cgroup 2>/dev/null; then
        echo "⚠️  Note: Running inside a Docker container"
        echo "   If Triton container fails, see TRITON_DOCKER_SETUP.md for Docker-in-Docker solutions"
    fi
else
    echo "⚠️  Docker not found. Installing..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    echo "✓ Docker installed"
fi
echo ""

# Step 7: Verify Triton Docker image availability
echo "=========================================="
echo "Step 7: Checking Triton Docker Image"
echo "=========================================="

if docker images | grep -q "tritonserver.*25.10-py3"; then
    echo "✓ Triton Docker image found"
else
    echo "ℹ️  Triton Docker image not found locally"
    echo "   Will be pulled when starting Triton server"
fi
echo ""

# Step 8: Create helper scripts
echo "=========================================="
echo "Step 8: Creating Helper Scripts"
echo "=========================================="

# Create start_triton.sh
cat > "${MICROSERVICES_DIR}/start_triton.sh" << 'EOF'
#!/bin/bash
# Start Triton Inference Server

cd "$(dirname "$0")"

docker run --gpus=all \
  --shm-size=1g \
  -p 8000:8000 \
  -p 8001:8001 \
  -p 8002:8002 \
  -v $(pwd)/triton_model_repository:/models \
  nvcr.io/nvidia/tritonserver:25.10-py3 \
  tritonserver --model-repository=/models \
  --log-verbose=1
EOF

chmod +x "${MICROSERVICES_DIR}/start_triton.sh"
echo "✓ Created start_triton.sh"

# Create stop_triton.sh
cat > "${MICROSERVICES_DIR}/stop_triton.sh" << 'EOF'
#!/bin/bash
# Stop Triton Inference Server

docker ps | grep tritonserver | awk '{print $1}' | xargs -r docker stop
echo "✓ Triton server stopped"
EOF

chmod +x "${MICROSERVICES_DIR}/stop_triton.sh"
echo "✓ Created stop_triton.sh"

echo ""

# Step 9: Summary
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Implement Python backend models (Phase 4):"
echo "   - Create triton_model_repository/_templates/model_template.py"
echo "   - Create triton_model_repository/*/1/model.py for each service"
echo ""
echo "2. Start Triton server:"
echo "   cd microservices"
echo "   ./start_triton.sh"
echo ""
echo "3. Test models:"
echo "   # In another terminal"
echo "   python test_triton_*.py"
echo ""
echo "=========================================="

