# How setup.sh Integrates with Triton Ensemble

## Your Questions Answered

### Q1: How does setup.sh tie into the final Triton ensemble?

**Answer**: setup.sh serves **two different purposes**:

1. **Development/Testing** (Current): Sets up isolated environment for standalone testing
2. **Triton Preparation** (New): Prepares code and models for Triton deployment

**Key Insight**: Triton Python backend uses the **container's Python environment**, NOT the microservice venv. So setup.sh's venv creation is for testing only.

### Q2: How does environmental setup shape into the final Triton ensemble?

**Current setup.sh does**:
- ✅ Creates venv → **Used for testing, NOT by Triton**
- ✅ Installs PyTorch → **Needed in Triton container**
- ✅ Clones ComfyUI → **Needed in Triton model repository**
- ✅ Installs requirements → **Needed in Triton container**
- ✅ Downloads models → **Needed in Triton model repository**

**For Triton, we need**:
1. **Dependencies in Container**: Install in Docker image (not venv)
2. **ComfyUI in Model Repo**: Copy to model directories or shared location
3. **Models in Model Repo**: Download to shared_models directory
4. **Service Code in Model Repo**: Copy to each model's version directory

### Q3: Model download concerns - how are models handled?

**Current Problem**:
- setup.sh downloads to `microservices/<service>/models/`
- Each service has its own models directory
- Models are duplicated across services (VAE used by multiple services)

**Triton Solution**:

#### Option A: Shared Models Directory (Recommended)
```
triton_model_repository/
├── shared_models/              # Download once, share across all models
│   ├── vae/
│   │   └── qwen_image_vae.safetensors
│   ├── clip/
│   ├── diffusion_models/
│   └── loras/
├── latent_encoder/
│   └── 1/
│       └── model.py            # References shared_models via env var
└── text_encoder/
    └── 1/
        └── model.py            # References shared_models via env var
```

**Benefits**:
- ✅ Download models once
- ✅ Save storage space
- ✅ Easy to update models
- ✅ Models accessible to all services

**Implementation**:
```python
# In model.py initialize():
import os
model_dir = pb_utils.get_model_dir()
shared_models = os.getenv('SHARED_MODELS_DIR', '/models/shared_models')
Config.model_dir = shared_models
```

#### Option B: Per-Model Directory
```
triton_model_repository/
├── latent_encoder/
│   └── 1/
│       ├── model.py
│       └── models/             # Models copied here
│           └── vae/
└── text_encoder/
    └── 1/
        ├── model.py
        └── models/              # Models copied here
            ├── vae/            # Duplicated
            └── clip/
```

**Benefits**:
- ✅ Complete isolation
- ✅ Models bundled with model code

**Drawbacks**:
- ❌ Duplicate storage (VAE in multiple places)
- ❌ More complex updates

**Recommendation**: Use **Option A (Shared Models)** for VastAI deployment.

---

## Updated setup.sh Strategy

### Current setup.sh (Keep for Testing)
```bash
# Current: Sets up venv, installs deps, downloads models to microservice dir
./setup.sh  # Creates: microservices/text_encoder/models/
```

### New: setup_triton_repository.sh (For Triton)
```bash
# New: Prepares Triton model repository
./setup_triton_repository.sh  # Creates: triton_model_repository/shared_models/
```

**What setup_triton_repository.sh does**:
1. Creates Triton model repository structure
2. Copies service code to model directories
3. Sets up ComfyUI (shared or per-model)
4. Downloads models to `shared_models/` directory
5. Creates symlinks or configs for model paths
6. Generates config.pbtxt templates

---

## Model Download Flow

### Development Flow:
```
setup.sh (in microservice)
  ↓
Downloads to: microservices/text_encoder/models/
  ↓
Test service: python main.py --mode standalone
```

### Triton Preparation Flow:
```
setup_triton_repository.sh
  ↓
Downloads to: triton_model_repository/shared_models/
  ↓
Copies code to: triton_model_repository/text_encoder/1/
  ↓
Triton uses: /models/shared_models/ (mounted volume)
```

### Docker Build Flow:
```
Dockerfile.triton
  ↓
RUN setup_triton_repository.sh (or COPY pre-built repo)
  ↓
Models in image: /models/shared_models/
  ↓
Runtime: Mount or use image models
```

---

## Environment Variables in Triton

### Container-Level (Dockerfile):
```dockerfile
ENV PYTHONPATH=/opt/comfyui:$PYTHONPATH
ENV COMFYUI_PATH=/opt/comfyui
ENV SHARED_MODELS_DIR=/models/shared_models
ENV MODEL_DIR=/models/shared_models
```

### Model-Level (model.py):
```python
def initialize(self, args):
    # Get from environment or use defaults
    shared_models = os.getenv('SHARED_MODELS_DIR', '/models/shared_models')
    comfyui_path = os.getenv('COMFYUI_PATH', '/opt/comfyui')
    
    # Add to Python path
    sys.path.insert(0, comfyui_path)
    
    # Configure model paths
    from config import Config
    Config.model_dir = shared_models
```

---

## Complete Integration Flow

### Step 1: Development Setup (Current)
```bash
cd microservices/text_encoder
./setup.sh
# Creates: venv/, comfyui/, models/
```

### Step 2: Test & Extract Info
```bash
source venv/bin/activate
python main.py --mode standalone --image1_path test.jpg --no-save
# Extract: tensor shapes, data types, model paths
```

### Step 3: Prepare Triton Repository
```bash
cd microservices
./setup_triton_repository.sh
# Creates: ../triton_model_repository/
#   - shared_models/ (models downloaded once)
#   - text_encoder/1/ (code copied)
#   - text_encoder/config.pbtxt (generated from extracted info)
```

### Step 4: Build Triton Container
```dockerfile
FROM nvcr.io/nvidia/tritonserver:25.10-py3
# Install dependencies (from setup.sh requirements)
RUN pip install -r requirements.txt
# Copy prepared repository
COPY triton_model_repository /models
# Set environment
ENV SHARED_MODELS_DIR=/models/shared_models
```

### Step 5: Run Triton
```bash
docker run --gpus=1 \
  -v $(pwd)/triton_model_repository:/models \
  vtryon-triton:latest \
  tritonserver --model-repository=/models
```

---

## Model Path Resolution in Triton

### In service.py (Current):
```python
# Uses Config.model_dir from config.py
vae_path = Config.get_vae_model_path()
# Returns: ./models/vae/qwen_image_vae.safetensors
```

### In model.py (Triton):
```python
# Override Config.model_dir to point to shared models
import os
from config import Config

def initialize(self, args):
    # Get shared models directory from environment
    shared_models = os.getenv('SHARED_MODELS_DIR', '/models/shared_models')
    Config.model_dir = shared_models
    
    # Now Config.get_vae_model_path() returns:
    # /models/shared_models/vae/qwen_image_vae.safetensors
```

**Key**: Service code doesn't need changes, just configure `Config.model_dir` in `model.py` initialization.

---

## Summary

1. **setup.sh**: Keeps current functionality for standalone testing
2. **setup_triton_repository.sh**: New script that prepares Triton model repository
3. **Model Downloads**: Use shared_models directory, download once, reference from all models
4. **Environment**: Dependencies installed in Docker container, not venv
5. **ComfyUI**: Shared location or per-model, configured via environment variables
6. **Model Paths**: Configured via environment variables in Triton, service code unchanged

**The key insight**: setup.sh is for **development/testing**, while Triton uses a **different structure** prepared by `setup_triton_repository.sh` and deployed via Docker.

