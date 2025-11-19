# Running Triton on VastAI: Docker Considerations

## Understanding VastAI Instance Types

VastAI instances typically come in two configurations:

### 1. **Standard VastAI Instance (Most Common)**
- **Type**: Virtual Machine (VM) or bare metal with Docker installed
- **Docker Access**: Docker daemon runs on the host
- **Running Containers**: You can run Docker containers normally
- **GPU Access**: Direct GPU access via `--gpus=all`

**This is the standard setup and works perfectly for running Triton.**

### 2. **Containerized VastAI Instance (Less Common)**
- **Type**: VastAI instance itself is a Docker container
- **Docker Access**: Requires Docker-in-Docker (DinD) or Docker socket mounting
- **Running Containers**: Requires special configuration
- **GPU Access**: May need additional setup

---

## Solution 1: Standard VastAI Instance (Recommended)

If your VastAI instance has Docker installed (which is standard), you can run Triton container directly:

### Check if Docker is Available

```bash
# SSH into VastAI instance
ssh root@<vastai-ip>

# Check Docker
docker --version
docker ps

# Check GPU access
nvidia-smi
```

### Run Triton Container (Standard Approach)

```bash
cd /workspace/vtryon2_triton/microservices

# Pull Triton image
docker pull nvcr.io/nvidia/tritonserver:25.10-py3

# Run Triton container
docker run --gpus=all \
  --shm-size=1g \
  -p 8000:8000 \
  -p 8001:8001 \
  -p 8002:8002 \
  -v $(pwd)/triton_model_repository:/models \
  nvcr.io/nvidia/tritonserver:25.10-py3 \
  tritonserver --model-repository=/models \
  --log-verbose=1
```

**This works because:**
- Docker daemon runs on the VastAI host
- GPU access is available via `--gpus=all`
- Volume mounts work normally
- No special configuration needed

---

## Solution 2: Containerized VastAI Instance (Docker-in-Docker)

If your VastAI instance IS a Docker container, you have two options:

### Option A: Mount Docker Socket (Easier)

This allows the container to use the host's Docker daemon:

```bash
# Inside VastAI container, run Triton with Docker socket mounted
docker run --gpus=all \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/triton_model_repository:/models \
  -p 8000:8000 -p 8001:8001 -p 8002:8002 \
  nvcr.io/nvidia/tritonserver:25.10-py3 \
  tritonserver --model-repository=/models
```

**Note**: This requires the VastAI container to have access to `/var/run/docker.sock`.

### Option B: Install Triton Directly (No Docker)

If Docker-in-Docker is problematic, install Triton directly on the VastAI instance:

```bash
# Install Triton server directly (not in Docker)
# This is more complex but avoids Docker-in-Docker issues

# Download Triton server binary
wget https://github.com/triton-inference-server/server/releases/download/v2.45.0/tritonserver-2.45.0-ubuntu2004.tar.gz
tar -xzf tritonserver-2.45.0-ubuntu2004.tar.gz

# Run Triton directly
./tritonserver/bin/tritonserver --model-repository=./triton_model_repository
```

**Pros:**
- No Docker-in-Docker complexity
- Direct GPU access
- Simpler setup

**Cons:**
- Need to install dependencies manually
- More setup steps
- Less portable

---

## Recommended Approach

### For Most VastAI Instances (Standard Setup):

**Use Docker container approach** - This is what our current plan assumes:

```bash
# 1. Pull Triton image
docker pull nvcr.io/nvidia/tritonserver:25.10-py3

# 2. Run using the start_triton.sh script
cd microservices
./start_triton.sh
```

The `start_triton.sh` script (created by `setup_triton_vastai.sh`) handles this automatically.

---

## Verification Steps

### 1. Check Your VastAI Instance Type

```bash
# Check if you're in a container
cat /proc/1/cgroup | grep docker

# If output shows "docker", you're in a container
# If no output, you're on a VM/host
```

### 2. Check Docker Availability

```bash
# Check Docker
docker --version
docker ps

# Check GPU access
nvidia-smi
```

### 3. Test Triton Container

```bash
# Quick test
docker run --rm --gpus=all nvcr.io/nvidia/tritonserver:25.10-py3 \
  tritonserver --help
```

If this works, you can run Triton in Docker normally.

---

## Troubleshooting

### Issue: "Cannot connect to Docker daemon"

**Solution**: Your VastAI instance might be a container. Try:
1. Mount Docker socket: `-v /var/run/docker.sock:/var/run/docker.sock`
2. Or install Triton directly (Option B above)

### Issue: "No GPU devices found"

**Solution**: 
1. Check `nvidia-smi` works
2. Ensure `--gpus=all` flag is used
3. Check NVIDIA Container Toolkit is installed: `nvidia-container-cli --version`

### Issue: "Permission denied" for Docker socket

**Solution**:
```bash
# Add user to docker group (if not root)
sudo usermod -aG docker $USER
# Or run with sudo (not recommended)
```

---

## Updated Workflow

Based on your VastAI instance type:

### Standard VastAI (VM with Docker):
```bash
# Use existing setup_triton_vastai.sh
./setup_triton_vastai.sh
./start_triton.sh
```

### Containerized VastAI:
```bash
# Option 1: Mount Docker socket
docker run --gpus=all -v /var/run/docker.sock:/var/run/docker.sock ...

# Option 2: Install Triton directly
# Follow Option B instructions above
```

---

## Summary

**Yes, you can run Triton by pulling the Docker image on VastAI**, but:

1. **Most VastAI instances** are VMs with Docker installed → **Works normally**
2. **If VastAI is a container** → Use Docker socket mounting or install Triton directly
3. **Current plan assumes standard setup** → Should work for 95% of cases

**Recommendation**: Try the standard Docker approach first. If it doesn't work, check if you're in a container and use the appropriate solution above.

