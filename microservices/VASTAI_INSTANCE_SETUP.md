# VastAI Instance Setup Guide - Step by Step

## Your Docker Image
- **Image Name**: `salafashionx/vtryon-triton:latest`
- **Size**: 17.9GB
- **Status**: ✅ Successfully pushed to DockerHub

---

## Step-by-Step: Create VastAI Instance

### Step 1: Go to VastAI Website

1. Open your browser and go to: **https://vast.ai**
2. Log in to your VastAI account
3. Click on **"Create"** or **"Rent"** button (usually in the top navigation)

---

### Step 2: Select GPU Instance

1. **Filter for GPU instances**:
   - Look for instances with:
     - **RTX 3090** (24GB VRAM) - Minimum recommended
     - **RTX 4090** (24GB VRAM) - Recommended
     - **A100** (40GB/80GB VRAM) - Best performance
   - **Avoid**: RTX 3060, RTX 3080 (may not have enough VRAM)

2. **Check instance details**:
   - GPU: RTX 3090/4090 or A100
   - Storage: At least **50GB** free (for models)
   - RAM: 32GB+ recommended
   - Docker: Should be pre-installed

3. **Click "Rent"** on your chosen instance

---

### Step 3: Configure Docker Container

After selecting an instance, you'll see a configuration page. Fill in the following:

#### A. Docker Image
```
salafashionx/vtryon-triton:latest
```

#### B. Ports Configuration
Add these three ports:

| Container Port | Host Port | Description |
|---------------|-----------|-------------|
| `8000` | `8000` | HTTP API |
| `8001` | `8001` | gRPC API |
| `8002` | `8002` | Metrics |

**How to add ports in VastAI:**
- Look for "Ports" or "Port Mapping" section
- Click "Add Port" or "+"
- Enter: `8000:8000`, `8001:8001`, `8002:8002`
- Or enter each separately:
  - Container: `8000`, Host: `8000`
  - Container: `8001`, Host: `8001`
  - Container: `8002`, Host: `8002`

#### C. GPU Access
- Enable **GPU access** (usually a checkbox)
- Select **"All GPUs"** or **"GPU 0"** if only one GPU

#### D. Environment Variables (Optional)
Add these if there's an "Environment Variables" section:
```
TRITON_MODEL_REPOSITORY=/models
PYTHONUNBUFFERED=1
```

#### E. Volume Mounts (Optional - for models)
If you want to mount models from host:
- **Host Path**: `/workspace/models`
- **Container Path**: `/models/shared_models`
- **Mode**: `rw` (read-write)

**Note**: Models are NOT in the image. You'll download them after starting the instance.

#### F. Shared Memory (if available)
- Set **Shared Memory**: `4g` or `4096` (if there's a field for it)

---

### Step 4: Start the Instance

1. Review your configuration
2. Click **"Start"** or **"Launch"** button
3. Wait for the instance to start (usually 1-2 minutes)

---

### Step 5: Access Your Instance

After the instance starts:

1. **Get the SSH connection details**:
   - VastAI will show you:
     - SSH command: `ssh root@<vastai-ip> -p <port>`
     - Or use VastAI's web terminal

2. **Connect via SSH** (or use web terminal):
   ```bash
   ssh root@<vastai-ip> -p <port>
   ```

---

### Step 6: Verify Container is Running

Once connected to the instance:

```bash
# Check if container is running
docker ps

# You should see your container running
# If not, check what happened:
docker ps -a
docker logs <container-name>
```

---

### Step 7: Download Models (Required)

Models are NOT included in the Docker image. You need to download them:

```bash
# Enter the running container
docker exec -it <container-name> bash

# Inside container, download models
cd /workspace
/workspace/download_triton_models.sh

# Wait for download to complete (this may take 10-30 minutes)
# Exit container
exit

# Restart container to load models
docker restart <container-name>
```

**Alternative**: If the download script doesn't exist, you can download models manually or mount them from host.

---

### Step 8: Verify Triton Server is Running

```bash
# Check server health
curl http://localhost:8000/v2/health/ready

# Should return: {"status":"ready"}

# List available models
curl http://localhost:8000/v2/models

# Should show:
# - latent_encoder
# - text_encoder
# - sampling
# - decoding
# - vtryon_pipeline (ensemble)
```

---

### Step 9: Test from Your Local Machine

Get the **public IP** and **port** from VastAI dashboard:

```bash
# Replace <vastai-ip> and <port> with your instance details
curl http://<vastai-ip>:<port>/v2/health/ready

# List models
curl http://<vastai-ip>:<port>/v2/models
```

**Note**: VastAI may assign different external ports. Check the VastAI dashboard for the actual external port mappings.

---

## Quick Reference: Docker Run Command

If you prefer to run the container manually via SSH:

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

## Troubleshooting

### Container Not Starting
```bash
# Check logs
docker logs <container-name>

# Check if image was pulled
docker images | grep vtryon-triton
```

### Models Not Found
```bash
# Check if models directory exists
docker exec <container-name> ls -la /models/shared_models/

# Download models (see Step 7)
```

### GPU Not Available
```bash
# Check GPU access
docker exec <container-name> nvidia-smi

# Verify CUDA
docker exec <container-name> /opt/venv/bin/python -c "import torch; print(torch.cuda.is_available())"
```

### Port Not Accessible
- Check VastAI firewall settings
- Verify port mappings in VastAI dashboard
- Test locally first: `curl http://localhost:8000/v2/health/ready`

---

## Expected Results

After successful setup:

1. ✅ Container running: `docker ps` shows your container
2. ✅ Server ready: `curl http://localhost:8000/v2/health/ready` returns `{"status":"ready"}`
3. ✅ Models loaded: `curl http://localhost:8000/v2/models` shows all 5 models
4. ✅ GPU accessible: `nvidia-smi` works inside container
5. ✅ External access: Can access from your local machine using VastAI IP

---

## Next Steps

1. ✅ Instance created and running
2. ✅ Models downloaded
3. ✅ Server verified
4. 🔄 Test inference with your API
5. 🔄 Monitor performance and costs

---

## Cost Estimation

- **RTX 3090**: ~$0.20-0.40/hour
- **RTX 4090**: ~$0.30-0.60/hour
- **A100**: ~$1.00-2.00/hour

**Remember to stop the instance when not in use to save costs!**

---

## Support

If you encounter issues:
1. Check container logs: `docker logs <container-name>`
2. Check Triton logs: `docker exec <container-name> cat /var/log/triton.log`
3. Verify image: `docker pull salafashionx/vtryon-triton:latest`
4. Review this guide's troubleshooting section

