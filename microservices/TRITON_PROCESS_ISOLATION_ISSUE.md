# Critical Issue: Triton Process Isolation and ComfyUI Memory Management

## Your Concern is 100% CORRECT! 🚨

**Each Triton model runs in a SEPARATE Python process**, so ComfyUI's global `current_loaded_models` list is **NOT shared** between processes!

## The Problem

### Triton Architecture

From `TRITON_ARCHITECTURE_AND_MEMORY.md`:

> "Triton C++ server spawns a Python stub process for each model instance"
> "Each Python model instance runs in a separate process"

**This means:**
- `latent_encoder` → Process 1 (has its own `current_loaded_models`)
- `text_encoder` → Process 2 (has its own `current_loaded_models`)
- `sampling` → Process 3 (has its own `current_loaded_models`)
- `decoding` → Process 4 (has its own `current_loaded_models`)

### The Issue with My Previous Approach

```python
# In latent_encoder/1/model.py
comfy.model_management.unload_all_models()  # Unloads in Process 1
```

**Problem:**
- This unloads models in Process 1's `current_loaded_models`
- But Process 3 (sampling) has its **own separate** `current_loaded_models`
- Process 3 doesn't know Process 1 unloaded anything!

### What Actually Happens

```
Process 1 (latent_encoder):
  ├─ Loads VAE encoder to GPU
  ├─ Processes request
  ├─ unload_all_models() → Moves VAE to CPU in Process 1
  └─ Process 1's GPU memory freed ✓

Process 2 (text_encoder) - RUNS IN PARALLEL:
  ├─ Loads CLIP + VAE to GPU (separate from Process 1)
  ├─ Processes request
  ├─ unload_all_models() → Moves CLIP+VAE to CPU in Process 2
  └─ Process 2's GPU memory freed ✓

Process 3 (sampling):
  ├─ GPU memory should be free (Process 1 & 2 finished)
  ├─ Loads UNet to GPU
  ├─ Processes request
  └─ unload_all_models() → Moves UNet to CPU in Process 3

Process 4 (decoding):
  ├─ GPU memory should be free (Process 3 finished)
  ├─ Loads VAE decoder to GPU
  └─ unload_all_models() → Moves VAE decoder to CPU
```

## The Good News

**GPU memory IS shared across processes!** Even though Python objects aren't shared:

1. **GPU Memory is Shared**: All processes use the same GPU device
2. **Sequential Execution**: Ensemble steps run sequentially (except parallel steps)
3. **Process Isolation Helps**: Each process manages its own models independently

## The Real Solution

### Option 1: Rely on Process Lifecycle (Current Approach)

**How it works:**
- Each process unloads models at end of `execute()`
- When process finishes, GPU memory is freed
- Next process can load its models

**Pros:**
- Simple
- Works because GPU memory is shared
- Each process is independent

**Cons:**
- No explicit coordination between processes
- Relies on Triton's sequential execution

### Option 2: Explicit GPU Memory Management

**Check GPU memory before loading:**

```python
# In sampling/1/model.py execute()
import torch

# Check available GPU memory
free_memory = torch.cuda.get_device_properties(0).total_memory - torch.cuda.memory_allocated(0)
if free_memory < required_memory:
    # Force cleanup
    torch.cuda.empty_cache()
    torch.cuda.ipc_collect()
```

### Option 3: Use Triton's Model Control API

**Unload models via Triton API** (if supported for ensemble):

```python
# This won't work - ensemble models can't control other models
pb_utils.unload_model("latent_encoder")  # ❌ Not possible
```

## Current Implementation Status

### What Works:

✅ **Each process unloads its own models** - This is correct!
✅ **GPU memory is freed** - When process unloads models, GPU memory is freed
✅ **Sequential execution** - Ensures processes don't conflict

### What Doesn't Work:

❌ **Cross-process model tracking** - Can't see models in other processes
❌ **Explicit coordination** - No way to tell other processes to unload

### What We Should Do:

1. **Keep current approach** - Each process unloads its models
2. **Add GPU memory checks** - Verify memory is free before loading
3. **Add logging** - Monitor GPU memory usage across processes

## Updated Code Strategy

### For Each Model's `execute()`:

```python
def execute(self, requests):
    # 1. Check GPU memory before loading
    import torch
    free_memory = torch.cuda.get_device_properties(0).total_memory - torch.cuda.memory_allocated(0)
    self.logger.log_info(f"GPU memory before: {free_memory / 1e9:.2f} GB free")
    
    # 2. Process request (loads models via service)
    responses = process_requests(requests)
    
    # 3. Unload models in THIS process
    import comfy.model_management
    loaded = comfy.model_management.loaded_models()
    if loaded:
        self.logger.log_info(f"Unloading {len(loaded)} models in this process...")
        comfy.model_management.unload_all_models()
        torch.cuda.empty_cache()
    
    # 4. Verify GPU memory freed
    free_memory_after = torch.cuda.get_device_properties(0).total_memory - torch.cuda.memory_allocated(0)
    self.logger.log_info(f"GPU memory after: {free_memory_after / 1e9:.2f} GB free")
    
    return responses
```

## Key Insights

1. **Process Isolation**: Each model is a separate process
2. **GPU Memory Sharing**: GPU memory is shared, Python objects are not
3. **Sequential Execution**: Ensemble ensures steps run in order
4. **Independent Management**: Each process must manage its own models

## Conclusion

✅ **Your concern was valid!** ComfyUI's global registry doesn't work across processes.

✅ **But the approach still works!** Because:
- GPU memory is shared across processes
- Each process unloads its models independently
- Sequential execution ensures memory is free for next step

✅ **We should add GPU memory monitoring** to verify it's working correctly.

