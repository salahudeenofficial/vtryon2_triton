# VastAI Launch Mode Configuration

## ✅ Recommended Launch Mode

**Select: "Docker" or "Docker Container"**

This is the correct launch mode for your Triton server Docker image.

---

## Why Docker Mode?

Your setup requires:
- ✅ Full Docker container support
- ✅ GPU access (`--gpus all`)
- ✅ Port mapping (8000, 8001, 8002)
- ✅ Volume mounts (for models)
- ✅ Custom Docker run commands

**Docker mode** provides all of these capabilities.

---

## Complete VastAI Configuration

### Launch Mode
```
Docker / Docker Container
```

### Docker Image
```
salafashionx/vtryon-triton:latest
```

### Ports
Add these three port mappings:

| Container Port | Host Port | Protocol | Description |
|---------------|-----------|----------|-------------|
| `8000` | `8000` | TCP | HTTP API |
| `8001` | `8001` | TCP | gRPC API |
| `8002` | `8002` | TCP | Metrics |

**How to add in VastAI:**
- Look for "Ports" or "Port Mapping" section
- Click "Add Port" or "+" button
- Enter each port mapping:
  - Container: `8000`, Host: `8000`
  - Container: `8001`, Host: `8001`
  - Container: `8002`, Host: `8002`

### GPU Configuration
- ✅ **Enable GPU**: Check this box
- **GPU Selection**: 
  - "All GPUs" (if multiple GPUs)
  - "GPU 0" (if single GPU)

### Advanced Options (if available)

#### Shared Memory
```
4g
```
or
```
4096
```

#### Environment Variables
Add these if there's an environment variables section:
```
TRITON_MODEL_REPOSITORY=/models
PYTHONUNBUFFERED=1
```

#### Volume Mounts (Optional)
If you want to mount models from host:
- **Host Path**: `/workspace/models`
- **Container Path**: `/models/shared_models`
- **Mode**: `rw` (read-write)

**Note**: Models are NOT in the image. You'll download them after the container starts.

---

## What NOT to Use

### ❌ Jupyter Mode
- This is for Jupyter notebooks only
- Won't work with your Docker container

### ❌ SSH Mode
- Just provides SSH access
- Doesn't automatically run your Docker container
- You'd have to manually run `docker run` commands

### ❌ Custom Mode
- Only use if you need special startup scripts
- Not needed for standard Docker containers

---

## After Launch Mode Selection

Once you select "Docker" mode:

1. **Enter your Docker image**: `salafashionx/vtryon-triton:latest`
2. **Configure ports**: 8000, 8001, 8002
3. **Enable GPU**: Check the box
4. **Click "Start" or "Launch"**

---

## Verification After Start

Once the instance starts, verify it's running:

```bash
# SSH into the instance
ssh root@<vastai-ip> -p <port>

# Check if container is running
docker ps

# Check container logs
docker logs <container-name>

# Test Triton server
curl http://localhost:8000/v2/health/ready
```

---

## Troubleshooting

### Container Not Starting
- Check Docker image name is correct: `salafashionx/vtryon-triton:latest`
- Verify you selected "Docker" launch mode
- Check logs: `docker logs <container-name>`

### GPU Not Available
- Ensure GPU is enabled in VastAI configuration
- Check inside container: `docker exec <container> nvidia-smi`

### Ports Not Accessible
- Verify port mappings in VastAI dashboard
- Check VastAI firewall settings
- Test locally first: `curl http://localhost:8000/v2/health/ready`

---

## Quick Reference

**Launch Mode**: Docker  
**Image**: `salafashionx/vtryon-triton:latest`  
**Ports**: 8000, 8001, 8002  
**GPU**: Enabled  
**Shared Memory**: 4g (optional)

---

## Next Steps

After configuring launch mode:

1. ✅ Select "Docker" launch mode
2. ✅ Enter Docker image
3. ✅ Configure ports
4. ✅ Enable GPU
5. ✅ Start instance
6. 🔄 Download models (after container starts)
7. 🔄 Test Triton server

