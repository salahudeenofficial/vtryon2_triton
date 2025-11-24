# OOM Diagnosis: Which Step is Failing?

## Analysis

Based on your error and the ensemble flow:

### Memory Usage Breakdown:
- **Process 1476433: 33.22 GiB** - This is the main process
- **PyTorch allocated: 31.69 GiB**
- **Tried to allocate: 66.00 MiB more** (failed)

### Ensemble Steps (in order):
1. **latent_encoder** - ~500MB (VAE encoder)
2. **text_encoder** - ~2-3GB (CLIP model)
3. **sampling** - **~20-30GB** (UNET 19.5GB + sampling overhead) ⚠️ **MOST LIKELY**
4. **decoding** - ~2-3GB (VAE decoder)

## Most Likely Culprit: Step 3 (Sampling)

**Why:**
- UNET model is **19.5GB** (largest model)
- Sampling process needs additional memory for:
  - Intermediate latent states during diffusion steps
  - Attention computations (memory-intensive)
  - Noise tensors
  - Gradient computation (even in inference mode, some overhead exists)

**Evidence:**
- 33.22 GiB already allocated suggests UNET + CLIP + VAE are loaded
- Only 66 MiB more needed suggests we're at the limit during sampling iteration

---

## Debugging Commands

### 1. Check Which Models Are Loaded

```bash
# Inside container
python3 << 'PYEOF'
import torch
import sys
sys.path.insert(0, '/workspace/shared_comfyui')
import comfy.model_management as mm

print("=== Loaded Models ===")
for i, model in enumerate(mm.current_loaded_models):
    print(f"Model {i}: {model.model.__class__.__name__}")
    print(f"  Device: {model.device}")
    print(f"  Memory: {model.model_memory_required(model.device) / 1024**3:.2f} GB")
PYEOF
```

### 2. Monitor Memory During Inference

```bash
# In another terminal, watch GPU memory
watch -n 0.5 nvidia-smi

# Or continuous monitoring
nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv -l 1
```

### 3. Check Triton Logs for Step Information

```bash
# Check which step failed
docker logs <container-name> 2>&1 | grep -i "sampling\|text_encoder\|latent_encoder\|decoding" | tail -20

# Check for OOM errors
docker logs <container-name> 2>&1 | grep -i "out of memory\|OOM\|CUDA" | tail -20
```

### 4. Test Individual Steps

```bash
# Test Step 1 (latent_encoder) only
curl -X POST http://localhost:8000/v2/models/latent_encoder/infer \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": [{
      "name": "image_path",
      "shape": [1, 1],
      "datatype": "BYTES",
      "data": [["/workspace/test_images/person.jpg"]]
    }],
    "outputs": [{"name": "latent"}]
  }'

# Test Step 2 (text_encoder) only
curl -X POST http://localhost:8000/v2/models/text_encoder/infer \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": [
      {"name": "image1_path", "shape": [1, 1], "datatype": "BYTES", "data": [["/workspace/test_images/person.jpg"]]},
      {"name": "image2_path", "shape": [1, 1], "datatype": "BYTES", "data": [["/workspace/test_images/cloth.jpg"]]},
      {"name": "prompt", "shape": [1, 1], "datatype": "BYTES", "data": [["test prompt"]]}
    ],
    "outputs": [{"name": "positive_encoding"}, {"name": "negative_encoding"}]
  }'
```

---

## Solutions

### Solution 1: Enable PyTorch Memory Optimization

Add to your service code or environment:

```bash
# Set environment variable
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

# Or in Python before loading models:
import os
os.environ['PYTORCH_CUDA_ALLOC_CONF'] = 'expandable_segments:True'
```

### Solution 2: Unload Models Between Steps

Modify the ensemble to unload models not needed:

- After `text_encoder`: Keep CLIP loaded, unload VAE encoder
- During `sampling`: Keep UNET loaded, unload CLIP if possible
- After `sampling`: Unload UNET, load VAE decoder

### Solution 3: Use CPU Offloading

Move some models to CPU when not in use:

```python
# In service.py, after each step:
model.to("cpu")
torch.cuda.empty_cache()
```

### Solution 4: Reduce Batch Size or Image Resolution

- Current output: 1176x880 (quite large)
- Try smaller resolution or batch_size=1 (already set)

### Solution 5: Use FP8/FP16 More Aggressively

- Models are already FP8, but ensure all tensors use lower precision
- Check if intermediate computations can use FP16

---

## Quick Fix Commands

### Add Memory Optimization to Container

```bash
# Inside container, add to entrypoint or service initialization
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

# Or modify entrypoint.sh:
echo 'export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True' >> /workspace/entrypoint.sh
```

### Clear GPU Cache Before Sampling

Add to `sampling/1/service.py`:

```python
# Before sampling
torch.cuda.empty_cache()
torch.cuda.synchronize()

# After sampling
torch.cuda.empty_cache()
```

---

## Verification

After applying fixes, monitor memory:

```bash
# Watch memory during inference
nvidia-smi --query-gpu=memory.used,memory.free,memory.total --format=csv -l 0.5
```

Expected behavior:
- Memory should peak during sampling step
- Should not exceed ~40GB (leaving some headroom)
- Should free memory after each step completes


