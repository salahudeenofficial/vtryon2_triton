# VastAI Deployment Checklist & Potential Issues

## ✅ Pre-Deployment Checklist

### 1. Image Pushed to DockerHub
- [ ] Image built successfully
- [ ] Image tagged with DockerHub username
- [ ] Image pushed to DockerHub
- [ ] Image accessible: `docker pull your-username/vtryon-triton:latest`

### 2. VastAI Instance Requirements
- [ ] GPU with 24GB+ VRAM (RTX 3090/4090, A100, etc.)
- [ ] Docker with GPU support installed
- [ ] NVIDIA Container Toolkit installed
- [ ] Ports 8000, 8001, 8002 available

### 3. Container Configuration
- [ ] Docker image: `your-username/vtryon-triton:latest`
- [ ] GPU access: `--gpus all`
- [ ] Shared memory: `--shm-size=4g` (recommended)
- [ ] Ports mapped: 8000, 8001, 8002

---

## ⚠️ Potential Issues & Solutions

### Issue 1: Models Not Found
**Problem**: Triton fails to start because models are missing

**Symptoms**:
```
error: creating server: Internal - failed to load all models
```

**Solutions**:
1. **Download models inside container** (recommended for first run):
   ```bash
   docker exec -it <container> /workspace/download_triton_models.sh
   ```
   Then restart container.

2. **Mount models from host**:
   ```bash
   # On VastAI host, download models first
   mkdir -p /workspace/models
   # Download models to /workspace/models
   
   # Mount in Docker
   docker run ... -v /workspace/models:/models/shared_models ...
   ```

3. **Use volume mount** (if models already on VastAI):
   ```bash
   -v /path/to/models:/models/shared_models:ro
   ```

---

### Issue 2: GPU Not Available
**Problem**: PyTorch can't access GPU

**Symptoms**:
```
CUDA available: False
WARNING: The NVIDIA Driver was not detected
```

**Solutions**:
1. **Verify GPU access**:
   ```bash
   docker exec <container> nvidia-smi
   ```

2. **Check VastAI instance**:
   - Ensure GPU is allocated
   - Check NVIDIA drivers are installed
   - Verify `--gpus all` flag is used

3. **Test GPU in container**:
   ```bash
   docker exec <container> /opt/venv/bin/python -c "import torch; print(torch.cuda.is_available())"
   ```

---

### Issue 3: Out of Memory (OOM)
**Problem**: Container killed due to memory limits

**Symptoms**:
```
Killed
exit code 137
```

**Solutions**:
1. **Increase shared memory**:
   ```bash
   --shm-size=8g  # or higher
   ```

2. **Use larger GPU**:
   - RTX 3090/4090 (24GB) minimum
   - A100 (40GB/80GB) recommended

3. **Monitor memory usage**:
   ```bash
   docker stats <container>
   nvidia-smi
   ```

---

### Issue 4: Port Not Accessible
**Problem**: Can't access Triton API from outside

**Symptoms**:
```
Connection refused
Timeout
```

**Solutions**:
1. **Check port mapping**:
   ```bash
   docker ps  # Verify ports are mapped
   ```

2. **Check VastAI firewall**:
   - Ensure ports 8000, 8001, 8002 are open
   - Check VastAI instance port configuration

3. **Test locally first**:
   ```bash
   curl http://localhost:8000/v2/health/ready
   ```

---

### Issue 5: ComfyUI Import Errors
**Problem**: Python can't find ComfyUI modules

**Symptoms**:
```
ModuleNotFoundError: No module named 'comfy'
ImportError: cannot import name 'xxx' from 'comfy'
```

**Solutions**:
1. **Verify ComfyUI in image**:
   ```bash
   docker exec <container> ls -la /models/shared_comfyui/comfy/
   ```

2. **Check PYTHONPATH**:
   ```bash
   docker exec <container> echo $PYTHONPATH
   # Should include: /models/shared_comfyui
   ```

3. **Verify environment variables**:
   ```bash
   docker exec <container> env | grep -E "PYTHONPATH|COMFYUI"
   ```

---

### Issue 6: Ensemble Model Not Found
**Problem**: vtryon_pipeline ensemble not available

**Symptoms**:
```
Model 'vtryon_pipeline' is not found
```

**Solutions**:
1. **Verify ensemble config exists**:
   ```bash
   docker exec <container> ls -la /models/vtryon_pipeline/
   ```

2. **Check Triton logs**:
   ```bash
   docker logs <container> | grep -i ensemble
   ```

3. **Verify all component models loaded**:
   ```bash
   curl http://localhost:8000/v2/models
   # Should show: latent_encoder, text_encoder, sampling, decoding, vtryon_pipeline
   ```

---

### Issue 7: Slow Model Loading
**Problem**: Models take too long to load

**Solutions**:
1. **Pre-download models** before starting container
2. **Use SSD storage** on VastAI instance
3. **Mount models as volume** instead of downloading inside container
4. **Increase shared memory** for faster I/O

---

### Issue 8: PyTorch CUDA Version Mismatch
**Problem**: PyTorch CUDA version doesn't match system CUDA

**Symptoms**:
```
CUDA runtime version mismatch
```

**Solutions**:
1. **Verify CUDA version**:
   ```bash
   docker exec <container> nvidia-smi  # Check CUDA version
   docker exec <container> /opt/venv/bin/python -c "import torch; print(torch.version.cuda)"
   ```

2. **Image uses CUDA 13.0** - ensure VastAI instance supports it

---

## 🚀 Quick Start on VastAI

### Step 1: Create Instance
- GPU: RTX 3090/4090 or A100
- Storage: 50GB+ (for models)
- Docker: Pre-installed

### Step 2: Pull and Run Container
```bash
# Pull image
docker pull your-username/vtryon-triton:latest

# Run container
docker run -d \
  --name vtryon-triton \
  --gpus all \
  --shm-size=4g \
  --restart unless-stopped \
  -p 8000:8000 \
  -p 8001:8001 \
  -p 8002:8002 \
  your-username/vtryon-triton:latest
```

### Step 3: Download Models
```bash
# Enter container
docker exec -it vtryon-triton bash

# Download models
/workspace/download_triton_models.sh

# Exit and restart container
exit
docker restart vtryon-triton
```

### Step 4: Verify
```bash
# Check health
curl http://localhost:8000/v2/health/ready

# List models
curl http://localhost:8000/v2/models

# Check ensemble
curl http://localhost:8000/v2/models/vtryon_pipeline
```

---

## 📝 Notes

1. **Models are NOT in the image** - they must be downloaded separately (~10.6 GB)
2. **First startup will be slow** - models need to be downloaded
3. **GPU memory usage** - expect 8-16GB VRAM usage during inference
4. **Network bandwidth** - downloading models requires good connection

---

## 🔍 Debugging Commands

```bash
# Check container status
docker ps -a | grep vtryon

# View logs
docker logs -f vtryon-triton

# Check GPU
docker exec vtryon-triton nvidia-smi

# Check models
docker exec vtryon-triton ls -lh /models/shared_models/*/

# Test Python/CUDA
docker exec vtryon-triton /opt/venv/bin/python -c "import torch; print(f'CUDA: {torch.cuda.is_available()}, Version: {torch.__version__}')"

# Check Triton status
curl http://localhost:8000/v2/health/ready
curl http://localhost:8000/v2/models
```



