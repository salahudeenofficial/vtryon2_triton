# Docker Image Deployment Plan for VastAI

## Overview
Build a self-contained Docker image with Triton Inference Server, ComfyUI, microservices, and ensemble configuration. On first run, the image downloads models and starts Triton automatically.

---

## Phase 1: Docker Image Structure

### 1.1 Base Image Selection
**Recommended**: `nvcr.io/nvidia/tritonserver:25.10-py3`
- ✅ Includes Triton Inference Server
- ✅ CUDA runtime included
- ✅ Python backend support
- ✅ GPU-ready
- ✅ No need to install Triton separately

**Alternative**: `nvidia/cuda:12.1.0-runtime-ubuntu22.04` + install Triton
- More control but more setup

### 1.2 Image Layers Strategy
```
Layer 1: Base (Triton image)
Layer 2: System dependencies (git, wget, curl, etc.)
Layer 3: Python dependencies (requirements.txt)
Layer 4: ComfyUI code (shared_comfyui/)
Layer 5: Microservice code (triton_model_repository/)
Layer 6: Entrypoint script (downloads models + starts Triton)
```

### 1.3 Directory Structure in Image
```
/workspace/
├── triton_model_repository/          # Triton model repo
│   ├── latent_encoder/
│   ├── text_encoder/
│   ├── sampling/
│   ├── decoding/
│   ├── vtryon_pipeline/              # Ensemble
│   ├── shared_comfyui/               # ComfyUI code
│   └── shared_models/                 # Models (downloaded on first run)
│       ├── vae/
│       ├── clip/
│       ├── diffusion_models/
│       └── loras/
├── scripts/
│   ├── download_models.sh             # Model download script
│   ├── start_triton.sh                # Start Triton server
│   └── health_check.sh                # Health check
└── requirements.txt                   # Python dependencies
```

---

## Phase 2: Dockerfile Design

### 2.1 Dockerfile Structure
```dockerfile
FROM nvcr.io/nvidia/tritonserver:25.10-py3

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /workspace

# Copy Python requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy ComfyUI
COPY microservices/triton_model_repository/shared_comfyui /workspace/triton_model_repository/shared_comfyui

# Copy Triton model repository (without models)
COPY microservices/triton_model_repository /workspace/triton_model_repository
# Note: shared_models/ will be created by download script

# Copy scripts
COPY microservices/docker/scripts /workspace/scripts
RUN chmod +x /workspace/scripts/*.sh

# Set environment variables
ENV PYTHONPATH=/workspace/triton_model_repository/shared_comfyui:$PYTHONPATH
ENV COMFYUI_PATH=/workspace/triton_model_repository/shared_comfyui
ENV MODEL_DIR=/workspace/triton_model_repository/shared_models
ENV TRITON_MODEL_REPOSITORY=/workspace/triton_model_repository

# Expose Triton ports
EXPOSE 8000 8001 8002

# Entrypoint: Download models if needed, then start Triton
ENTRYPOINT ["/workspace/scripts/entrypoint.sh"]
```

### 2.2 Key Considerations
- **No models in image**: Keep image size small (~5-10GB vs 50GB+)
- **Download on first run**: Models downloaded to `/workspace/triton_model_repository/shared_models/`
- **Persistent storage**: VastAI mounts `/workspace`, so models persist
- **Health check**: Script to verify Triton is running

---

## Phase 3: Entrypoint Script

### 3.1 Entrypoint Logic
```bash
#!/bin/bash
# /workspace/scripts/entrypoint.sh

set -e

MODELS_DIR="/workspace/triton_model_repository/shared_models"
TRITON_REPO="/workspace/triton_model_repository"

# Check if models exist
if [ ! -d "$MODELS_DIR" ] || [ -z "$(ls -A $MODELS_DIR/*/ 2>/dev/null)" ]; then
    echo "=========================================="
    echo "First Run: Downloading Models"
    echo "=========================================="
    /workspace/scripts/download_models.sh
    echo "✓ Models downloaded"
else
    echo "✓ Models already exist, skipping download"
fi

# Verify Triton model repository structure
echo "Verifying Triton model repository..."
if [ ! -d "$TRITON_REPO" ]; then
    echo "❌ Triton model repository not found"
    exit 1
fi

# Start Triton server
echo "=========================================="
echo "Starting Triton Inference Server"
echo "=========================================="
exec /opt/tritonserver/bin/tritonserver \
    --model-repository="$TRITON_REPO" \
    --log-verbose=1 \
    --strict-model-config=false \
    --http-port=8000 \
    --grpc-port=8001 \
    --metrics-port=8002
```

### 3.2 Model Download Script
```bash
#!/bin/bash
# /workspace/scripts/download_models.sh

MODELS_DIR="/workspace/triton_model_repository/shared_models"

# Create directories
mkdir -p "$MODELS_DIR"/{vae,clip,diffusion_models,loras}

# Model URLs (from download.sh)
declare -A MODELS=(
    ["qwen_image_edit_fp8_e4m3fn.safetensors"]="https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_fp8_e4m3fn.safetensors"
    ["qwen_2.5_vl_7b_fp8_scaled.safetensors"]="https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors"
    ["qwen_image_vae.safetensors"]="https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors"
    # ... more models
)

# Download function
download_model() {
    local url="$1"
    local output="$2"
    local name="$3"
    
    if [ -f "$output" ]; then
        echo "  ✓ $name already exists"
        return
    fi
    
    echo "  Downloading $name..."
    wget -q --show-progress -O "$output" "$url" || {
        echo "  ❌ Failed to download $name"
        return 1
    }
}

# Download all models
echo "Downloading models to $MODELS_DIR..."
download_model "${MODELS[qwen_image_vae.safetensors]}" "$MODELS_DIR/vae/qwen_image_vae.safetensors" "Qwen VAE"
download_model "${MODELS[qwen_2.5_vl_7b_fp8_scaled.safetensors]}" "$MODELS_DIR/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors" "Qwen CLIP"
# ... download all models

echo "✓ All models downloaded"
```

