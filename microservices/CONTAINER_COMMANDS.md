# Commands to Run Inside Container

## Enter Container

```bash
docker exec -it <container-name> bash
```

---

## 1. Check Model Download Status

```bash
# Check total sizes of each model directory
du -sh /workspace/shared_models/*

# Check individual directories
ls -lh /workspace/shared_models/vae/
ls -lh /workspace/shared_models/clip/
ls -lh /workspace/shared_models/diffusion_models/
ls -lh /workspace/shared_models/loras/

# Check specific model files (expected sizes)
ls -lh /workspace/shared_models/vae/qwen_image_vae.safetensors
# Expected: ~242 MB

ls -lh /workspace/shared_models/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors
# Expected: ~8949 MB

ls -lh /workspace/shared_models/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors
# Expected: ~19484 MB

ls -lh /workspace/shared_models/loras/Qwen-Image-Lightning-4steps-V2.0.safetensors
# Expected: ~167 MB
```

---

## 2. Check Triton Server Status

```bash
# Check if server is ready
curl -s http://localhost:8000/v2/health/ready
# Empty response = ready, error = not ready

# Check if server is live
curl -s http://localhost:8000/v2/health/live

# List all loaded models
curl -s http://localhost:8000/v2/models | python3 -m json.tool

# Check specific model status
curl -s http://localhost:8000/v2/models/latent_encoder/ready | python3 -m json.tool
curl -s http://localhost:8000/v2/models/text_encoder/ready | python3 -m json.tool
curl -s http://localhost:8000/v2/models/sampling/ready | python3 -m json.tool
curl -s http://localhost:8000/v2/models/decoding/ready | python3 -m json.tool
curl -s http://localhost:8000/v2/models/vtryon_pipeline/ready | python3 -m json.tool

# Check if Triton process is running
ps aux | grep tritonserver
```

---

## 3. Check Model Loading Status

```bash
# Check server logs (if accessible)
# Note: logs might be in /var/log or stdout, check with:
cat /proc/1/cmdline | tr '\0' ' '

# Check if models are accessible
ls -la /models/latent_encoder/1/
ls -la /models/text_encoder/1/
ls -la /models/sampling/1/
ls -la /models/decoding/1/
```

---

## 4. Check Environment & Paths

```bash
# Check environment variables
echo "COMFYUI_PATH: $COMFYUI_PATH"
echo "MODEL_DIR: $MODEL_DIR"
echo "TRITON_MODEL_REPOSITORY: $TRITON_MODEL_REPOSITORY"

# Check if paths exist
test -d "$COMFYUI_PATH" && echo "✓ ComfyUI path exists" || echo "✗ ComfyUI path missing"
test -d "$MODEL_DIR" && echo "✓ Model dir exists" || echo "✗ Model dir missing"

# Check ComfyUI structure
ls -la /workspace/shared_comfyui/comfy | head -10

# Check model files structure
ls -la /workspace/shared_models/
```

---

## 5. Test Imports (Debugging)

```bash
# Test if Python can import ComfyUI
python3 -c "
import sys
sys.path.insert(0, '/workspace/shared_comfyui')
try:
    import comfy
    print('✓ ComfyUI import successful')
except Exception as e:
    print(f'✗ ComfyUI import failed: {e}')
"

# Test if service modules can be imported
python3 -c "
import sys
sys.path.insert(0, '/workspace/shared_comfyui')
sys.path.insert(0, '/models/latent_encoder/1')
try:
    from service import encode_image_to_latent
    print('✓ Service import successful')
except Exception as e:
    print(f'✗ Service import failed: {e}')
    import traceback
    traceback.print_exc()
"
```

---

## 6. Manual Download (if needed)

```bash
# Run download script manually
/workspace/download_triton_models.sh

# Check if download is running
ps aux | grep -E "(wget|curl|download)"
```

---

## 7. All-in-One Status Check

```bash
echo "=== Model Download Status ==="
du -sh /workspace/shared_models/*

echo ""
echo "=== Triton Server Status ==="
curl -s http://localhost:8000/v2/health/ready && echo "✓ Ready" || echo "✗ Not ready"

echo ""
echo "=== Loaded Models ==="
curl -s http://localhost:8000/v2/models | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'models' in data:
    for model in data['models']:
        print(f'  - {model[\"name\"]}')
else:
    print('  No models loaded')
"

echo ""
echo "=== Environment ==="
echo "COMFYUI_PATH: $COMFYUI_PATH"
echo "MODEL_DIR: $MODEL_DIR"
```

---

## Expected Results

### Models Downloaded:
- VAE: ~242 MB
- CLIP: ~8949 MB
- UNET: ~19484 MB
- LoRA: ~167 MB

### Triton Ready:
- Health endpoint returns empty (200 OK)
- All 5 models show in `/v2/models`
- Each model shows `ready: true` in status

---

## Troubleshooting

### Models not downloading?
```bash
# Check if download script exists
ls -la /workspace/download_triton_models.sh

# Run manually
/workspace/download_triton_models.sh

# Check network
ping -c 3 8.8.8.8
```

### Triton not responding?
```bash
# Check if process is running
ps aux | grep tritonserver

# Check if port is listening
netstat -tlnp | grep 8000 || ss -tlnp | grep 8000
```

### Import errors?
```bash
# Check Python path
python3 -c "import sys; print('\n'.join(sys.path))"

# Test imports step by step
python3 -c "import sys; sys.path.insert(0, '/workspace/shared_comfyui'); import comfy"
```


