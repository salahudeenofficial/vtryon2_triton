# Troubleshooting Stuck Download

## Quick Diagnostic Steps

### 1. Check if Download Script is Running

```bash
# Check if the process is still active
ps aux | grep download_triton_models

# Check for any download/wget/curl processes
ps aux | grep -E "wget|curl|download"
```

### 2. Check Network Connectivity

```bash
# Test internet connection
ping -c 3 8.8.8.8

# Test HuggingFace connectivity
curl -I https://huggingface.co

# Test specific model URL
curl -I https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors
```

### 3. Check Current Download Status

```bash
# Check file sizes
du -sh /models/shared_models/*

# Check if VAE file is still growing
ls -lh /models/shared_models/vae/

# Check disk space
df -h
```

### 4. Check Container Logs

```bash
# View container logs for errors
docker logs $(docker ps -q)

# Or if you know container name
docker logs <container-name>
```

### 5. Check for Errors in Download Script

```bash
# If script is running in a terminal, check for error messages
# Look for:
# - Connection timeout
# - 404 Not Found
# - Network errors
```

---

## Solutions

### Solution 1: Restart Download Script

If the script stopped:

```bash
# Enter container
docker exec -it $(docker ps -q) bash

# Navigate to workspace
cd /workspace

# Check what's already downloaded
ls -lh /models/shared_models/*/

# Re-run download script
/workspace/download_triton_models.sh

# Exit when done
exit
```

### Solution 2: Manual Download (If Script Fails)

Download models manually:

```bash
# Enter container
docker exec -it $(docker ps -q) bash

# Create directories if needed
mkdir -p /models/shared_models/vae
mkdir -p /models/shared_models/clip
mkdir -p /models/shared_models/diffusion_models
mkdir -p /models/shared_models/loras

# Download VAE (if not complete)
cd /models/shared_models/vae
wget -c https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors

# Check download script for other URLs
cat /workspace/download_triton_models.sh

# Exit
exit
```

### Solution 3: Check Disk Space

```bash
# Check available disk space
df -h

# Check if /models is full
du -sh /models/*

# If disk is full, you may need to:
# - Clean up old files
# - Use a different location
# - Increase VastAI instance storage
```

### Solution 4: Resume Interrupted Download

If download was interrupted:

```bash
# Enter container
docker exec -it $(docker ps -q) bash

# Use wget with resume option
cd /models/shared_models/vae
wget -c https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors

# -c flag resumes partial downloads
exit
```

### Solution 5: Check Download Script Content

```bash
# View the download script to see what it's trying to download
cat /workspace/download_triton_models.sh

# Or if script is in container
docker exec $(docker ps -q) cat /workspace/download_triton_models.sh
```

---

## Common Issues

### Issue 1: Network Timeout

**Symptoms**: Download stops, no error message

**Solution**:
```bash
# Increase timeout and retry
wget --timeout=300 --tries=3 <url>
```

### Issue 2: HuggingFace Rate Limiting

**Symptoms**: 429 errors, connection refused

**Solution**:
- Wait 5-10 minutes
- Use HuggingFace authentication token
- Try again later

### Issue 3: Disk Space Full

**Symptoms**: "No space left on device"

**Solution**:
```bash
# Check space
df -h

# Clean up if needed
docker system prune
```

### Issue 4: Container Stopped

**Symptoms**: Can't exec into container

**Solution**:
```bash
# Check container status
docker ps -a

# Restart container
docker start $(docker ps -aq)
```

---

## Quick Recovery Steps

1. **Check what's running**:
   ```bash
   ps aux | grep download
   ```

2. **Check current status**:
   ```bash
   du -sh /models/shared_models/*
   ls -lh /models/shared_models/vae/
   ```

3. **If script stopped, restart**:
   ```bash
   docker exec -it $(docker ps -q) /workspace/download_triton_models.sh
   ```

4. **If network issue, wait and retry**:
   ```bash
   # Wait 5 minutes, then check again
   sleep 300
   du -sh /models/shared_models/*
   ```

5. **Manual download if needed**:
   ```bash
   docker exec -it $(docker ps -q) bash
   cd /models/shared_models/vae
   wget -c <url>
   ```

---

## Next Steps

After fixing the issue:

1. ✅ Verify download completes
2. ✅ Check all files are present
3. ✅ Restart container
4. ✅ Test Triton server

