# VastAI Model Download Status

## Current Status

✅ **Download script is running**
✅ **Qwen VAE Model downloaded successfully** (~500 MB)

---

## Check Download Progress

### 1. Check what's been downloaded so far

```bash
# Check VAE directory
ls -lh /models/shared_models/vae/

# Check CLIP directory
ls -lh /models/shared_models/clip/

# Check diffusion models directory
ls -lh /models/shared_models/diffusion_models/

# Check LoRAs directory
ls -lh /models/shared_models/loras/

# Check total size
du -sh /models/shared_models/*
```

### 2. Monitor download progress

The script will download:
- ✅ Qwen VAE Model (~500 MB) - **DONE**
- ⏳ CLIP models (multiple files, ~1-2 GB total)
- ⏳ Diffusion models (largest, ~4-6 GB)
- ⏳ LoRA models (if any, ~100-500 MB)

**Total expected**: ~10-12 GB

### 3. Check if download is still running

```bash
# Check if download script is still running
ps aux | grep download_triton_models

# Or check if there's network activity
# (downloads will show network usage)
```

---

## What to Expect

The download script will:
1. ✅ Create directories
2. ✅ Download Qwen VAE (DONE)
3. ⏳ Download CLIP models
4. ⏳ Download diffusion models
5. ⏳ Download LoRA models (if configured)
6. ⏳ Verify all downloads

**Total time**: 10-30 minutes depending on connection speed

---

## While Downloading

You can:
1. **Monitor progress**: Check file sizes growing
2. **Check container**: Ensure container is still running
3. **Wait patiently**: Large files take time

```bash
# Watch file sizes grow (run every 30 seconds)
watch -n 30 'du -sh /models/shared_models/*'

# Or check specific directory
watch -n 30 'ls -lh /models/shared_models/vae/'
```

---

## After Download Completes

### 1. Verify all models downloaded

```bash
# Check all directories have files
ls -lh /models/shared_models/vae/
ls -lh /models/shared_models/clip/
ls -lh /models/shared_models/diffusion_models/
ls -lh /models/shared_models/loras/

# Check total size (should be ~10-12 GB)
du -sh /models/shared_models/
```

### 2. Restart container to load models

```bash
# Find container name/ID
docker ps

# Restart container
docker restart <container-name>

# Or if using container ID
docker restart $(docker ps -q)
```

### 3. Wait for Triton to load models

```bash
# Watch logs to see models loading
docker logs -f <container-name>

# Look for messages like:
# - "Loading model: latent_encoder"
# - "Loading model: text_encoder"
# - "Loading model: sampling"
# - "Loading model: decoding"
# - "Loading model: vtryon_pipeline"
```

### 4. Test server

```bash
# Check health
curl http://localhost:8000/v2/health/ready

# List models
curl http://localhost:8000/v2/models

# Should show all 5 models:
# - latent_encoder
# - text_encoder
# - sampling
# - decoding
# - vtryon_pipeline
```

---

## Troubleshooting

### Download Stopped/Interrupted

```bash
# Check if script is still running
ps aux | grep download

# If not running, restart download
docker exec -it <container-name> /workspace/download_triton_models.sh
```

### Missing Files

```bash
# Check what should be there
cat /workspace/download_triton_models.sh

# Re-run download for specific model
# (check script for individual download commands)
```

### Container Stopped

```bash
# Check container status
docker ps -a

# Restart container
docker start <container-name>

# Or recreate if needed
docker run -d \
  --name vtryon-triton \
  --gpus all \
  --shm-size=4g \
  --restart unless-stopped \
  -p 8000:8000 \
  -p 8001:8001 \
  -p 8002:8002 \
  -v /models:/models \
  salafashionx/vtryon-triton:latest
```

---

## Quick Status Check Commands

```bash
# 1. Check download progress
du -sh /models/shared_models/*

# 2. Check if script is running
ps aux | grep download

# 3. Check container status
docker ps

# 4. Check container logs
docker logs -f $(docker ps -q)

# 5. Check specific model files
ls -lh /models/shared_models/vae/
ls -lh /models/shared_models/clip/
```

---

## Expected File Structure

After complete download:

```
/models/shared_models/
├── vae/
│   └── qwen_image_vae.safetensors (~500 MB)
├── clip/
│   ├── (CLIP model files, ~1-2 GB)
├── diffusion_models/
│   ├── (Diffusion model files, ~4-6 GB)
└── loras/
    └── (LoRA files if any, ~100-500 MB)
```

---

## Next Steps

1. ✅ Wait for download to complete (10-30 minutes)
2. ⏳ Verify all files downloaded
3. ⏳ Restart container
4. ⏳ Test Triton server
5. ⏳ Verify all models loaded

