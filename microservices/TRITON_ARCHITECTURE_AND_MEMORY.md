# Triton Architecture, Memory Management, and Code Flow

## Overview: How Triton Works

Triton Inference Server is a C++ application that manages model inference. For Python models, it uses a **Python backend** that runs Python code in separate processes.

---

## 1. Triton's Main Code Location

### Core Triton Server (C++)
- **Location**: `triton-server/src/`
- **Main entry**: `triton-server/src/main.cc` or `triton-server/src/tritonserver.cc`
- **Language**: C++
- **Purpose**: 
  - Manages model repository scanning
  - Handles HTTP/gRPC requests
  - Coordinates backends (Python, TensorRT, ONNX, etc.)
  - Manages memory pools (CPU pinned memory, CUDA memory)
  - Routes requests to appropriate backend

### Python Backend
- **Location**: `triton-server/src/backends/python/` (C++ wrapper)
- **Python stub**: `/opt/tritonserver/backends/python/triton_python_backend_stub`
- **How it works**:
  1. Triton C++ server spawns a Python stub process for each model instance
  2. Stub process loads your `model.py` file
  3. Stub communicates with Triton via shared memory
  4. Your Python code runs in this separate process

### Your Model Code
- **Location**: `/models/<model-name>/1/model.py`
- **Example**: `/models/latent_encoder/1/model.py`
- **Structure**:
  ```python
  class TritonPythonModel:
      def initialize(self, args):  # Called once when model loads
      def execute(self, requests):  # Called for each inference request
      def finalize(self):           # Called when model unloads
  ```

---

## 2. Memory Management Architecture

### A. Triton's Memory Management (C++ Layer)

#### 1. **Memory Pools**
Triton pre-allocates memory pools for efficiency:

```cpp
// From tritonserver logs:
pinned_memory_pool_byte_size = 268435456  // 256 MB pinned CPU memory
cuda_memory_pool_byte_size{0} = 67108864  // 64 MB CUDA memory pool per GPU
```

**Purpose**:
- **Pinned Memory**: Fast CPU↔GPU transfers (page-locked)
- **CUDA Memory Pool**: Pre-allocated GPU memory for tensors
- Reduces allocation overhead during inference

#### 2. **Shared Memory (Python Backend)**
- Each Python model instance runs in a separate process
- Communication via shared memory regions:
  ```
  triton_python_backend_shm_region_<uuid>  # Shared memory for IPC
  ```
- Size: Default 1MB, grows as needed

#### 3. **Tensor Memory**
- Input/output tensors are passed via shared memory
- Triton handles CPU↔GPU transfers automatically
- Memory is managed by Triton's allocator

### B. Python Model Memory (Your Code)

#### 1. **Model Initialization** (`initialize()`)
```python
def initialize(self, args):
    # This runs ONCE when model loads
    # Memory allocated here persists until finalize()
    
    # Example: Load PyTorch model
    self.model = torch.load(...)  # Stays in memory
    self.model.to('cuda')         # GPU memory allocated
```

**Memory Lifecycle**:
- Allocated: When `initialize()` runs
- Persists: Until `finalize()` or model unload
- Shared: Across all requests to this model instance

#### 2. **Request Execution** (`execute()`)
```python
def execute(self, requests):
    # This runs for EACH inference request
    # Memory allocated here is temporary (per request)
    
    for request in requests:
        # Get input tensor (shared memory, no copy)
        input_tensor = pb_utils.get_input_tensor_by_name(request, "input")
        input_np = input_tensor.as_numpy()  # View, not copy
        
        # Process (may allocate temporary GPU memory)
        result = self.model(input_np)
        
        # Create output tensor (Triton manages memory)
        output = pb_utils.Tensor("output", result)
        responses.append(pb_utils.InferenceResponse([output]))
    
    return responses
```

**Memory Behavior**:
- Input tensors: Shared memory (no copy)
- Processing: Temporary allocations (PyTorch/ComfyUI)
- Output tensors: Managed by Triton
- Cleanup: Automatic after response sent

### C. ComfyUI Memory Management

ComfyUI has its own memory management system:

#### 1. **Model Loading** (`comfy/model_management.py`)
```python
# From your codebase:
def load_models_gpu(models, memory_required=0, ...):
    # Checks available VRAM
    # Unloads unused models if needed
    # Loads requested models to GPU
    # Tracks loaded models in current_loaded_models[]
```

**Key Functions**:
- `load_models_gpu()`: Loads models, manages VRAM
- `free_memory()`: Unloads models to free VRAM
- `current_loaded_models[]`: Tracks what's loaded

#### 2. **Lazy Loading Strategy**
In your implementation:
```python
# In service.py:
def encode_image_to_latent(...):
    # ComfyUI models are loaded ON-DEMAND (lazy)
    # Not loaded during initialize()
    # Loaded when first request comes in
    # Stays loaded for subsequent requests
```