---

## Phase 4: Build Process

### 4.1 Local Build Steps
```bash
# 1. Create docker directory structure
mkdir -p microservices/docker/scripts

# 2. Create Dockerfile
# 3. Create entrypoint.sh
# 4. Create download_models.sh
# 5. Create .dockerignore

# 6. Build image
docker build -t vtryon-triton:latest -f microservices/docker/Dockerfile .

# 7. Test locally
docker run --gpus all -p 8000:8000 -p 8001:8001 vtryon-triton:latest

# 8. Verify Triton is running
curl http://localhost:8000/v2/models
```

### 4.2 .dockerignore
```
# Exclude large files from build context
*.pt
*.safetensors
*.ckpt
*.pth
models/
test_outputs/
__pycache__/
*.pyc
.git/
.gitignore
```

---

## Phase 5: Push to Registry

### 5.1 Docker Hub Push
```bash
# Tag for Docker Hub
docker tag vtryon-triton:latest yourusername/vtryon-triton:latest

# Login
docker login

# Push
docker push yourusername/vtryon-triton:latest
```

### 5.2 Alternative Registries
- **GitHub Container Registry**: `ghcr.io/username/vtryon-triton:latest`
- **Private registry**: Your own registry URL

---

## Phase 6: VastAI Deployment

### 6.1 VastAI Instance Configuration

**When creating instance:**
1. **Select**: "Run custom Docker image"
2. **Image**: `yourusername/vtryon-triton:latest`
3. **Startup command**: `/bin/bash` (or leave empty, entrypoint handles it)
4. **Enable**: SSH ✅
5. **Ports**: 
   - 8000 (HTTP)
   - 8001 (gRPC)
   - 8002 (Metrics)
6. **Storage**: Mount to `/workspace` (default)
7. **GPU**: RTX 4090 / A6000 (24GB+ VRAM recommended)

### 6.2 First Run Behavior
1. Container starts
2. Entrypoint script runs
3. Checks for models in `/workspace/triton_model_repository/shared_models/`
4. If missing, downloads all models (takes 10-30 minutes)
5. Starts Triton server
6. Models persist in `/workspace` (VastAI volume)

### 6.3 Subsequent Runs
- Models already exist → Skip download → Start Triton immediately
- Fast startup (~30 seconds)

---

## Phase 7: Verification & Testing

### 7.1 Health Checks
```bash
# Check Triton is running
curl http://localhost:8000/v2/health/ready

# List models
curl http://localhost:8000/v2/models

# Check ensemble model
curl http://localhost:8000/v2/models/vtryon_pipeline
```

### 7.2 Test Inference
```python
import tritonclient.http as httpclient

client = httpclient.InferenceServerClient("localhost:8000")

# Test ensemble model
inputs = [
    httpclient.InferInput("image1", [1], "BYTES"),
    httpclient.InferInput("image2", [1], "BYTES"),
    httpclient.InferInput("prompt", [1], "BYTES"),
]
# ... set input data
result = client.infer("vtryon_pipeline", inputs)
```

---

## Phase 8: Optimization

### 8.1 Image Size Optimization
- Use multi-stage builds
- Remove build dependencies
- Use `.dockerignore` effectively
- Compress ComfyUI if possible

### 8.2 Model Download Optimization
- Parallel downloads
- Resume support
- Checksum verification
- Progress indicators

### 8.3 Startup Time Optimization
- Pre-warm models (optional)
- Lazy loading
- Model caching

---

## Implementation Checklist

### Docker Setup
- [ ] Create `microservices/docker/` directory
- [ ] Create `Dockerfile`
- [ ] Create `entrypoint.sh`
- [ ] Create `download_models.sh`
- [ ] Create `.dockerignore`
- [ ] Create `requirements.txt` (consolidated)

### Build & Test
- [ ] Build image locally
- [ ] Test model download
- [ ] Test Triton startup
- [ ] Verify ensemble model loads
- [ ] Test inference endpoint

### Registry
- [ ] Create Docker Hub account (or use existing)
- [ ] Tag image
- [ ] Push to registry
- [ ] Verify image is accessible

### VastAI Deployment
- [ ] Create VastAI instance with custom image
- [ ] Verify first-run model download
- [ ] Test Triton endpoints
- [ ] Test ensemble inference
- [ ] Document deployment process

---

## File Structure Summary

```
microservices/
├── docker/
│   ├── Dockerfile
│   ├── .dockerignore
│   └── scripts/
│       ├── entrypoint.sh
│       ├── download_models.sh
│       └── health_check.sh
├── triton_model_repository/          # Already exists
│   ├── latent_encoder/
│   ├── text_encoder/
│   ├── sampling/
│   ├── decoding/
│   ├── vtryon_pipeline/
│   └── shared_comfyui/
└── requirements.txt                   # Consolidated Python deps
```

---

## Next Steps

1. **Review this plan** - Confirm approach and make adjustments
2. **Create Docker files** - Implement Dockerfile and scripts
3. **Test locally** - Build and test on local machine with GPU
4. **Push to registry** - Upload to Docker Hub
5. **Deploy on VastAI** - Create instance and verify

---

## Questions to Resolve

1. **Model storage**: Download on first run (recommended) vs include in image?
2. **Base image**: Use Triton image directly or CUDA base + install Triton?
3. **ComfyUI source**: Copy from repo or git clone during build?
4. **Requirements**: Consolidate all Python dependencies into one file?
5. **Registry**: Docker Hub, GitHub Container Registry, or private?

