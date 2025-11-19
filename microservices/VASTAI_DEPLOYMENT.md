# VastAI Deployment Guide - Complete Docker Image

## Overview

This guide shows how to:
1. Build a Docker image with Triton + all code
2. Push to DockerHub
3. Deploy on VastAI using the image

---

## Step 1: Build Docker Image

### On Your Local Machine or VastAI Instance

```bash
cd /path/to/vtryon2_triton/microservices

# Set your DockerHub username
export DOCKERHUB_USER=your-dockerhub-username

# Build the image
chmod +x build_triton_image.sh
./build_triton_image.sh
```

Or manually:

```bash
docker build -f Dockerfile.triton -t vtryon-triton:latest .
docker tag vtryon-triton:latest your-username/vtryon-triton:latest
```

---

## Step 2: Test Image Locally (Optional)

```bash
# Test the image (models need to be downloaded/mounted)
docker run --gpus all \
  -p 8000:8000 \
  -p 8001:8001 \
  -p 8002:8002 \
  -v $(pwd)/triton_model_repository/shared_models:/models/shared_models \
  vtryon-triton:latest
```

---

## Step 3: Push to DockerHub

```bash
# Login to DockerHub
docker login

# Push image
docker push your-username/vtryon-triton:latest
```

---

## Step 4: Deploy on VastAI

### Option A: Using VastAI Web Interface

1. **Create New Instance**:
   - Go to https://vast.ai
   - Click "Create" or "Rent"
   - Select GPU instance (RTX 3090/4090 or A100 with 24GB+ VRAM)

2. **Configure Container**:
   - **Docker Image**: `your-username/vtryon-triton:latest`
   - **Ports**: 
     - `8000:8000` (HTTP)
     - `8001:8001` (gRPC)
     - `8002:8002` (Metrics)
   - **Environment Variables** (optional):
     - `TRITON_MODEL_REPOSITORY=/models`
   - **Volume Mounts** (for models):
     - Host path: `/workspace/models` (or wherever you store models)
     - Container path: `/models/shared_models`
     - Mode: `rw` (read-write)

3. **Start Instance**

### Option B: Using VastAI API/SSH

If you SSH into the instance:

```bash
# Pull your image
docker pull your-username/vtryon-triton:latest

# Run container
docker run -d \
  --name triton-server \
  --gpus all \
  --shm-size=2g \
  -p 8000:8000 \
  -p 8001:8001 \
  -p 8002:8002 \
  -v /workspace/models:/models/shared_models \
  your-username/vtryon-triton:latest
```

---

## Step 5: Download Models (If Not Included)

Models are **not included** in the Docker image (to keep size small). Download them at runtime:

### Option A: Download Script Inside Container

```bash
# SSH into VastAI instance
# Enter the running container
docker exec -it triton-server bash

# Download models (use your existing setup_vastai.sh logic)
cd /models
# Run model download script
```

### Option B: Volume Mount from Host

Mount models from VastAI host:

```bash
# On VastAI host, download models first
cd /workspace
git clone https://github.com/salahudeenofficial/vtryon2_triton.git
cd vtryon2_triton/microservices
./setup_vastai.sh  # Downloads models

# Then mount in Docker
docker run ... \
  -v /workspace/vtryon2_triton/microservices/triton_model_repository/shared_models:/models/shared_models \
  your-username/vtryon-triton:latest
```

### Option C: Include Models in Image (Large Image)

If you want models in the image, modify `Dockerfile.triton`:

```dockerfile
# Add model download step
RUN cd /models && \
    wget <model-url-1> -O shared_models/vae/model.safetensors && \
    wget <model-url-2> -O shared_models/clip/model.safetensors && \
    # ... etc
```

**Warning**: This will make the image very large (10GB+).

---

## Step 6: Verify Deployment

### Check Server Status

```bash
# From VastAI host or your local machine
curl http://<vastai-ip>:8000/v2/health/ready

# Should return: {"status":"ready"}
```

### List Models

```bash
curl http://<vastai-ip>:8000/v2/models
```

### Test Inference

```bash
# Test ensemble model
curl -X POST http://<vastai-ip>:8000/v2/models/vtryon_pipeline/infer \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": [
      {
        "name": "image1_path",
        "shape": [1],
        "datatype": "BYTES",
        "data": ["/path/to/image1.jpg"]
      },
      {
        "name": "image2_path",
        "shape": [1],
        "datatype": "BYTES",
        "data": ["/path/to/image2.jpg"]
      },
      {
        "name": "prompt",
        "shape": [1],
        "datatype": "BYTES",
        "data": ["a photo of a person"]
      }
    ]
  }'
```

---

## VastAI Configuration Template

### Docker Run Command for VastAI

```bash
docker run -d \
  --name vtryon-triton \
  --gpus all \
  --shm-size=4g \
  --restart unless-stopped \
  -p 8000:8000 \
  -p 8001:8001 \
  -p 8002:8002 \
  -v /workspace/models:/models/shared_models:ro \
  -v /workspace/comfyui:/models/shared_comfyui:ro \
  your-username/vtryon-triton:latest \
  tritonserver \
    --model-repository=/models \
    --log-verbose=1 \
    --strict-model-config=false
```

### Environment Variables

- `TRITON_MODEL_REPOSITORY=/models` (default)
- `CUDA_VISIBLE_DEVICES=0` (if you want to specify GPU)

---

## Troubleshooting

### Issue: Models Not Found

**Solution**: Ensure models are mounted or downloaded:
```bash
# Check if models exist in container
docker exec triton-server ls -la /models/shared_models/
```

### Issue: ComfyUI Import Errors

**Solution**: Verify ComfyUI is in the image:
```bash
docker exec triton-server ls -la /models/shared_comfyui/comfy/
```

### Issue: GPU Not Available

**Solution**: Check GPU access:
```bash
docker exec triton-server nvidia-smi
```

### Issue: Port Not Accessible

**Solution**: Check VastAI firewall/port settings:
- Ensure ports 8000, 8001, 8002 are open
- Check VastAI instance port mapping

---

## Complete Deployment Script

Create `deploy_vastai.sh`:

```bash
#!/bin/bash
# Complete deployment script for VastAI

IMAGE_NAME="your-username/vtryon-triton:latest"

# Pull image
docker pull $IMAGE_NAME

# Stop existing container
docker stop vtryon-triton 2>/dev/null || true
docker rm vtryon-triton 2>/dev/null || true

# Run new container
docker run -d \
  --name vtryon-triton \
  --gpus all \
  --shm-size=4g \
  --restart unless-stopped \
  -p 8000:8000 \
  -p 8001:8001 \
  -p 8002:8002 \
  -v $(pwd)/triton_model_repository/shared_models:/models/shared_models:ro \
  $IMAGE_NAME

# Wait for server to start
sleep 10

# Check status
curl http://localhost:8000/v2/health/ready
```

---

## Next Steps

1. ✅ Build image
2. ✅ Push to DockerHub
3. ✅ Deploy on VastAI
4. ✅ Download models (if not in image)
5. ✅ Test ensemble model
6. ✅ Monitor performance

---

## Image Size Optimization

To reduce image size:

1. **Multi-stage build**: Build in one stage, copy only needed files
2. **Exclude models**: Download at runtime (current approach)
3. **Remove build tools**: Clean apt cache, remove git/wget after use
4. **Compress ComfyUI**: Remove unnecessary files

See `Dockerfile.triton` for current optimization.

