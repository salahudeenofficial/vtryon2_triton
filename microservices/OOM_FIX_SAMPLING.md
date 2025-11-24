# OOM Fix for Sampling Service

## Problem Analysis

**Error:**
```
CUDA out of memory. Tried to allocate 260.00 MiB. GPU 0 has a total capacity of 44.42 GiB of which 69.50 MiB is free.
Process 739679 has 43.26 GiB memory in use.
```

**Root Cause:**
1. The `sampling` service loads the UNET model (~43 GB) but was **NOT** wrapped in `torch.inference_mode()`
2. The sampled latent tensor was staying on GPU after inference
3. `unload_all_models()` was called, but Python references kept the model in memory
4. No garbage collection was performed after unloading

## What Was Wrong

1. **Missing `torch.inference_mode()`**: The sampling service didn't disable gradient computation, causing PyTorch to keep additional memory for backpropagation
2. **Tensor on GPU**: The `sampled_latent_tensor` was returned while still on GPU, keeping GPU memory allocated
3. **No garbage collection**: Python references weren't cleared, preventing actual memory release

## The Fix

### Changes Made to `sampling/1/service.py`:

1. **Wrapped entire inference in `torch.inference_mode()`**:
   ```python
   with torch.inference_mode():
       # All model loading and inference code
   ```
   - Disables gradient computation
   - Reduces memory overhead
   - Prevents memory leaks from autograd

2. **Move sampled tensor to CPU immediately**:
   ```python
   # Move sampled latent to CPU immediately to free GPU memory
   sampled_latent = sampled_latent.detach().cpu()
   ```
   - Frees GPU memory as soon as sampling completes
   - Tensor is still available for return, just on CPU

3. **Added explicit garbage collection**:
   ```python
   import gc
   comfy.model_management.unload_all_models()
   torch.cuda.empty_cache()
   torch.cuda.synchronize()
   gc.collect()  # Force garbage collection
   ```
   - Ensures Python references are cleared
   - Forces immediate memory release

## Expected Behavior After Fix

1. **During sampling**: UNET model loads to GPU (~43 GB)
2. **After sampling**: 
   - Sampled tensor moved to CPU
   - Models unloaded to CPU via `unload_all_models()`
   - GPU cache cleared
   - Garbage collection runs
   - **GPU memory should drop to <1 GB**

3. **Before next request**: Models stay on CPU, ready to load again

## Verification

After applying the fix, check GPU memory:

```bash
# Inside container
nvidia-smi

# Should show:
# - Before request: ~0-1 GB GPU memory
# - During sampling: ~43 GB GPU memory
# - After sampling: ~0-1 GB GPU memory (back to baseline)
```

## Why This Matters

The ensemble pipeline runs 4 models sequentially:
1. `latent_encoder` - loads VAE (~500 MB)
2. `text_encoder` - loads CLIP (~7 GB)
3. `sampling` - loads UNET (~43 GB) ← **This was the problem**
4. `decoding` - loads VAE again (~500 MB)

If `sampling` doesn't unload properly, the UNET stays in memory (43 GB), leaving only ~1 GB free. When `decoding` tries to load VAE, it fails with OOM.

## Related Files

- `sampling/1/service.py` - Fixed
- `sampling/1/model.py` - No changes needed
- Other services already had `torch.inference_mode()` - verified

## Testing

After rebuilding the image, test with:

```bash
# Send inference request
curl -X POST http://localhost:8000/v2/models/vtryon_pipeline/infer \
  -H "Content-Type: application/json" \
  -d @TEST_INFERENCE_REQUEST.json

# Monitor GPU memory during request
watch -n 1 nvidia-smi
```

Expected: GPU memory should spike during sampling, then drop back to baseline after completion.


