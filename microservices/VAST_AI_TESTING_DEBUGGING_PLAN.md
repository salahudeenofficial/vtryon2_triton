# Vast AI Testing & Debugging Plan

## Overview
This document outlines a comprehensive plan for testing and debugging the Triton server on Vast AI, with strategies for syncing fixes back to local code.

---

## 🎯 Goals

1. **Test Triton server** on Vast AI instance
2. **Debug issues** efficiently
3. **Sync fixes** from container back to local code
4. **Iterate quickly** without losing work
5. **Push final image** with all fixes

---

## 📋 Pre-Deployment Checklist

### Before Pushing Image

- [ ] All local fixes are committed
- [ ] Image builds successfully locally
- [ ] Models are downloaded and accessible
- [ ] Container starts and Triton server becomes ready
- [ ] Basic health checks pass

### Image Tagging Strategy

```bash
# Tag with version for tracking
docker tag vtryon-triton:latest vtryon-triton:v1.0-debug
docker tag vtryon-triton:latest vtryon-triton:latest

# Push to registry
docker push vtryon-triton:v1.0-debug
docker push vtryon-triton:latest
```

---

## 🚀 Deployment on Vast AI

### Step 1: Start Vast AI Instance

1. **Select GPU**: Choose appropriate GPU (24GB+ recommended)
2. **Image**: Use your pushed Docker image
3. **Ports**: Expose 8000, 8001, 8002 (HTTP, gRPC, Metrics)
4. **Volumes**: Mount persistent storage for models (optional)

### Step 2: Connect to Instance

```bash
# SSH into Vast AI instance
ssh root@<vast-ai-ip>

# Or use Vast AI's web terminal
```

---

## 🧪 Testing Strategy

### Phase 1: Basic Health Checks

```bash
# 1. Check container is running
docker ps

# 2. Check Triton server logs
docker logs <container-name> -f

# 3. Test health endpoints
curl http://localhost:8000/v2/health/live
curl http://localhost:8000/v2/health/ready

# 4. List loaded models
curl http://localhost:8000/v2/models | python3 -m json.tool

# 5. Check model status
curl http://localhost:8000/v2/models/<model-name>/ready | python3 -m json.tool
```

### Phase 2: Model Initialization Verification

```bash
# Check all models are READY
for model in latent_encoder text_encoder sampling decoding vtryon_pipeline; do
  echo "Checking $model..."
  curl -s http://localhost:8000/v2/models/$model/ready
  echo ""
done

# Check model metadata
curl http://localhost:8000/v2/models/latent_encoder | python3 -m json.tool
```

### Phase 3: Inference Testing

```bash
# Test with sample request (will fail without real images, but tests routing)
curl -X POST http://localhost:8000/v2/models/vtryon_pipeline/infer \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": [
      {"name": "image1_path", "shape": [1,1], "datatype": "BYTES", "data": [["/tmp/test1.jpg"]]},
      {"name": "image2_path", "shape": [1,1], "datatype": "BYTES", "data": [["/tmp/test2.jpg"]]},
      {"name": "prompt", "shape": [1,1], "datatype": "BYTES", "data": [["test prompt"]]},
      {"name": "seed", "shape": [1,1], "datatype": "INT64", "data": [[42]]}
    ],
    "outputs": [{"name": "output_image"}]
  }' | python3 -m json.tool
```

### Phase 4: Full Pipeline Test

```bash
# With actual image files
# (Upload test images first, then run inference)
```

---

## 🐛 Debugging Workflow

### Strategy: Two-Way Sync

**Problem**: Changes made in container are lost when container restarts.

**Solution**: Use volume mounts + git workflow

### Option 1: Volume Mount for Code (Recommended for Active Debugging)

```bash
# On Vast AI instance, mount local code directory
docker run -d \
  --name vtryon-debug \
  --gpus all \
  -p 8000:8000 -p 8001:8001 -p 8002:8002 \
  -v /path/to/local/code/triton_model_repository:/models:ro \
  -v /path/to/local/code/shared_comfyui:/workspace/shared_comfyui:ro \
  -v /path/to/models:/workspace/shared_models \
  vtryon-triton:latest
```

**Pros**: 
- Changes in local code immediately available
- No need to rebuild image
- Easy to test fixes

**Cons**:
- Requires code to be on Vast AI instance
- Read-only mounts prevent container modifications

### Option 2: Git-Based Workflow (Recommended for Final Fixes)

```bash
# Inside container, make changes
docker exec -it <container-name> bash

# Edit files
vi /models/latent_encoder/1/model.py

# Test changes
# (Triton will reload models if using model control API)

# When fix works, copy changes out
docker cp <container-name>:/models/latent_encoder/1/model.py ./triton_model_repository/latent_encoder/1/model.py

# Commit and push
git add .
git commit -m "Fix: <description>"
git push

# Rebuild image with fixes
docker build -f Dockerfile.triton -t vtryon-triton:latest .
docker push vtryon-triton:latest
```