**Benefits**:
- Faster startup (models not loaded until needed)
- Better memory efficiency (only load what's used)
- Can unload unused models to free VRAM

#### 3. **Memory Sharing**
- **Shared ComfyUI**: All models use same ComfyUI code (saves RAM)
- **Shared Model Files**: All models access `/workspace/shared_models/` (saves disk)
- **GPU Memory**: ComfyUI manages per-model (VAE, CLIP, UNET loaded separately)

---

## 3. Complete Request Flow

### Step-by-Step: What Happens When You Send a Request

```
1. Client Request
   ↓
   HTTP/gRPC → Triton C++ Server
   ↓
2. Request Routing
   Triton identifies model (e.g., "latent_encoder")
   ↓
3. Backend Selection
   Triton sees backend: "python"
   ↓
4. Python Backend Process
   - Stub process already running (spawned at model load)
   - Request sent via shared memory
   ↓
5. Your model.py execute()
   - Receives InferenceRequest objects
   - Extracts input tensors
   - Calls service function
   ↓
6. Service Function (service.py)
   - setup_comfyui() if first call (lazy init)
   - Load models if needed (ComfyUI memory management)
   - Process inference
   ↓
7. ComfyUI Processing
   - Uses loaded models (VAE, CLIP, etc.)
   - Allocates temporary GPU memory
   - Returns result tensor
   ↓
8. Response Creation
   - Convert to Triton Tensor
   - Return InferenceResponse
   ↓
9. Triton C++ Server
   - Receives response via shared memory
   - Sends to client
   ↓
10. Memory Cleanup
    - Temporary allocations freed
    - Models stay loaded (for next request)
```

---

## 4. Memory Management in Your Approach

### Current Structure:
```
/models/                          # Triton model repository
├── latent_encoder/1/model.py    # Your code (runs in Python process)
├── text_encoder/1/model.py
├── sampling/1/model.py
└── decoding/1/model.py

/workspace/                       # Outside model repository
├── shared_comfyui/               # Shared code (loaded once per process)
└── shared_models/                # Shared model files (loaded on-demand)
    ├── vae/
    ├── clip/
    ├── diffusion_models/
    └── loras/
```

### Memory Allocation:

#### **Per Model Instance** (4 instances total):
- **Python Process**: ~100-200 MB RAM per instance
- **ComfyUI Code**: Shared via `sys.path` (no duplication)
- **Model Files**: Shared via `/workspace/shared_models/` (no duplication)

#### **Per Request**:
- **Input Tensors**: Shared memory (no copy)
- **Processing**: Temporary GPU allocations (freed after request)
- **Output Tensors**: Managed by Triton

#### **GPU Memory** (ComfyUI managed):
- **VAE**: ~500 MB (loaded when needed)
- **CLIP**: ~7 GB (loaded when needed)
- **UNET**: ~3 GB (loaded when needed)
- **LoRA**: ~100 MB (loaded when needed)

**Total GPU Memory**: ~10.6 GB when all models loaded

---

## 5. Key Code Locations

### Your Code:
1. **Model Entry Points**: 
   - `/models/latent_encoder/1/model.py`
   - `/models/text_encoder/1/model.py`
   - `/models/sampling/1/model.py`
   - `/models/decoding/1/model.py`

2. **Service Logic**:
   - `/models/latent_encoder/1/service.py`
   - `/models/text_encoder/1/service.py`
   - etc.

3. **Configuration**:
   - `/models/latent_encoder/1/config.py`
   - `/models/latent_encoder/config.pbtxt`

### Triton Core (if you want to explore):
1. **Server Main**: `triton-server/src/tritonserver.cc`
2. **Python Backend**: `triton-server/src/backends/python/python_be.cc`
3. **Memory Management**: `triton-server/src/memory_alloc.cc`
4. **Model Lifecycle**: `triton-server/src/model_lifecycle.cc`

### ComfyUI Memory Management:
- `triton_model_repository/shared_comfyui/comfy/model_management.py`
- Key functions: `load_models_gpu()`, `free_memory()`

---

## 6. Memory Optimization Strategies

### Current Approach (Good):
1. ✅ **Shared ComfyUI**: One copy of code, all models use it
2. ✅ **Shared Models**: One copy of model files, all models access
3. ✅ **Lazy Loading**: Models loaded on-demand
4. ✅ **Triton Memory Pools**: Pre-allocated for efficiency

### Potential Improvements:
1. **Model Unloading**: ComfyUI can unload unused models
2. **Memory Monitoring**: Track GPU memory usage
3. **Batch Processing**: Process multiple requests together (if configured)

---

## 7. Debugging Memory Issues

### Check Memory Usage:
```bash
# Inside container
nvidia-smi                    # GPU memory
free -h                       # RAM
ps aux | grep python          # Python process memory
```

### Triton Logs:
- Look for memory pool sizes in startup logs
- Check for OOM errors
- Monitor model loading/unloading

### ComfyUI Logs:
- Check `model_management.py` logs
- See which models are loaded
- Monitor VRAM usage

---

## Summary

**Triton's Role**:
- C++ server manages requests, routing, memory pools
- Spawns Python processes for each model instance
- Handles tensor transfers (CPU↔GPU)

**Your Code's Role**:
- `model.py`: Interface with Triton (initialize/execute/finalize)
- `service.py`: Business logic (ComfyUI, model loading)
- Memory: Managed by ComfyUI's `model_management.py`

**Memory Flow**:
1. Triton pre-allocates pools (CPU pinned, CUDA)
2. Python process loads models on-demand (lazy)
3. Requests use shared memory (no copies)
4. ComfyUI manages GPU memory (load/unload as needed)
5. Temporary allocations freed after each request

This architecture provides:
- ✅ Isolation (each model in separate process)
- ✅ Efficiency (shared code, lazy loading)
- ✅ Scalability (Triton handles routing/batching)
- ✅ Memory safety (automatic cleanup)


