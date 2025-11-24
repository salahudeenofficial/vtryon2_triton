# Triton Setup Analysis - Potential Issues

## Overview
Analyzing the setup against Triton documentation to identify potential issues causing "failed to load all models" error.

---

## 1. Model Repository Structure ✅

**Status**: **CORRECT**

According to Triton docs:
- Each `<model-name>` directory must have:
  - `config.pbtxt` file
  - At least one numeric version directory (e.g., `1/`)
  - Model files in version directory

**Your Structure**:
```
/models/
├── latent_encoder/
│   ├── config.pbtxt ✅
│   └── 1/
│       ├── model.py ✅
│       ├── service.py ✅
│       └── config.py ✅
├── text_encoder/ ✅
├── sampling/ ✅
├── decoding/ ✅
└── vtryon_pipeline/ ✅
```

**Verdict**: Structure is correct per Triton documentation.

---

## 2. Python Backend Initialization ⚠️

### Issue 1: Import Errors Not Caught

**Problem**: If `from service import encode_image_to_latent` fails, `initialize()` will raise an exception, causing model load to fail.

**Current Code**:
```python
def initialize(self, args):
    # ...
    from service import encode_image_to_latent  # No try/except!
    from config import Config
```

**Risk**: If `service.py` has import errors (e.g., missing dependencies, path issues), model fails to load silently.

**Fix**: Add error handling:
```python
try:
    from service import encode_image_to_latent
    from config import Config
except Exception as e:
    self.logger.log_error(f"Failed to import service: {e}")
    raise pb_utils.TritonModelException(f"Import error: {e}")
```

### Issue 2: Path Resolution in service.py

**Problem**: `service.py` line 53 hardcodes ComfyUI path:
```python
comfyui_path = Path(__file__).parent / "comfyui"  # ❌ Wrong path!
```

