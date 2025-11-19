# Quick Triton Installation Guide

## Problem
- Docker daemon not available (containerized VastAI)
- Direct download links not working
- Podman has permission issues

## Solution: Use PyTriton (Simplest Method)

**This is the recommended approach - it's the simplest and most reliable.**

```bash
cd /workspace/vtryon2_triton/microservices
chmod +x install_triton_via_pytriton.sh
./install_triton_via_pytriton.sh
```

**What it does:**
- Installs `nvidia-pytriton` via pip
- Includes Triton Inference Server binaries
- Works on Ubuntu 24.04
- No Docker, no podman, no downloads needed
- Just `pip install` and you're done

**After installation:**
```bash
# Start Triton
./start_triton_direct.sh

# Verify
tritonserver --version
```

---

## Why PyTriton?

1. ✅ **Simplest**: Just `pip install nvidia-pytriton`
2. ✅ **Includes binaries**: Triton server is included
3. ✅ **Works everywhere**: No Docker, no special tools needed
4. ✅ **Official**: Maintained by NVIDIA
5. ✅ **Latest version**: Always up-to-date

---

## Alternative Methods (if PyTriton doesn't work)

### Option 1: Fix Podman Permissions

If you want to use podman method, try:

```bash
# Configure podman for rootless (if not root)
podman system migrate

# Or use sudo
sudo podman pull nvcr.io/nvidia/tritonserver:25.10-py3
```

### Option 2: Manual Image Transfer

If you have access to a machine with Docker:

1. **On machine with Docker:**
   ```bash
   docker pull nvcr.io/nvidia/tritonserver:25.10-py3
   docker run --rm -v $(pwd):/output nvcr.io/nvidia/tritonserver:25.10-py3 \
     sh -c "cp -r /opt/tritonserver /output/"
   tar -czf tritonserver.tar.gz tritonserver/
   ```

2. **Transfer to VastAI:**
   ```bash
   scp tritonserver.tar.gz root@<vastai-ip>:/workspace/vtryon2_triton/microservices/
   ```

3. **On VastAI:**
   ```bash
   cd /workspace/vtryon2_triton/microservices
   tar -xzf tritonserver.tar.gz
   ```

---

## Recommendation

**Just use PyTriton** - it's the simplest and most reliable method:

```bash
./install_triton_via_pytriton.sh
```

That's it! No Docker, no podman, no downloads, no complications.

