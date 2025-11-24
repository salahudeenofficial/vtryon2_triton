# Troubleshooting: Connection Refused on Port 8000

## Error: `curl: (7) Failed to connect to localhost port 8000`

This means Triton server is not running or not accessible.

---

## Step 1: Check Container Status

```bash
# Check if container is running
docker ps

# Check all containers (including stopped)
docker ps -a
```

**Expected**: You should see a container running with image `salafashionx/vtryon-triton:latest`

**If no container running**: You need to start it.

---

## Step 2: Check Container Logs

```bash
# View recent logs
docker logs $(docker ps -aq | head -1)

# Or if you know container name
docker logs <container-name>

# Follow logs in real-time
docker logs -f $(docker ps -aq | head -1)
```

**Look for**:
- ✅ "Triton Inference Server started"
- ✅ "Server is ready"
- ❌ Error messages
- ❌ "Failed to start"
- ❌ Port binding errors

---

## Step 3: Start Container (If Not Running)

### Option A: Container Exists But Stopped

```bash
# Start existing container
docker start $(docker ps -aq | head -1)

# Or by name
docker start <container-name>
```

### Option B: No Container Exists - Create New One

```bash
# Run container
docker run -d \
  --name vtryon-triton \
  --gpus all \
  --shm-size=4g \
  --restart unless-stopped \
  -p 8000:8000 \
  -p 8001:8001 \
  -p 8002:8002 \
  salafashionx/vtryon-triton:latest

# Check if it started
docker ps
```

---

## Step 4: Verify Port Mapping

```bash
# Check if ports are mapped
docker ps --format "table {{.Names}}\t{{.Ports}}"

# Should show: 0.0.0.0:8000->8000/tcp, etc.
```

**If ports not mapped**: Container was started without port mapping. Restart with ports:

```bash
# Stop container
docker stop $(docker ps -q)

# Remove container
docker rm $(docker ps -aq | head -1)

# Start with ports
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

## Step 5: Check Triton Server Inside Container

```bash
# Enter container
docker exec -it $(docker ps -q) bash

# Check if Triton process is running
ps aux | grep tritonserver

# Check if port 8000 is listening
netstat -tlnp | grep 8000
# Or
ss -tlnp | grep 8000

# Exit container
exit
```

---

## Step 6: Common Issues and Solutions

### Issue 1: Container Not Running

**Solution**:
```bash
docker start $(docker ps -aq | head -1)
```

### Issue 2: Container Crashed

**Check logs**:
```bash
docker logs $(docker ps -aq | head -1)
```

**Common causes**:
- Missing models (Triton fails to start)
- GPU not available
- Port already in use
- Out of memory

**Solution**: Fix the issue and restart:
```bash
docker restart $(docker ps -aq | head -1)
```

### Issue 3: Ports Not Mapped

**Check**:
```bash
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

**Solution**: Restart container with port mapping (see Step 4)

### Issue 4: Triton Server Not Started

**Check inside container**:
```bash
docker exec $(docker ps -q) ps aux | grep triton
```

**If not running**, check logs for errors:
```bash
docker logs $(docker ps -q) | tail -50
```

### Issue 5: Models Missing (Triton Won't Start)

**Check**:
```bash
docker exec $(docker ps -q) ls -la /models/shared_models/
```

**If empty**: Download models first (see download guide)

---

## Quick Diagnostic Commands

```bash
# 1. Check container status
docker ps -a

# 2. Check logs
docker logs $(docker ps -aq | head -1) | tail -50

# 3. Check ports
docker ps --format "table {{.Names}}\t{{.Ports}}"

# 4. Check if Triton is running inside
docker exec $(docker ps -q) ps aux | grep triton

# 5. Test from inside container
docker exec $(docker ps -q) curl http://localhost:8000/v2/health/ready
```

---

## Step-by-Step Recovery

### If Container Doesn't Exist:

```bash
# 1. Pull image (if not local)
docker pull salafashionx/vtryon-triton:latest

# 2. Run container
docker run -d \
  --name vtryon-triton \
  --gpus all \
  --shm-size=4g \
  --restart unless-stopped \
  -p 8000:8000 \
  -p 8001:8001 \
  -p 8002:8002 \
  salafashionx/vtryon-triton:latest

# 3. Wait 30 seconds
sleep 30

# 4. Check logs
docker logs vtryon-triton

# 5. Test
curl http://localhost:8000/v2/health/ready
```

### If Container Exists But Stopped:

```bash
# 1. Start container
docker start $(docker ps -aq | head -1)

# 2. Wait 30 seconds
sleep 30

# 3. Check logs
docker logs -f $(docker ps -q)

# 4. Test
curl http://localhost:8000/v2/health/ready
```

### If Container Running But No Response:

```bash
# 1. Check logs for errors
docker logs $(docker ps -q) | tail -100

# 2. Check if Triton process exists
docker exec $(docker ps -q) ps aux | grep triton

# 3. Restart container
docker restart $(docker ps -q)

# 4. Wait and test
sleep 30
curl http://localhost:8000/v2/health/ready
```

---

## Expected Behavior

After container starts:

1. **0-10 seconds**: Container starting, Triton initializing
2. **10-30 seconds**: Triton scanning model repository
3. **30-60 seconds**: Models loading (if present)
4. **60+ seconds**: Server ready

**Test every 10 seconds** until you get a response:
```bash
curl http://localhost:8000/v2/health/ready
```

---

## Next Steps

Once you get a response:

1. ✅ Check health: `curl http://localhost:8000/v2/health/ready`
2. ✅ List models: `curl http://localhost:8000/v2/models`
3. ✅ Verify all models loaded
4. ✅ Test inference

