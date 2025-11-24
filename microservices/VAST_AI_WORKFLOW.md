# Vast AI Workflow (No Host Access)

## Overview
Since Vast AI doesn't provide persistent host access, we use a rebuild-and-redeploy workflow.

---

## 🔄 Workflow

```
1. Build & Push Image
   ↓
2. Create Vast AI Instance
   ↓
3. Debug & Fix (inside container)
   ↓
4. Sync Fixes Back (docker cp via SSH)
   ↓
5. Rebuild & Push New Image
   ↓
6. Destroy Old Instance
   ↓
7. Create New Instance with Updated Image
   ↓
8. Repeat from step 3 if needed
```

---

## 📦 Step 1: Build & Push Image

```bash
# Make sure all local changes are committed
git status

# Build and push
./push_image.sh <registry> <tag>

# Example:
./push_image.sh docker.io/username v1.0
```

**What it does:**
- Builds Docker image from Dockerfile.triton
- Tags with registry and version
- Pushes to registry

---

## 🚀 Step 2: Create Vast AI Instance

1. Go to Vast AI dashboard
2. Create new instance:
   - **Image**: Use your pushed image (`<registry>/vtryon-triton:<tag>`)
   - **GPU**: Select appropriate GPU (24GB+ recommended)
   - **Ports**: Expose 8000, 8001, 8002
3. Note the IP address

---

## 🐛 Step 3: Debug & Fix

### Connect to Vast AI

```bash
# SSH into instance
ssh root@<vast-ai-ip>

# Or use Vast AI web terminal
```

### Debug Commands

```bash
# Check container
docker ps
docker logs <container-name> -f

# Enter container
docker exec -it <container-name> bash

# Inside container - make fixes
vi /models/latent_encoder/1/model.py
# ... make changes ...

# Test fixes (restart container)
exit
docker restart <container-name>

# Check if fix works
curl http://localhost:8000/v2/health/ready
```

### Common Debugging

```bash
# Check logs for errors
docker logs <container-name> 2>&1 | grep -i error

# Test imports
docker exec <container-name> python3 -c "
import sys
sys.path.insert(0, '/workspace/shared_comfyui')
sys.path.insert(0, '/models/latent_encoder/1')
from service import encode_image_to_latent
print('OK')
"

# Check file paths
docker exec <container-name> ls -la /workspace/shared_comfyui
docker exec <container-name> ls -la /workspace/shared_models
```

---

## 📥 Step 4: Sync Fixes Back

### Option 1: Using Script (Recommended)

```bash
# From your local machine
./sync_fixes_from_vastai.sh <vast-ai-ip> [container-name]

# Example:
./sync_fixes_from_vastai.sh 123.45.67.89
```

**What it does:**
- Connects to Vast AI via SSH
- Copies fixed files from container
- Shows changes
- Optionally commits to git

### Option 2: Manual Sync

```bash
# From your local machine, via SSH
ssh root@<vast-ai-ip> "docker cp <container>:/models/latent_encoder/1/model.py /tmp/model.py"
scp root@<vast-ai-ip>:/tmp/model.py ./triton_model_repository/latent_encoder/1/model.py
ssh root@<vast-ai-ip> "rm /tmp/model.py"
```

### Option 3: Direct Copy (if you have direct access)

```bash
# If you can run docker commands directly on Vast AI
docker cp <container>:/models/latent_encoder/1/model.py ./triton_model_repository/latent_encoder/1/model.py
```

---

## 🔨 Step 5: Rebuild & Push

```bash
# Review changes
git diff triton_model_repository/

# Commit if needed
git add triton_model_repository/
git commit -m "Fix: <description>"
git push

# Rebuild and push new image
./push_image.sh <registry> <new-tag>

# Example:
./push_image.sh docker.io/username v1.1
```

---

## 🔄 Step 6: Redeploy

1. **Destroy old Vast AI instance**
2. **Create new instance** with updated image
3. **Test** - repeat from Step 3 if needed

---

## 📝 Best Practices

### 1. Version Your Images

```bash
# Use version tags
./push_image.sh docker.io/username v1.0
./push_image.sh docker.io/username v1.1
./push_image.sh docker.io/username v1.2
```

### 2. Document Fixes

```bash
# Commit with descriptive messages
git commit -m "Fix: Corrected batch dimension handling in sampling model"
git commit -m "Fix: Updated COMFYUI_PATH usage in service.py"
```

### 3. Test Before Pushing

```bash
# Test locally if possible
docker build -f Dockerfile.triton -t vtryon-triton:test .
docker run --gpus all -p 8000:8000 vtryon-triton:test
```

### 4. Keep Logs

```bash
# Save logs from Vast AI
ssh root@<vast-ai-ip> "docker logs <container>" > vastai_logs_$(date +%Y%m%d_%H%M%S).txt
```

---

## 🚨 Troubleshooting

### Can't Connect to Vast AI

```bash
# Check SSH key
ssh-add -l

# Test connection
ssh -v root@<vast-ai-ip>
```

### Container Not Found

```bash
# List containers on Vast AI
ssh root@<vast-ai-ip> "docker ps -a"
```

### Files Not Syncing

```bash
# Check file exists in container
ssh root@<vast-ai-ip> "docker exec <container> ls -la /models/latent_encoder/1/"

# Check permissions
ssh root@<vast-ai-ip> "docker exec <container> cat /models/latent_encoder/1/model.py | head -5"
```

---

## 📊 Iteration Tracking

Keep a log of iterations:

```markdown
## Iteration Log

### v1.0 (Initial)
- Status: Deployed
- Issues: Models not loading
- Fixes: Fixed COMFYUI_PATH in service.py

### v1.1
- Status: Testing
- Issues: Batch dimension errors
- Fixes: Fixed batch handling in all models

### v1.2
- Status: Production
- Issues: None
- Fixes: All fixes applied
```

---

## ⚡ Quick Reference

```bash
# Build & Push
./push_image.sh <registry> <tag>

# Sync Fixes
./sync_fixes_from_vastai.sh <vast-ai-ip>

# Check Status
ssh root@<vast-ai-ip> "docker ps && docker logs <container> | tail -20"

# Test Health
ssh root@<vast-ai-ip> "curl http://localhost:8000/v2/health/ready"
```

---

## Summary

This workflow works well for Vast AI's constraints:
- ✅ No host access needed
- ✅ Changes are version controlled
- ✅ Easy to iterate
- ✅ Can test fixes before committing
- ✅ Full audit trail via git

The key is: **Fix → Sync → Commit → Rebuild → Redeploy**


