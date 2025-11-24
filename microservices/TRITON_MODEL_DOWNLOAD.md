# Triton Model Download Guide

This guide explains how to download the required models for the Triton Inference Server ensemble pipeline after building the Docker image.

## Overview

The Docker image is built **without** model files to keep the image size small. Models are downloaded separately and can be:

1. **Downloaded inside the running container**
2. **Downloaded to a host directory and mounted as a volume**
3. **Downloaded before starting the container**

## Required Models

The ensemble pipeline requires the following models:

| Model | Size (approx) | Location | Purpose |
|-------|---------------|----------|---------|
| `qwen_image_vae.safetensors` | ~500 MB | `shared_models/vae/` | VAE encoder/decoder |
| `qwen_2.5_vl_7b_fp8_scaled.safetensors` | ~7 GB | `shared_models/clip/` | CLIP text encoder |
| `qwen_image_edit_2509_fp8_e4m3fn.safetensors` | ~3 GB | `shared_models/diffusion_models/` | UNET diffusion model |
| `Qwen-Image-Lightning-4steps-V2.0.safetensors` | ~100 MB | `shared_models/loras/` | Lightning LoRA |

**Total size: ~10.6 GB**

## Method 1: Download Inside Running Container

### Step 1: Build and Start the Container

```bash
# Build the image
cd microservices
./build_triton_image.sh

# Start the container (with GPU support)
docker run -d --gpus all \
  --name vtryon-triton \
  -p 8000:8000 -p 8001:8001 -p 8002:8002 \
  vtryon-triton:latest
```

### Step 2: Download Models Inside Container

```bash
# Execute the download script inside the container
docker exec -it vtryon-triton /workspace/download_triton_models.sh

# Or manually run the script
docker exec -it vtryon-triton /bin/bash
# Inside container:
/workspace/download_triton_models.sh
```

The script will download all models to `/models/shared_models/` inside the container.

### Step 3: Restart Container (if needed)

If Triton was already running, you may need to restart it to detect the new models:

```bash
docker restart vtryon-triton
```

## Method 2: Download to Host Directory (Volume Mount)

This method is recommended for production as models persist even if the container is removed.

### Step 1: Create Host Directory

```bash
# Create directory on host
mkdir -p ~/triton_models/shared_models
```

### Step 2: Download Models to Host

```bash
# Run the download script on host
cd microservices
MODELS_DIR=~/triton_models/shared_models ./download_triton_models.sh
```

Or specify the path directly:

```bash
./download_triton_models.sh ~/triton_models/shared_models
```

### Step 3: Start Container with Volume Mount

```bash
# Start container with models directory mounted
docker run -d --gpus all \
  --name vtryon-triton \
  -p 8000:8000 -p 8001:8001 -p 8002:8002 \
  -v ~/triton_models:/models \
  vtryon-triton:latest
```

The models will be available at `/models/shared_models/` inside the container.

## Method 3: Download Before Starting Container

### Step 1: Download Models First

```bash
cd microservices

# Create models directory
mkdir -p triton_models/shared_models

# Download models
./download_triton_models.sh triton_models/shared_models
```

### Step 2: Start Container with Volume

```bash
docker run -d --gpus all \
  --name vtryon-triton \
  -p 8000:8000 -p 8001:8001 -p 8002:8002 \
  -v $(pwd)/triton_models:/models \
  vtryon-triton:latest
```

## Verifying Models

### Check Models in Container

```bash
# List downloaded models
docker exec vtryon-triton ls -lh /models/shared_models/vae/
docker exec vtryon-triton ls -lh /models/shared_models/clip/
docker exec vtryon-triton ls -lh /models/shared_models/diffusion_models/
docker exec vtryon-triton ls -lh /models/shared_models/loras/
```

### Check Triton Server Status

```bash
# Check if Triton is ready
curl http://localhost:8000/v2/health/ready

# List loaded models
curl http://localhost:8000/v2/models

# Check specific model
curl http://localhost:8000/v2/models/latent_encoder
curl http://localhost:8000/v2/models/vtryon_pipeline
```

## Troubleshooting

### Download Fails

If downloads fail:

1. **Check internet connection**: Ensure the container/host has internet access
2. **Check disk space**: Ensure you have at least 12 GB free space
3. **Retry download**: The script skips already downloaded files, so you can safely retry:
   ```bash
   docker exec -it vtryon-triton /workspace/download_triton_models.sh
   ```

### Models Not Detected by Triton

1. **Check file permissions**: Ensure models are readable
   ```bash
   docker exec vtryon-triton chmod -R 755 /models/shared_models
   ```

2. **Check Triton logs**: 
   ```bash
   docker logs vtryon-triton
   ```

3. **Verify model paths**: Check that models are in the correct directories:
   - `/models/shared_models/vae/qwen_image_vae.safetensors`
   - `/models/shared_models/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors`
   - `/models/shared_models/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors`
   - `/models/shared_models/loras/Qwen-Image-Lightning-4steps-V2.0.safetensors`

### Partial Downloads

If a download is interrupted, the script will detect incomplete files and re-download them. Simply run the script again.

## Manual Download (Alternative)

If the script doesn't work, you can manually download models using `wget` or `curl`:

```bash
# Inside container or on host
MODELS_DIR=/models/shared_models  # or your host path

# VAE
wget -O ${MODELS_DIR}/vae/qwen_image_vae.safetensors \
  https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors

# CLIP
wget -O ${MODELS_DIR}/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors \
  https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors

# UNET
wget -O ${MODELS_DIR}/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors \
  https://huggingface.co/theunlikely/Qwen-Image-Edit-2509/resolve/main/qwen_image_edit_2509_fp8_e4m3fn.safetensors

# LoRA
wget -O ${MODELS_DIR}/loras/Qwen-Image-Lightning-4steps-V2.0.safetensors \
  https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Lightning-4steps-V2.0.safetensors
```

## Environment Variables

The download script respects these environment variables:

- `TRITON_MODEL_REPOSITORY`: Base Triton model repository path
- `MODEL_DIR`: Direct path to shared_models directory
- `MODELS_DIR`: Direct path to shared_models directory (takes precedence)

## Next Steps

After downloading models:

1. **Test the ensemble pipeline**: Use the test scripts to verify everything works
2. **Monitor Triton logs**: Check for any errors during model loading
3. **Test inference**: Send a test request to the ensemble model

For more information, see:
- `TESTING_CHECKLIST.md` - Testing guide
- `TRITON_CONFIG.md` - Configuration details
- `VASTAI_DEPLOYMENT.md` - Production deployment



