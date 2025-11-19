# Triton Installation - Quick Start

## Recommended Method: PyTriton

**This is the simplest and most reliable method for Ubuntu 24.04.**

### On VastAI Instance:

```bash
cd /workspace/vtryon2_triton
git pull origin microservice
cd microservices

# Install Triton via PyTriton
chmod +x install_triton_via_pytriton.sh
./install_triton_via_pytriton.sh
```

**What it does:**
- Installs `nvidia-pytriton` via pip
- Includes Triton Inference Server binaries
- Sets up everything automatically
- No Docker, no podman, no downloads needed

**After installation:**
```bash
# Verify
tritonserver --version

# Start Triton server
./start_triton_direct.sh
```

---

## Why PyTriton?

✅ **Simplest**: Just `pip install nvidia-pytriton`  
✅ **Includes binaries**: Triton server is included  
✅ **Works everywhere**: No Docker, no special tools  
✅ **Official**: Maintained by NVIDIA  
✅ **Latest version**: Always up-to-date  
✅ **Ubuntu 24.04 compatible**: Works out of the box  

---

## Troubleshooting

### If installation fails:

1. **Check Python version:**
   ```bash
   python3 --version  # Should be 3.8+
   ```

2. **Upgrade pip:**
   ```bash
   pip install --upgrade pip
   ```

3. **Try with verbose output:**
   ```bash
   pip install -v nvidia-pytriton
   ```

### If tritonserver not found after installation:

The script will try to locate it automatically. If it can't find it:

```bash
# Find it manually
python3 -c "import nvidia.pytriton; import os; print(os.path.dirname(nvidia.pytriton.__file__))"

# Or check PATH
which tritonserver

# Or search
find ~/.local -name "tritonserver" -type f 2>/dev/null
```

---

## Next Steps

Once Triton is installed:

1. **Start Triton server:**
   ```bash
   ./start_triton_direct.sh
   ```

2. **Test models:**
   ```bash
   curl http://localhost:8000/v2/models
   ```

3. **Proceed with Phase 5 testing**

---

## Alternative Methods

If PyTriton doesn't work, see:
- `TRITON_INSTALL_QUICK.md` - Other installation options
- `extract_from_docker_image.sh` - Extract from Docker image (requires podman)
- `setup_triton_direct.sh` - Direct download (if links work)