### Option 3: Hybrid Approach (Best for Iterative Development)

**Step 1**: Initial deployment with volume mounts for rapid iteration
**Step 2**: Once stable, commit fixes and rebuild image
**Step 3**: Deploy final image without volume mounts

---

## 🔧 Debugging Commands

### Container Inspection

```bash
# Enter container
docker exec -it <container-name> bash

# Check environment variables
env | grep -E "(COMFYUI|MODEL|TRITON)"

# Check file paths
ls -la /workspace/shared_comfyui
ls -la /workspace/shared_models
ls -la /models

# Check Python paths
python3 -c "import sys; print('\n'.join(sys.path))"

# Test imports
python3 -c "
import sys
sys.path.insert(0, '/workspace/shared_comfyui')
sys.path.insert(0, '/models/latent_encoder/1')
from service import encode_image_to_latent
print('Import successful')
"
```

### Triton Server Debugging

```bash
# Enable verbose logging (if not already)
# Check entrypoint.sh has --log-verbose=1

# View real-time logs
docker logs -f <container-name>

# Filter for errors
docker logs <container-name> 2>&1 | grep -i error

# Check model loading
docker logs <container-name> 2>&1 | grep -E "(READY|LOADING|UNLOADING)"

# Check Python backend errors
docker logs <container-name> 2>&1 | grep -E "(python|Python|PYTHON)"
```

### Model-Specific Debugging

```bash
# Test individual model
curl -X POST http://localhost:8000/v2/models/latent_encoder/infer \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": [{
      "name": "image_path",
      "shape": [1,1],
      "datatype": "BYTES",
      "data": [["/path/to/image.jpg"]]
    }],
    "outputs": [{"name": "latent"}]
  }'

# Check model config
curl http://localhost:8000/v2/models/latent_encoder/config | python3 -m json.tool
```

### GPU Memory Monitoring

```bash
# Monitor GPU memory
watch -n 1 nvidia-smi

# Check memory usage during inference
nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv -l 1
```

### File System Debugging

```bash
# Check if files exist
docker exec <container-name> ls -la /workspace/shared_comfyui/comfy
docker exec <container-name> ls -la /workspace/shared_models/vae

# Check file permissions
docker exec <container-name> ls -la /models/latent_encoder/1/

# Test file access
docker exec <container-name> cat /models/latent_encoder/1/model.py | head -20
```

---

## 📦 Code Synchronization Strategy

### Method 1: Docker Copy (Quick Fixes)

```bash
# Copy file from container to local
docker cp <container-name>:/models/latent_encoder/1/model.py \
  ./triton_model_repository/latent_encoder/1/model.py

# Copy entire directory
docker cp <container-name>:/models/latent_encoder/1/ \
  ./triton_model_repository/latent_encoder/1/
```

### Method 2: Git Workflow (Recommended)

```bash
# 1. Make changes in container
docker exec -it <container-name> bash
# ... edit files ...

# 2. Copy changes out
docker cp <container-name>:/models/latent_encoder/1/model.py \
  ./triton_model_repository/latent_encoder/1/model.py

# 3. Test locally
docker build -f Dockerfile.triton -t vtryon-triton:test .
docker run --gpus all -p 8000:8000 vtryon-triton:test

# 4. Commit and push
git add triton_model_repository/
git commit -m "Fix: <description of fix>"
git push

# 5. Rebuild and push image
docker build -f Dockerfile.triton -t vtryon-triton:latest .
docker push vtryon-triton:latest
```

### Method 3: Volume Mount with Git (Best for Active Development)

```bash
# On Vast AI, clone repo
git clone <your-repo-url>
cd <repo>

# Run container with volume mount
docker run -d \
  --name vtryon-debug \
  --gpus all \
  -p 8000:8000 \
  -v $(pwd)/microservices/triton_model_repository:/models:ro \
  -v $(pwd)/microservices/triton_model_repository/shared_comfyui:/workspace/shared_comfyui:ro \
  vtryon-triton:latest

# Make changes locally (on Vast AI instance)
vi microservices/triton_model_repository/latent_encoder/1/model.py

# Test (Triton may need restart or model reload)
docker restart vtryon-debug

# Commit changes
git add .
git commit -m "Fix: <description>"
git push
```

---

## 🎯 Recommended Workflow

### Phase 1: Initial Deployment & Testing

1. **Push image** to registry
2. **Deploy on Vast AI** with basic configuration
3. **Run health checks** (Phase 1 testing)
4. **Identify issues** from logs

### Phase 2: Active Debugging

1. **Use volume mounts** for rapid iteration
   ```bash
   # Mount code directory (read-only for safety)
   -v /path/to/code:/models:ro
   ```

