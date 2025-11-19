# How to Start Triton Inference Server

## ⚠️ Important: Are You Inside a Docker Container?

**If you're already inside a Docker container on VastAI**, you need to **exit the container first**:

```bash
# Exit the container
exit

# Now you're on the VastAI host
# Then proceed with the steps below
```

See `RUNNING_IN_DOCKER.md` for more details.

---

## Quick Start

### Option 1: Using Docker Run (Recommended)

**Note**: Run this on the VastAI **host**, not inside a container.

```bash
cd /path/to/vtryon2_triton/microservices

docker run --gpus all \
  --shm-size=1g \
  -p 8000:8000 \
  -p 8001:8001 \
  -p 8002:8002 \
  -v $(pwd)/triton_model_repository:/models \
  nvcr.io/nvidia/tritonserver:25.10-py3 \
  tritonserver --model-repository=/models --log-verbose=1
```

### Option 2: Using the Startup Script

```bash
cd /path/to/vtryon2_triton/microservices
chmod +x start_triton.sh
./start_triton.sh
```

---

## Detailed Setup

### Prerequisites

1. **Docker with GPU support**
   ```bash
   # Verify Docker can access GPU
   docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
   ```

2. **Triton Model Repository**
   - Ensure `triton_model_repository/` directory exists
   - All model directories should have `config.pbtxt` and `1/model.py`

3. **Models Available** (on VastAI)
   - Models should be in `triton_model_repository/shared_models/`
   - ComfyUI should be in `triton_model_repository/shared_comfyui/`

---

## Docker Command Breakdown

```bash
docker run \
  --gpus all \                    # Enable GPU access
  --shm-size=1g \                 # Shared memory (may need more for large models)
  -p 8000:8000 \                  # HTTP endpoint
  -p 8001:8001 \                  # gRPC endpoint
  -p 8002:8002 \                  # Metrics endpoint
  -v $(pwd)/triton_model_repository:/models \  # Mount model repository
  nvcr.io/nvidia/tritonserver:25.10-py3 \     # Triton image
  tritonserver \
    --model-repository=/models \   # Path to models in container
    --log-verbose=1                # Verbose logging
```

### Ports

- **8000**: HTTP/REST API
- **8001**: gRPC API
- **8002**: Metrics endpoint

### Volume Mounts

- `-v $(pwd)/triton_model_repository:/models`: Maps local model repository to `/models` in container

---

## Verify Server is Running

### Check Server Status

```bash
# Check if server is running
curl http://localhost:8000/v2/health/ready

# Should return: {"status":"ready"}
```

### Check Model Status

```bash
# List all models
curl http://localhost:8000/v2/models

# Check specific model
curl http://localhost:8000/v2/models/latent_encoder

# Check model readiness
curl http://localhost:8000/v2/models/latent_encoder/ready
```

### View Server Logs

```bash
# If running in foreground, logs appear in terminal
# If running in background, use:
docker logs <container_id>
```

---

## Common Issues

### Issue 1: GPU Not Available

**Error**: `CUDA driver version is insufficient`

**Solution**:
```bash
# Check NVIDIA driver
nvidia-smi

# Verify Docker GPU access
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
```

### Issue 2: Model Not Loading

**Error**: `Model not found` or `Import error`

**Solution**:
1. Check model repository structure:
   ```bash
   ls -la triton_model_repository/latent_encoder/
   # Should have: config.pbtxt and 1/model.py
   ```

2. Check ComfyUI path:
   ```bash
   ls -la triton_model_repository/shared_comfyui/comfy/
   ```

3. Check model files:
   ```bash
   ls -la triton_model_repository/shared_models/
   ```

### Issue 3: Out of Memory

**Error**: `CUDA out of memory`

**Solution**:
1. Reduce instance count in `config.pbtxt`:
   ```protobuf
   instance_group [
     {
       count: 1  # Reduce from higher number
       kind: KIND_GPU
     }
   ]
   ```

2. Increase shared memory:
   ```bash
   docker run --shm-size=2g ...  # Increase from 1g
   ```

### Issue 4: Port Already in Use

**Error**: `bind: address already in use`

**Solution**:
```bash
# Find process using port
sudo lsof -i :8000

# Kill process or use different ports
docker run -p 8003:8000 ...  # Use different host port
```

---

## Testing the Server

### Test Individual Model

```bash
# Test latent_encoder
curl -X POST http://localhost:8000/v2/models/latent_encoder/infer \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": [{
      "name": "image_path",
      "shape": [1],
      "datatype": "BYTES",
      "data": ["/path/to/image.jpg"]
    }]
  }'
```

### Test Ensemble Model

```bash
# Test complete pipeline
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

## Running in Background

### Start in Background

```bash
docker run -d \
  --name triton-server \
  --gpus all \
  --shm-size=1g \
  -p 8000:8000 \
  -p 8001:8001 \
  -p 8002:8002 \
  -v $(pwd)/triton_model_repository:/models \
  nvcr.io/nvidia/tritonserver:25.10-py3 \
  tritonserver --model-repository=/models --log-verbose=1
```

### Stop Server

```bash
docker stop triton-server
docker rm triton-server
```

### View Logs

```bash
docker logs -f triton-server
```

---

## VastAI Specific Notes

### On VastAI Instance

1. **SSH into instance**:
   ```bash
   ssh root@<vastai-ip>
   ```

2. **Navigate to project**:
   ```bash
   cd /root/vtryon2_triton/microservices
   ```

3. **Ensure models are downloaded**:
   ```bash
   ls -la triton_model_repository/shared_models/
   # Should see: vae/, clip/, diffusion_models/, loras/
   ```

4. **Start server**:
   ```bash
   ./start_triton.sh
   # Or use docker run command directly
   ```

5. **Test from local machine**:
   ```bash
   # From your local machine
   curl http://<vastai-ip>:8000/v2/health/ready
   ```

---

## Performance Tuning

### Increase Shared Memory

For large models:
```bash
docker run --shm-size=4g ...
```

### Enable TensorRT (if available)

Add to config.pbtxt:
```protobuf
optimization {
  execution_accelerators {
    gpu_execution_accelerator [
      {
        name: "tensorrt"
      }
    ]
  }
}
```

### Adjust Instance Count

Based on Phase 2 concurrency analysis, adjust in `config.pbtxt`:
```protobuf
instance_group [
  {
    count: 1  # Adjust based on GPU memory and CPU
    kind: KIND_GPU
  }
]
```

---

## Next Steps

1. ✅ Start Triton server
2. ✅ Verify all models load
3. ✅ Test individual models
4. ✅ Test ensemble model
5. ✅ Validate performance

See `PHASE_4_5_COMPLETE.md` for testing details.

