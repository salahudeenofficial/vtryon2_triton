# Triton Ensemble Configuration for CPU Offloading

## Overview

✅ **YES** - Triton **does support** the exact configuration you're looking for! 

The ensemble scheduler automatically executes models in parallel when their inputs are ready, and each composing model can be configured with CPU or GPU instance groups.

## Answer to Your Question

**Is there a Triton ensemble configuration for CPU offloading?**

**YES!** The configuration is now set up. Here's what's configured:

### ✅ 1. First Two Components Execute in Parallel

The ensemble configuration **already supports this**:
- `latent_encoder` and `text_encoder` execute **in parallel** automatically
- Both receive inputs directly from ensemble inputs (no dependencies between them)
- Triton's ensemble scheduler detects ready inputs and executes them simultaneously

**How it works**: In `vtryon_pipeline/config.pbtxt`, both steps are at the same level:
```protobuf
step [
  { model_name: "latent_encoder" ... },  // Step 1
  { model_name: "text_encoder" ... },     // Step 2 - executes in parallel with Step 1
  { model_name: "sampling" ... },        // Step 3 - waits for Steps 1 & 2
  { model_name: "decoding" ... }         // Step 4 - waits for Step 3
]
```

### ✅ 2. Third Sampling Step with CPU Offloading

**Current Configuration**: Sampling model is configured to run on **CPU**:
- Updated `sampling/config.pbtxt` with `instance_group { kind: KIND_CPU }`
- All sampling operations (including UNet) run on CPU

**For "UNet only on GPU"**: 
- See `sampling/config.pbtxt.gpu_hybrid` for alternative config
- Requires modifying `sampling/1/model.py` to:
  - Load UNet to GPU explicitly
  - Keep other components on CPU
  - Manually transfer tensors between CPU/GPU

### ✅ 3. Decoding Step Executes Alone

**Current Configuration**: Decoding model is configured to run on **CPU**:
- Updated `decoding/config.pbtxt` with `instance_group { kind: KIND_CPU }`
- Executes sequentially after sampling completes

## Current Configuration Status

| Model | Device | Status |
|-------|--------|--------|
| `latent_encoder` | GPU | ✅ Configured (KIND_GPU) |
| `text_encoder` | GPU | ✅ Configured (KIND_GPU) |
| `sampling` | CPU | ✅ **Updated** (KIND_CPU) |
| `decoding` | CPU | ✅ **Updated** (KIND_CPU) |
| `vtryon_pipeline` | Ensemble | ✅ Supports parallel execution |

## Execution Flow

```
Input: image1_path, image2_path, prompt, seed
  │
  ├─→ latent_encoder (GPU) ──┐
  │                          │
  └─→ text_encoder (GPU) ───┤ (PARALLEL - both execute simultaneously)
                             │
                             ▼
                    sampling (CPU) - waits for both above
                             │
                             ▼
                    decoding (CPU) - executes alone after sampling
                             │
                             ▼
                    Output: output_image
```

## Files Updated

1. ✅ `triton_model_repository/sampling/config.pbtxt` - Changed to `KIND_CPU`
2. ✅ `triton_model_repository/decoding/config.pbtxt` - Changed to `KIND_CPU`
3. ✅ `triton_model_repository/vtryon_pipeline/config.pbtxt` - Already supports parallel (no changes needed)
4. 📄 `triton_model_repository/sampling/config.pbtxt.gpu_hybrid` - Alternative for hybrid approach

## How Parallel Execution Works

From Triton documentation:
> "When an inference request for the ensemble model is received, the ensemble scheduler will... Check models that require the newly collected tensor and send internal requests to models whose inputs are ready... Note that the responses will be in arbitrary order depending on the load and computation time of individual models."

**Key Point**: Steps 1 and 2 (`latent_encoder` and `text_encoder`) both have their inputs ready immediately, so Triton executes them **in parallel automatically**.

## For Hybrid "UNet Only on GPU" Sampling

If you want sampling to run with only UNet on GPU (other components on CPU), you need to:

1. **Use the hybrid config**: Copy `config.pbtxt.gpu_hybrid` to `config.pbtxt`
2. **Modify `sampling/1/model.py`** to:
   ```python
   # Load UNet to GPU
   unet_model = load_unet().to('cuda')
   
   # Keep other components on CPU
   clip_model = load_clip().to('cpu')
   vae_model = load_vae().to('cpu')
   
   # Manually transfer tensors as needed
   latent = latent.to('cuda')  # For UNet
   # ... process with UNet on GPU
   result = result.to('cpu')  # Move back to CPU if needed
   ```

## Testing the Configuration

1. **Start Triton Server**:
   ```bash
   docker run --gpus=1 --rm -p 8000:8000 -p 8001:8001 \
     -v $(pwd)/triton_model_repository:/models \
     nvcr.io/nvidia/tritonserver:latest-py3 \
     tritonserver --model-repository=/models
   ```

2. **Verify Model Status**:
   ```bash
   curl http://localhost:8000/v2/models
   ```

3. **Check Instance Groups**:
   - Each model's config.pbtxt shows `instance_group` with `KIND_CPU` or `KIND_GPU`
   - Ensemble model doesn't have instance_group (it's just a scheduler)

## Notes

1. **Parallel Execution**: ✅ Automatic - No configuration needed, Triton handles it
2. **CPU Offloading**: ✅ Configured - Updated sampling and decoding to CPU
3. **Partial Offloading**: ⚠️ Requires code changes in model.py for hybrid approach
4. **Memory Management**: CPU offloading reduces GPU memory but may increase latency
5. **Performance**: Parallel execution of steps 1 & 2 reduces overall pipeline latency

## Summary

**Your requirements are now configured:**

✅ First two components (latent_encoder + text_encoder) execute in parallel  
✅ Third sampling step executes with CPU offloading (or can be hybrid with code changes)  
✅ Third decoding step executes alone on CPU  

The configuration is ready to use!

