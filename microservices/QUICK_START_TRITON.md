# Quick Start Triton Server - Commands

## Step 1: Check Container Status

```bash
# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# Get container ID
docker ps -q
```

---

## Step 2: Enter Docker Container

```bash
# Enter running container
docker exec -it $(docker ps -q) bash

# Or if you know container name
docker exec -it <container-name> bash

# If container is stopped, start it first
docker start $(docker ps -aq | head -1)
docker exec -it $(docker ps -q) bash
```

---

## Step 3: Inside Container - Check Triton Status

```bash
# Check if Triton process is running
ps aux | grep tritonserver

# Check if port 8000 is listening
netstat -tlnp | grep 8000
# Or
ss -tlnp | grep 8000

# Test health endpoint
curl http://localhost:8000/v2/health/ready
```

---

## Step 4: Start Triton Server (If Not Running)

### Option A: Triton Should Auto-Start

Triton should start automatically when container starts. If it's not running, check logs:

```bash
# Exit container first
exit

# Check container logs
docker logs $(docker ps -q)

# Look for errors
docker logs $(docker ps -q) | grep -i error
```

### Option B: Manual Start (If Needed)

```bash
# Inside container, start Triton manually
tritonserver --model-repository=/models --log-verbose=1 --strict-model-config=false

# Or in background
nohup tritonserver --model-repository=/models --log-verbose=1 --strict-model-config=false > /tmp/triton.log 2>&1 &
```

---

## Step 5: Verify Triton is Running

```bash
# Inside container
curl http://localhost:8000/v2/health/ready

# Should return: {"status":"ready"}

# List models
curl http://localhost:8000/v2/models

# Check process
ps aux | grep tritonserver
```

---

## Complete Quick Start Sequence

```bash
# 1. Check container
docker ps

# 2. Enter container
docker exec -it $(docker ps -q) bash

# 3. Inside container - check Triton
ps aux | grep triton
curl http://localhost:8000/v2/health/ready

# 4. If not running, check logs (exit container first)
exit
docker logs $(docker ps -q) | tail -50

# 5. Restart container if needed
docker restart $(docker ps -q)

# 6. Wait 30 seconds, then test
sleep 30
docker exec $(docker ps -q) curl http://localhost:8000/v2/health/ready
```

---

## Troubleshooting

### Container Not Running

```bash
# Start container
docker start $(docker ps -aq | head -1)

# Or create new
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

### Triton Not Starting

```bash
# Check logs
docker logs $(docker ps -q) | tail -100

# Common issues:
# - Missing models (check /models/shared_models/)
# - GPU not available
# - Port conflict
# - Memory issues
```

### Models Missing

```bash
# Inside container
ls -la /models/shared_models/

# If empty, download models
/workspace/download_triton_models.sh
```

---

## Quick Reference

```bash
# Enter container
docker exec -it $(docker ps -q) bash

# Check Triton
ps aux | grep triton
curl http://localhost:8000/v2/health/ready

# Restart container
docker restart $(docker ps -q)

# View logs
docker logs -f $(docker ps -q)
```