**Issue**: 
- `__file__` = `/models/latent_encoder/1/service.py`
- `comfyui_path` = `/models/latent_encoder/1/comfyui` ❌ (doesn't exist)
- Should be: `/workspace/shared_comfyui` ✅

**Impact**: When `setup_comfyui()` is called (lazy, on first request), it will fail with:
```
ComfyUIInitializationError: ComfyUI directory not found: /models/latent_encoder/1/comfyui
```

**Fix**: Update `service.py` to use environment variable:
```python
comfyui_path = os.getenv("COMFYUI_PATH")
if not comfyui_path:
    comfyui_path = Path(__file__).parent / "comfyui"  # Fallback
else:
    comfyui_path = Path(comfyui_path)
```

### Issue 3: Config.model_dir Path

**Problem**: `config.py` uses relative path:
```python
model_dir = os.getenv("MODEL_DIR", "./models")  # ❌ Relative path
```

**Issue**: 
- In Triton, working directory might not be what you expect
- Should use absolute path from environment variable

**Current**: `MODEL_DIR=/workspace/shared_models` ✅ (set in Dockerfile)
**But**: If env var not set, falls back to `./models` which doesn't exist

**Fix**: Ensure `MODEL_DIR` is always set, or use absolute path resolution.

---

## 3. Strict Readiness Check ⚠️

**Current**: `strict_readiness = 1` (from logs)

**Meaning**: Triton requires ALL models to be ready before server becomes ready.

**Issue**: If ANY model fails readiness check (even if `initialize()` succeeds), server exits.

**Potential Causes**:
1. Model instance fails health check
2. Ensemble model can't verify all sub-models are ready
3. Python process crashes after initialization

**Fix**: Check if models are actually ready after initialization:
```python
# In model.py initialize()
try:
    # ... initialization code ...
    self.logger.log_info("✓ Model initialized")
except Exception as e:
    self.logger.log_error(f"Initialization failed: {e}")
    raise pb_utils.TritonModelException(f"Init error: {e}")
```

---

## 4. Ensemble Model Configuration ⚠️

**Issue**: Ensemble references models that might not be ready.

**From config.pbtxt**:
```protobuf
ensemble_scheduling {
  step {
    model_name: "latent_encoder"
    model_version: -1  # Latest version
  }
  # ... other steps
}
```

**Potential Issue**: If ensemble tries to verify sub-models are ready, and one isn't, ensemble fails.

**Check**: Ensure all referenced models are actually loaded and ready.

---

## 5. Error Handling in initialize() ⚠️

**Current**: No explicit error handling for imports or path setup.

**Risk**: Silent failures or unclear error messages.

**Best Practice** (from Triton examples):
```python
def initialize(self, args):
    try:
        # Setup code
        self.logger.log_info("Initializing...")
        
        # Critical imports
        try:
            from service import encode_image_to_latent
        except ImportError as e:
            raise pb_utils.TritonModelException(f"Failed to import service: {e}")
        
        # Path validation
        comfyui_path = os.getenv("COMFYUI_PATH")
        if not comfyui_path or not Path(comfyui_path).exists():
            raise pb_utils.TritonModelException(f"COMFYUI_PATH not set or invalid: {comfyui_path}")
        
        self.logger.log_info("✓ Initialized")
    except pb_utils.TritonModelException:
        raise  # Re-raise Triton exceptions
    except Exception as e:
        # Convert other exceptions to Triton exceptions
        raise pb_utils.TritonModelException(f"Initialization error: {e}")
```

---

## 6. Environment Variables ✅

**Status**: **MOSTLY CORRECT**

**Set in Dockerfile**:
- `COMFYUI_PATH=/workspace/shared_comfyui` ✅
- `MODEL_DIR=/workspace/shared_models` ✅
- `PYTHONPATH=/workspace/shared_comfyui:${PYTHONPATH}` ✅

**Issue**: `service.py` doesn't use `COMFYUI_PATH` - it hardcodes path!

---

## 7. Critical Issues Found

### 🔴 CRITICAL: service.py Hardcoded Path

**File**: `triton_model_repository/*/1/service.py` (all 4 models)

**Problem**:
```python
# Line 53 in service.py
comfyui_path = Path(__file__).parent / "comfyui"  # ❌ WRONG!
```

**Should be**:
```python
comfyui_path = os.getenv("COMFYUI_PATH")
if comfyui_path:
    comfyui_path = Path(comfyui_path)
else:
    comfyui_path = Path(__file__).parent / "comfyui"  # Fallback
```

**Impact**: When `setup_comfyui()` is called (on first request), it will fail because ComfyUI is not at `/models/latent_encoder/1/comfyui`.

**Why it might not show up immediately**:
- `setup_comfyui()` is called lazily (on first request, not during `initialize()`)
- So `initialize()` succeeds, but first request will fail
- However, if Triton does any pre-validation, this could cause issues

### 🟡 MEDIUM: Config Path Resolution

**File**: `triton_model_repository/*/1/config.py`

**Problem**: Falls back to relative path if `MODEL_DIR` not set:
```python
model_dir = os.getenv("MODEL_DIR", "./models")  # Relative path fallback
```

**Fix**: Use absolute path or ensure env var is always set (it is, but defensive coding is better).

### 🟡 MEDIUM: Missing Error Handling

**File**: `triton_model_repository/*/1/model.py`

**Problem**: No try/except around imports:
```python
from service import encode_image_to_latent  # Could fail silently
```

**Fix**: Add error handling to catch and report import errors clearly.

---

## 8. Recommended Fixes

### Fix 1: Update service.py to use COMFYUI_PATH

**Files to update**:
- `triton_model_repository/latent_encoder/1/service.py`
- `triton_model_repository/text_encoder/1/service.py`
- `triton_model_repository/sampling/1/service.py`
- `triton_model_repository/decoding/1/service.py`

**Change**:
```python
# OLD (line 53):
comfyui_path = Path(__file__).parent / "comfyui"

# NEW:
comfyui_path = os.getenv("COMFYUI_PATH")
if comfyui_path:
    comfyui_path = Path(comfyui_path)
    if not comfyui_path.exists():
        raise ComfyUIInitializationError(f"COMFYUI_PATH does not exist: {comfyui_path}")
else:
    # Fallback to relative path (for backward compatibility)
    comfyui_path = Path(__file__).parent / "comfyui"
```

### Fix 2: Add Error Handling to model.py

**Files to update**: All 4 `model.py` files

**Add**:
```python
def initialize(self, args):
    try:
        self.logger.log_info("Initializing...")
        
        # ... existing code ...
        
        # Import with error handling
        try:
            from service import encode_image_to_latent
            from config import Config
        except ImportError as e:
            error_msg = f"Failed to import service modules: {e}"
            self.logger.log_error(error_msg)
            raise pb_utils.TritonModelException(error_msg)
        
        self.encode_image_to_latent = encode_image_to_latent
        
        # Validate paths
        comfyui_path = os.getenv("COMFYUI_PATH")
        if not comfyui_path:
            self.logger.log_warn("COMFYUI_PATH not set, using fallback")
        elif not Path(comfyui_path).exists():
            error_msg = f"COMFYUI_PATH does not exist: {comfyui_path}"
            self.logger.log_error(error_msg)
            raise pb_utils.TritonModelException(error_msg)
        
        self.logger.log_info("✓ Model initialized")
        
    except pb_utils.TritonModelException:
        raise  # Re-raise Triton exceptions
    except Exception as e:
        error_msg = f"Unexpected initialization error: {e}"
        self.logger.log_error(error_msg)
        import traceback
        self.logger.log_error(traceback.format_exc())
        raise pb_utils.TritonModelException(error_msg)
```

### Fix 3: Improve Config Path Handling

**File**: `triton_model_repository/*/1/config.py`

**Change**:
```python
# OLD:
model_dir = os.getenv("MODEL_DIR", "./models")

# NEW:
model_dir = os.getenv("MODEL_DIR")
if not model_dir:
    # Try to resolve relative to current file
    model_dir = str(Path(__file__).parent / "models")
    if not Path(model_dir).exists():
        raise ValueError(f"MODEL_DIR not set and default path does not exist: {model_dir}")
model_dir = str(Path(model_dir).resolve())  # Ensure absolute path
```

---

## 9. Verification Checklist

After fixes, verify:

- [ ] All models can import `service` module
- [ ] `COMFYUI_PATH` is accessible from all models
- [ ] `MODEL_DIR` points to correct location
- [ ] `initialize()` logs success message
- [ ] No import errors in logs
- [ ] All models show as READY in Triton
- [ ] Server becomes ready (health check passes)

---

## 10. Testing Strategy

1. **Test imports manually**:
   ```bash
   docker exec <container> python3 -c "
   import sys
   sys.path.insert(0, '/workspace/shared_comfyui')
   sys.path.insert(0, '/models/latent_encoder/1')
   from service import encode_image_to_latent
   print('Import successful')
   "
   ```

2. **Check paths**:
   ```bash
   docker exec <container> python3 -c "
   import os
   print('COMFYUI_PATH:', os.getenv('COMFYUI_PATH'))
   print('MODEL_DIR:', os.getenv('MODEL_DIR'))
   from pathlib import Path
   print('ComfyUI exists:', Path(os.getenv('COMFYUI_PATH')).exists())
   print('Models dir exists:', Path(os.getenv('MODEL_DIR')).exists())
   "
   ```

3. **Test model initialization**:
   - Check Triton logs for initialization messages
   - Look for any error messages
   - Verify all models show as READY

---

## Summary

**Critical Issues**:
1. 🔴 **service.py hardcodes ComfyUI path** - Will fail when setup_comfyui() is called
2. 🟡 **Missing error handling** - Import errors not caught
3. 🟡 **Config path fallback** - Uses relative path if env var missing

**These issues could cause**:
- Models to initialize successfully but fail on first request
- Silent failures that are hard to debug
- Path resolution errors

**Next Steps**: Apply fixes above, rebuild, and test.


