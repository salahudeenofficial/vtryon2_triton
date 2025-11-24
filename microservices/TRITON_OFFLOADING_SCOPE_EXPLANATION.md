# Triton Model Offloading: Scope and Garbage Collection Explained

## Your Concern (Valid!)

You're asking: **When we call `unload_all_models()` in `model.py` after the service function returns, will it work? Won't models be out of scope and garbage collected?**

## The Answer: YES, It Works! Here's Why:

### 1. ComfyUI Uses a Global Registry

ComfyUI maintains a **global list** that persists across function calls:

```python
# In comfy/model_management.py (line 449)
current_loaded_models = []  # GLOBAL list, not local
```

### 2. Models Are Added to Global Registry

When models are loaded via `load_models_gpu()`:

```python
# In service.py
vae_loader = VAELoader()
vae_output = vae_loader.load_vae(...)  # This calls load_models_gpu()

# Inside load_models_gpu() (line 617-653):
def load_models_gpu(models, ...):
    for x in models:
        loaded_model = LoadedModel(x)
        # Models are added to GLOBAL list
        current_loaded_models.append(loaded_model)  # ← GLOBAL reference!
```

**Key Point**: Models are stored in the **global** `current_loaded_models` list, not just local variables.

### 3. `unload_all_models()` Works on Global Registry

```python
# In comfy/model_management.py (line 1435)
def unload_all_models():
    free_memory(1e30, get_torch_device())

# free_memory() (line 580-615) iterates through GLOBAL list:
def free_memory(memory_required, device, keep_loaded=[]):
    for i in range(len(current_loaded_models) -1, -1, -1):  # ← Uses GLOBAL list!
        shift_model = current_loaded_models[i]
        if shift_model.device == device:
            # Unload model
            current_loaded_models[i].model_unload()
```

**Key Point**: `unload_all_models()` works on the **global** `current_loaded_models` list, so it works even after service functions return!

### 4. Garbage Collection Won't Remove Models

**Why models aren't garbage collected:**

1. **Global Reference**: Models are in `current_loaded_models` (global list)
2. **Weak References**: ComfyUI uses `weakref.ref()` for some references, but the global list keeps strong references
3. **Explicit Unload Required**: Models stay in GPU memory until explicitly unloaded via `model_unload()`

**What `gc.collect()` does:**
- Removes Python objects with **no references**
- But models in `current_loaded_models` **have references** (the global list)
- So `gc.collect()` won't remove them until they're unloaded from the global list

## Current Implementation Analysis

### Service Functions Already Unload

Looking at the service functions, they **already** call `unload_all_models()`:

```python
# latent_encoder/1/service.py (line 280)
comfy.model_management.unload_all_models()

# text_encoder/1/service.py (line 398)
comfy.model_management.unload_all_models()

# sampling/1/service.py (line 373)
comfy.model_management.unload_all_models()
```

### Model.py Also Unloads (Redundant but Safe)

```python
# latent_encoder/1/model.py (line 173)
comfy.model_management.unload_all_models()  # ← Called AFTER service returns
```

**Is this redundant?** Yes, but it's **defensive programming**:
- Service might fail before reaching unload code
- Ensures models are unloaded even if service doesn't
- No harm in calling it twice (works on global list, idempotent)

## The Real Flow

```
1. Service function called:
   ├─ load_models_gpu() → Adds models to current_loaded_models (GLOBAL)
   ├─ Perform inference
   └─ unload_all_models() → Removes from current_loaded_models (GLOBAL)

2. Service function returns:
   ├─ Local variables go out of scope ✓
   ├─ BUT models still in current_loaded_models (GLOBAL) ✓
   └─ Models still on GPU (not garbage collected) ✗

3. model.py execute() continues:
   └─ unload_all_models() → Works on current_loaded_models (GLOBAL) ✓
      └─ Models moved to CPU, removed from GPU ✓
```

## Potential Issue: Double Unloading

If service already unloads, calling it again in `model.py`:
- Works on empty/partially empty `current_loaded_models` list
- No error, just redundant
- But ensures cleanup even if service fails

## Better Approach: Verify Before Unloading

We could check if models are still loaded:

```python
# In model.py execute()
import comfy.model_management

# Check if any models are still loaded
loaded = comfy.model_management.loaded_models()
if loaded:
    self.logger.log_info(f"Found {len(loaded)} models still loaded, unloading...")
    comfy.model_management.unload_all_models()
else:
    self.logger.log_info("No models loaded, skipping unload")
```

## Conclusion

✅ **Your concern is valid** - we should understand scope
✅ **But it works** - because of global registry
✅ **Redundant calls are safe** - defensive programming
⚠️ **Could be optimized** - check before unloading

The current implementation is **correct and safe**, but could be optimized to avoid redundant calls.

