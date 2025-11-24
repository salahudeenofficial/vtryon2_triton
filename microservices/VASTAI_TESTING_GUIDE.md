# VastAI Testing Guide - Step by Step

## Current Status
You're on the VastAI instance at `/workspace`. Let's test the Triton server.

---

## Step 1: Check Docker Container Status

```bash
# Check if container is running
docker ps

# Check all containers (including stopped)
docker ps -a

# Check container logs
docker logs <container-name>
```

**Expected**: You should see a container running with image `salafashionx/vtryon-triton:latest`

---

## Step 2: Verify Container is Running

```bash
# List running containers
docker ps

# If container is not running, check what happened
docker ps -a
docker logs <container-name>
```

**If container is not running**, you may need to start it manually:

```bash
docker run -d \
  --name vtryon-triton \
  --gpus all \
  --shm-size=4g \
  --restart unless-stopped \
  -p 8000:8000 \
  -p 8001:8001 \
  -p 8002:8002 \
  salafashionx/vtryon-triton:latest
```

---

## Step 3: Check Container Logs

```bash
# View recent logs
docker logs <container-name>

# Follow logs in real-time
docker logs -f <container-name>

# Check last 50 lines
docker logs --tail 50 <container-name>
```

**Look for**:
- ✅ "Triton Inference Server started"
- ✅ "Model repository loaded"
- ⚠️ Any error messages about missing models

---

## Step 4: Download Models (If Needed)

Models are NOT in the Docker image. You need to download them:

```bash
# Enter the running container
docker exec -it <container-name> bash

# Inside container, check if download script exists
ls -la /workspace/download_triton_models.sh

# Run the download script
/workspace/download_triton_models.sh

# Wait for download to complete (10-30 minutes)
# Exit container when done
exit

# Restart container to load models
docker restart <container-name>
```

**Alternative**: If download script doesn't work, download models manually or mount from host.

---

## Step 5: Test Triton Server Health

```bash
# Test if server is ready
curl http://localhost:8000/v2/health/ready

# Expected response:
# {"status":"ready"}

# Test if server is live
curl http://localhost:8000/v2/health/live

# Expected response:
# {"status":"alive"}
```

**If you get connection refused**:
- Container may not be running
- Server may still be starting (wait 1-2 minutes)
- Check logs: `docker logs <container-name>`

---

## Step 6: List Available Models

```bash
# List all models
curl http://localhost:8000/v2/models

# Expected models:
# - latent_encoder
# - text_encoder
# - sampling
# - decoding
# - vtryon_pipeline (ensemble)

# Get detailed info about a model
curl http://localhost:8000/v2/models/vtryon_pipeline

# Check model readiness
curl http://localhost:8000/v2/models/vtryon_pipeline/ready
```

---

## Step 7: Test GPU Access

```bash
# Check GPU inside container
docker exec <container-name> nvidia-smi

# Test PyTorch CUDA
docker exec <container-name> /opt/venv/bin/python -c "import torch; print(f'CUDA Available: {torch.cuda.is_available()}')"

# Check CUDA version
docker exec <container-name> nvidia-smi --query-gpu=driver_version --format=csv
```

---

## Step 8: Test Inference (If Models Are Loaded)

```bash
# Test ensemble model inference
curl -X POST http://localhost:8000/v2/models/vtryon_pipeline/infer \
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

## Step 9: Check External Access

Get your VastAI instance's public IP and port from the VastAI dashboard, then test:

```bash
# From your local machine
curl http://<vastai-ip>:<port>/v2/health/ready

# List models from external
curl http://<vastai-ip>:<port>/v2/models
```

**Note**: VastAI may assign different external ports. Check the VastAI dashboard for port mappings.

---

## Troubleshooting

### Container Not Running
```bash
# Check what happened
docker ps -a
docker logs <container-name>

# Start manually if needed
docker start <container-name>
```

### Models Not Found
```bash
# Check if models directory exists in container
docker exec <container-name> ls -la /models/shared_models/

# Download models (see Step 4)
```

### Server Not Responding
```bash
# Check if server is still starting
docker logs -f <container-name>

# Wait 2-3 minutes for initial startup
# Check again: curl http://localhost:8000/v2/health/ready
```

### GPU Not Available
```bash
# Check GPU access
docker exec <container-name> nvidia-smi

# If no GPU, check VastAI GPU configuration
# Ensure GPU is enabled in VastAI settings
```

---

## Quick Test Commands

```bash
# 1. Check container
docker ps

# 2. Check health
curl http://localhost:8000/v2/health/ready

# 3. List models
curl http://localhost:8000/v2/models

# 4. Check GPU
docker exec <container-name> nvidia-smi

# 5. View logs
docker logs -f <container-name>
```

---

## Expected Results

After successful setup:

✅ Container running: `docker ps` shows your container  
✅ Server ready: `curl http://localhost:8000/v2/health/ready` returns `{"status":"ready"}`  
✅ Models loaded: `curl http://localhost:8000/v2/models` shows 5 models  
✅ GPU accessible: `nvidia-smi` works inside container  
✅ External access: Can access from your local machine

---

## Next Steps

1. ✅ Container running
2. ✅ Models downloaded
3. ✅ Server verified
4. 🔄 Test inference with your API
5. 🔄 Monitor performance

