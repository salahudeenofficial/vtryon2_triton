# Vast AI Commands - Model Download & Triton Server

## Quick Reference Commands

### 1. Check Container Status

```bash
# List running containers
docker ps

# Check container logs
docker logs <container-name> -f

# Or if you know the container name pattern
docker logs $(docker ps -q) -f
```

### 2. Check Model Download Status

```bash
# Check if models are downloaded
docker exec <container-name> ls -lh /workspace/shared_models/vae/
docker exec <container-name> ls -lh /workspace/shared_models/clip/
docker exec <container-name> ls -lh /workspace/shared_models/diffusion_models/
docker exec <container-name> ls -lh /workspace/shared_models/loras/

# Check total size of models directory
docker exec <container-name> du -sh /workspace/shared_models/*

# Check specific model files
docker exec <container-name> ls -lh /workspace/shared_models/vae/qwen_image_vae.safetensors
docker exec <container-name> ls -lh /workspace/shared_models/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors
docker exec <container-name> ls -lh /workspace/shared_models/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors
docker exec <container-name> ls -lh /workspace/shared_models/loras/Qwen-Image-Lightning-4steps-V2.0.safetensors

# Check download progress in logs
docker logs <container-name> 2>&1 | grep -E "(downloading|Download|MB|GB)" | tail -20
```

### 3. Check Triton Server Status

```bash
# Check if Triton server is running
docker exec <container-name> ps aux | grep tritonserver

# Check Triton server logs
docker logs <container-name> 2>&1 | grep -E "(Triton|READY|ready|error|Error)" | tail -30

# Check if server is ready (from inside container)
docker exec <container-name> curl -s http://localhost:8000/v2/health/ready

# Check from host (if ports are exposed)
curl http://localhost:8000/v2/health/ready

# Check server live status
curl http://localhost:8000/v2/health/live

# List loaded models
curl http://localhost:8000/v2/models | python3 -m json.tool
```

### 4. Check Model Loading Status

```bash
# Check which models are loaded
docker logs <container-name> 2>&1 | grep -E "(READY|LOADING|UNLOADING)" | tail -20

# Check model initialization
docker logs <container-name> 2>&1 | grep -E "(Initializing|initialized)" | tail -20

# Check for errors
docker logs <container-name> 2>&1 | grep -i error | tail -20
```

### 5. Manual Model Download (if needed)

```bash
# Enter container
docker exec -it <container-name> bash

# Run download script manually
/workspace/download_triton_models.sh

# Or check if download is in progress
ps aux | grep -E "(wget|curl|download)"
```

### 6. Restart Triton Server (if needed)

```bash
# Restart container (this restarts Triton)
docker restart <container-name>

# Or if you need to restart just Triton (inside container)
docker exec <container-name> pkill tritonserver
# (Triton will restart automatically via entrypoint)
```

---

## All-in-One Status Check

```bash
# Replace <container-name> with your actual container name
CONTAINER="<container-name>"

echo "=== Container Status ==="
docker ps --filter name=$CONTAINER

echo ""
echo "=== Model Download Status ==="
docker exec $CONTAINER du -sh /workspace/shared_models/* 2>/dev/null || echo "Models directory not accessible"

echo ""
echo "=== Triton Server Status ==="
docker exec $CONTAINER curl -s http://localhost:8000/v2/health/ready && echo " - Ready" || echo " - Not ready"

echo ""
echo "=== Loaded Models ==="
docker logs $CONTAINER 2>&1 | grep -E "READY" | grep -E "(decoding|latent_encoder|sampling|text_encoder|vtryon_pipeline)" | tail -5

echo ""
echo "=== Recent Errors ==="
docker logs $CONTAINER 2>&1 | grep -i error | tail -5
```

---

## Expected Model Sizes

When fully downloaded, you should see:
- VAE: ~242 MB (qwen_image_vae.safetensors)
- CLIP: ~8949 MB (qwen_2.5_vl_7b_fp8_scaled.safetensors)
- UNET: ~19484 MB (qwen_image_edit_2509_fp8_e4m3fn.safetensors)
- LoRA: ~167 MB (Qwen-Image-Lightning-4steps-V2.0.safetensors)
- **Total: ~28.8 GB**

---

## Troubleshooting

### Models not downloading?
```bash
# Check if download script is running
docker exec <container-name> ps aux | grep download

# Check network connectivity
docker exec <container-name> ping -c 3 8.8.8.8

# Manually trigger download
docker exec <container-name> /workspace/download_triton_models.sh
```

### Triton server not starting?
```bash
# Check full logs
docker logs <container-name> 2>&1 | tail -100

# Check for Python errors
docker logs <container-name> 2>&1 | grep -i "python\|import\|error" | tail -20

# Check file permissions
docker exec <container-name> ls -la /workspace/shared_comfyui
docker exec <container-name> ls -la /workspace/shared_models
```


