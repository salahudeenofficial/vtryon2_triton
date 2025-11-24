# Triton Dynamic CPU Offloading Configuration

## Overview

This configuration implements **dynamic CPU offloading** where models:
- Run on **GPU** during inference
- Are **offloaded to CPU** after each step to free GPU memory
- Are **reloaded to GPU** when needed for the next request

## Execution Flow

```
Request Flow:
┌─────────────────────────────────────────────────────────────┐
│ Step 1: latent_encoder (GPU)                               │
│   - Loads VAE encoder to GPU                                │
│   - Encodes image to latent                                 │
│   - Offloads VAE encoder to CPU ← Frees GPU memory         │
└─────────────────────────────────────────────────────────────┘
         │
         ├─┐
         │ │ (Parallel execution)
         ├─┘
┌─────────────────────────────────────────────────────────────┐
│ Step 2: text_encoder (GPU)                                  │
│   - Loads CLIP + VAE to GPU                                 │
│   - Encodes text and images                                 │
│   - Offloads CLIP + VAE to CPU ← Frees GPU memory          │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│ Step 3: sampling (GPU)                                      │
│   - GPU memory now free (previous models offloaded)         │
│   - Loads UNet to GPU                                       │
│   - Performs diffusion sampling                              │
│   - Offloads UNet to CPU ← Frees GPU memory                │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│ Step 4: decoding (GPU)                                      │
│   - UNet already offloaded (from step 3)                    │
│   - Loads VAE decoder to GPU                                │
│   - Decodes latent to image                                 │
│   - Offloads VAE decoder to CPU ← Frees GPU memory        │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│ Next Request:                                                │
│   - GPU memory free (all models offloaded)                  │
│   - latent_encoder and text_encoder can run in parallel     │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Details

### 1. Model Configurations

All models use `KIND_GPU` in their `instance_group`:
- Models **run on GPU** during inference
- CPU offloading is handled **dynamically in code**, not via config

### 2. Code-Level Offloading

Each model's `model.py` implements offloading at the end of `execute()`:

#### latent_encoder/1/model.py
```python
# After encoding completes:
comfy.model_management.unload_all_models()  # Offloads VAE encoder to CPU
torch.cuda.empty_cache()
```

#### text_encoder/1/model.py
```python
# After encoding completes:
comfy.model_management.unload_all_models()  # Offloads CLIP + VAE to CPU
torch.cuda.empty_cache()
```

#### sampling/1/model.py
```python
# After sampling completes:
# Service already unloads all models (including UNet)
torch.cuda.empty_cache()
```

#### decoding/1/model.py
```python
# BEFORE decoding starts:
comfy.model_management.unload_all_models()  # Ensures UNet is offloaded
torch.cuda.empty_cache()

# ... perform decoding ...

# AFTER decoding completes:
comfy.model_management.unload_all_models()  # Offloads VAE decoder to CPU
torch.cuda.empty_cache()
```

## Key Points

1. **All models run on GPU** - No models are configured to run on CPU
2. **Dynamic offloading** - Models are offloaded to CPU after each step via code
3. **Parallel execution** - latent_encoder and text_encoder run in parallel (Triton automatic)
4. **Memory management** - GPU memory is freed between steps for next model
5. **Next request ready** - After decoding, all models are offloaded, ready for next request

## Benefits

✅ **Maximum GPU utilization** - All inference happens on GPU (fast)
✅ **Memory efficient** - Models offloaded between steps (prevents OOM)
✅ **Parallel execution** - First two steps run simultaneously
✅ **Ready for next request** - GPU memory freed after each pipeline

## Configuration Files

- `latent_encoder/config.pbtxt` - `KIND_GPU`
- `text_encoder/config.pbtxt` - `KIND_GPU`
- `sampling/config.pbtxt` - `KIND_GPU`
- `decoding/config.pbtxt` - `KIND_GPU`
- `vtryon_pipeline/config.pbtxt` - Ensemble (supports parallel)

## Verification

To verify offloading is working:

1. **Check logs** - Each model logs "offloaded to CPU" messages
2. **Monitor GPU memory** - Should drop after each step completes
3. **Check nvidia-smi** - GPU memory usage should cycle up/down with each step

## Notes

- Offloading happens in `execute()`, not `finalize()` (which is only called on model unload)
- ComfyUI's `unload_all_models()` moves models to CPU (offload_device)
- Models stay in CPU memory, ready to be reloaded to GPU for next request
- This is more efficient than reloading from disk each time

