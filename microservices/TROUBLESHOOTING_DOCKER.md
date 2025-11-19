# Troubleshooting Docker on VastAI

## Error: Docker daemon not running

If you see:
```
docker: failed to connect to the docker API at unix:///var/run/docker.sock
```

This means Docker is not installed or the daemon is not running.

---

## Solution 1: Install Docker (if not installed)

### Check if Docker is installed

```bash
which docker
docker --version
```

If Docker is not installed:

```bash
# Update package list
apt-get update

# Install Docker
apt-get install -y docker.io

# Start Docker service
systemctl start docker
systemctl enable docker

# Verify Docker is running
systemctl status docker
```

---

## Solution 2: Start Docker Daemon

If Docker is installed but not running:

```bash
# Start Docker service
systemctl start docker

# Enable Docker to start on boot
systemctl enable docker

# Verify it's running
systemctl status docker
```

---

## Solution 3: Install Docker with GPU Support

For VastAI instances, you may need NVIDIA Container Toolkit:

```bash
# Install Docker
apt-get update
apt-get install -y docker.io

# Install NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list

apt-get update
apt-get install -y nvidia-container-toolkit

# Restart Docker
systemctl restart docker

# Verify GPU access
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
```

---

## Solution 4: Use Rootless Docker (Alternative)

If you can't use system Docker:

```bash
# Install rootless Docker
curl -fsSL https://get.docker.com/rootless | sh

# Add to PATH
export PATH=$HOME/bin:$PATH

# Start Docker daemon
dockerd-rootless.sh --experimental &

# Verify
docker ps
```

---

## Verify Docker is Working

### Test 1: Basic Docker

```bash
docker run hello-world
```

### Test 2: GPU Access

```bash
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
```

If this works, you're ready to start Triton!

---

## Quick Fix Script

Run this to install and start Docker:

```bash
#!/bin/bash
# Quick Docker setup for VastAI

echo "Checking Docker installation..."

if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    apt-get update
    apt-get install -y docker.io
fi

echo "Starting Docker service..."
systemctl start docker
systemctl enable docker

echo "Verifying Docker..."
docker --version
docker ps

echo "Testing GPU access..."
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi

echo "✓ Docker is ready!"
```

---

## After Docker is Running

Once Docker is working, start Triton:

```bash
cd /workspace/vtryon2_triton/microservices
./start_triton.sh
```

Or manually:

```bash
docker run --gpus all \
  --shm-size=2g \
  -p 8000:8000 \
  -p 8001:8001 \
  -p 8002:8002 \
  -v $(pwd)/triton_model_repository:/models \
  nvcr.io/nvidia/tritonserver:25.10-py3 \
  tritonserver --model-repository=/models --log-verbose=1
```

---

## Common Issues

### Issue: Permission Denied

```bash
# Add user to docker group (if not root)
usermod -aG docker $USER
newgrp docker

# Or use sudo
sudo docker run ...
```

### Issue: Cannot connect to Docker daemon

```bash
# Check if Docker service is running
systemctl status docker

# Start it if not running
systemctl start docker

# Check Docker socket
ls -la /var/run/docker.sock
```

### Issue: GPU not accessible in Docker

```bash
# Install NVIDIA Container Toolkit
apt-get install -y nvidia-container-toolkit
systemctl restart docker

# Test GPU access
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
```

---

## VastAI Specific Notes

Some VastAI instances may have Docker pre-installed but not running. Try:

```bash
# Check Docker status
systemctl status docker

# Start if stopped
systemctl start docker

# If systemctl doesn't work, try service command
service docker start

# Or try direct start
dockerd &
```

If Docker is not available, contact VastAI support or use a different instance with Docker pre-installed.