2. **Make changes locally** on Vast AI instance
3. **Test immediately** (restart container if needed)
4. **Document fixes** as you go

### Phase 3: Stabilization

1. **Once fixes are stable**, copy all changes out
2. **Test locally** with rebuilt image
3. **Commit and push** code changes
4. **Rebuild and push** Docker image
5. **Redeploy** with final image (no volume mounts)

---

## 📝 Debugging Checklist

### Common Issues & Solutions

#### Issue: Models not loading
```bash
# Check logs
docker logs <container> | grep -i error

# Verify paths
docker exec <container> ls -la /workspace/shared_comfyui
docker exec <container> ls -la /workspace/shared_models

# Test imports
docker exec <container> python3 -c "import sys; sys.path.insert(0, '/workspace/shared_comfyui'); import comfy"
```

#### Issue: OOM Errors
```bash
# Monitor memory
watch -n 1 nvidia-smi

# Check model sizes
docker exec <container> du -sh /workspace/shared_models/*

# Reduce batch size or use CPU offloading
```

#### Issue: Import Errors
```bash
# Check Python path
docker exec <container> python3 -c "import sys; print('\n'.join(sys.path))"

# Test imports manually
docker exec <container> python3 -c "
import sys
sys.path.insert(0, '/workspace/shared_comfyui')
sys.path.insert(0, '/models/latent_encoder/1')
from service import encode_image_to_latent
"
```

#### Issue: Path Errors
```bash
# Verify environment variables
docker exec <container> env | grep -E "(COMFYUI|MODEL)"

# Check file existence
docker exec <container> test -d /workspace/shared_comfyui && echo "Exists" || echo "Missing"
```

---

## 🔄 Iterative Development Script

Create a helper script for quick iteration:

```bash
#!/bin/bash
# debug_helper.sh

CONTAINER_NAME="vtryon-debug"
MODEL_NAME="${1:-latent_encoder}"

echo "=== Debugging $MODEL_NAME ==="

# 1. Copy file from container
echo "Copying $MODEL_NAME/model.py from container..."
docker cp $CONTAINER_NAME:/models/$MODEL_NAME/1/model.py \
  ./triton_model_repository/$MODEL_NAME/1/model.py

# 2. Show diff
echo ""
echo "=== Changes made ==="
git diff triton_model_repository/$MODEL_NAME/1/model.py

# 3. Ask to commit
read -p "Commit these changes? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git add triton_model_repository/$MODEL_NAME/1/model.py
    read -p "Commit message: " msg
    git commit -m "$msg"
    echo "✓ Committed"
fi
```

---

## ✅ Final Deployment Checklist

Before pushing final image:

- [ ] All fixes tested and working
- [ ] All changes committed to git
- [ ] Image rebuilt with latest code
- [ ] Image tested locally
- [ ] Image pushed to registry
- [ ] Documentation updated
- [ ] Version tagged appropriately

---

## 🚨 Emergency Debugging

If server crashes or becomes unresponsive:

```bash
# 1. Get logs immediately
docker logs <container> --tail 1000 > debug_logs.txt

# 2. Check system resources
nvidia-smi
df -h
free -h

# 3. Restart container
docker restart <container>

# 4. Check if models are corrupted
docker exec <container> ls -lh /workspace/shared_models/*/*.safetensors
```

---

## 📊 Monitoring & Metrics

```bash
# Triton metrics endpoint
curl http://localhost:8002/metrics

# Model statistics
curl http://localhost:8000/v2/models/latent_encoder/stats | python3 -m json.tool

# Server statistics
curl http://localhost:8000/v2 | python3 -m json.tool
```

---

## 🎓 Best Practices

1. **Always commit fixes** before rebuilding image
2. **Use version tags** for tracking iterations
3. **Keep debug logs** for reference
4. **Test locally** before pushing to registry
5. **Document issues** and solutions
6. **Use volume mounts** during active debugging
7. **Remove volume mounts** for production deployment

---

## 🔗 Quick Reference

### Essential Commands

```bash
# Connect to Vast AI
ssh root@<vast-ai-ip>

# Check container
docker ps
docker logs -f <container-name>

# Test health
curl http://localhost:8000/v2/health/ready

# Copy file from container
docker cp <container>:/path/to/file ./local/path

# Restart container
docker restart <container-name>

# Rebuild image
docker build -f Dockerfile.triton -t vtryon-triton:latest .
```

---

## Summary

**Recommended Approach**:
1. **Initial**: Deploy with volume mounts for rapid debugging
2. **Active Debugging**: Make changes, test, copy out, commit
3. **Final**: Rebuild image with all fixes, deploy without mounts

This gives you the best of both worlds: rapid iteration during debugging, and stable deployment for production.


