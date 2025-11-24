# Triton Ensemble Server - Updated Implementation Plan

## Key Insights from Triton Server Analysis

### 1. **Model Repository Structure**
```
triton_model_repository/
├── latent_encoder/
│   ├── config.pbtxt
│   └── 1/                          # Version directory
│       ├── model.py                 # Python backend entry point
│       ├── service.py               # Copied from microservice
│       ├── config.py                # Copied from microservice
│       ├── utils.py                 # Copied from microservice
│       ├── comfyui/                 # ComfyUI modules (symlink or copy)
│       └── models/                  # Model files (VAE encoder)
│           └── vae/
│               └── qwen_image_vae.safetensors
├── text_encoder/
│   ├── config.pbtxt
│   └── 1/
│       ├── model.py
│       ├── service.py
│       ├── config.py
│       ├── utils.py
│       ├── comfyui/
│       └── models/
│           ├── clip/
│           └── vae/
├── sampling/
│   └── (similar structure)
├── decoding/
│   └── (similar structure)
└── vtryon_pipeline/
    └── config.pbtxt                 # Ensemble config only
```

### 2. **Python Backend Model Access**
- Models access files via `pb_utils.get_model_dir()` - returns path to `<model-name>/<version>/`
- Can import Python modules from model directory
- Environment variables are accessible via `os.environ`
- Model initialization happens once per model instance

### 3. **Model Download Strategy**
**Problem**: Current setup.sh downloads models to `microservices/<service>/models/`, but Triton models need models in their own directories.

**Solution Options**:
1. **Shared Models Directory** (Recommended for VastAI)
   - Download models once to `/models/shared/`
   - Symlink or reference from each model directory
   - Reduces storage and download time

2. **Per-Model Directory** (Better isolation)
   - Copy models to each model's `1/models/` directory
   - More storage but better isolation

3. **Hybrid Approach** (Best for development)
   - Shared models for large files (VAE, UNET)
   - Per-model for service-specific models

---

## Updated Implementation Plan

### Phase 1: Information Extraction via Testing (Current Priority)

**Goal**: Run each service in standalone mode to extract Triton configuration requirements.

**Why This First**: 
- Need actual input/output shapes and data types
- Need to understand tensor formats
- Need to identify model file paths and dependencies
- Need to measure performance characteristics

**Tasks**:

#### 1.1 Test Latent Encoder
```bash
cd microservices/latent_encoder
source venv/bin/activate
python main.py --mode standalone --image_path test.jpg --no-save
```

**Extract**:
- Input: Image tensor shape (e.g., `[1, 3, 1024, 1024]` FP32)
- Output: Latent tensor shape (e.g., `[1, 4, 64, 64]` FP32)
- Model files needed: VAE encoder path
- ComfyUI dependencies: Which modules are used
- Processing time: For performance tuning

#### 1.2 Test Text Encoder
```bash
cd microservices/text_encoder
source venv/bin/activate
python main.py --mode standalone --image1_path test1.jpg --image2_path test2.jpg --prompt "test" --no-save
```

**Extract**:
- Inputs: 
  - image1: `[1, 3, 1024, 1024]` FP32
  - image2: `[1, 3, 1024, 1024]` FP32
  - prompt: STRING
- Outputs:
  - positive_encoding: `[1, 77, 2048]` FP32
  - negative_encoding: `[1, 77, 2048]` FP32
- Model files: CLIP + VAE paths

#### 1.3 Test Sampling
```bash
cd microservices/sampling
source venv/bin/activate
python main.py --mode standalone \
  --positive_encoding ../text_encoder/output/positive.pt \
  --negative_encoding ../text_encoder/output/negative.pt \
  --latent_image ../latent_encoder/output/latent.pt \
  --no-save
```

**Extract**:
- Inputs: Encodings + latent shapes
- Output: Sampled latent shape
- Model files: UNET + LoRA paths

#### 1.4 Test Decoding
```bash
cd microservices/decoding
source venv/bin/activate
python main.py --mode standalone \
  --latent ../sampling/output/sampled_latent.pt \
  --no-save
```

**Extract**:
- Input: Latent tensor shape
- Output: Image tensor shape
- Model files: VAE decoder path

#### 1.5 Document Extracted Information
Create `TRITON_CONFIG_EXTRACTED.md` with:
- Tensor shapes and data types for each service
- Model file paths and structure
- ComfyUI module dependencies
- Performance characteristics
- Memory requirements

---

### Phase 2: Triton Model Repository Setup

**Goal**: Create proper Triton model repository structure with all dependencies.

#### 2.1 Create Repository Structure
```bash
mkdir -p triton_model_repository/{latent_encoder,text_encoder,sampling,decoding,vtryon_pipeline}/{1}
```

#### 2.2 Setup Shared Models Directory
**Strategy**: Create shared models directory that all models can access.

```bash
# Create shared models directory
mkdir -p triton_model_repository/shared_models/{vae,clip,diffusion_models,loras}

# Download models once (or symlink from microservices)
# Models will be referenced via environment variable or absolute path
```

**Model Organization**:
```
triton_model_repository/
├── shared_models/              # Shared model files
│   ├── vae/
│   │   └── qwen_image_vae.safetensors
│   ├── clip/
│   │   └── qwen_2.5_vl_7b_fp8_scaled.safetensors
│   ├── diffusion_models/
│   │   └── qwen_image_edit_2509_fp8_e4m3fn.safetensors
│   └── loras/
│       └── Qwen-Image-Lightning-4steps-V2.0.safetensors
├── latent_encoder/
│   └── 1/
│       └── models -> ../../shared_models  # Symlink or env var
└── ...
```

#### 2.3 Copy Service Code to Model Directories
**Strategy**: Copy necessary files from microservices to each model's version directory.

```bash
# For each service:
cp microservices/latent_encoder/{service.py,config.py,utils.py,errors.py} \
   triton_model_repository/latent_encoder/1/
```

#### 2.4 Setup ComfyUI in Model Directories
**Options**:

**Option A: Shared ComfyUI** (Recommended - saves space)
```bash
# Copy ComfyUI once to shared location
cp -r microservices/latent_encoder/comfyui triton_model_repository/shared_comfyui/

# In each model's model.py, add to sys.path:
import sys
sys.path.insert(0, '/path/to/triton_model_repository/shared_comfyui')
```

**Option B: Per-Model ComfyUI** (Better isolation)
```bash
# Copy ComfyUI to each model directory
cp -r microservices/latent_encoder/comfyui triton_model_repository/latent_encoder/1/
```

**Recommendation**: Use shared ComfyUI with environment variable pointing to it.

#### 2.5 Create Model Configuration Files
Based on extracted information from Phase 1, create `config.pbtxt` for each model.

---

### Phase 3: Python Backend Implementation

**Goal**: Create `model.py` for each service that implements Triton Python backend interface.

#### 3.1 Template Structure
Each `model.py` will:
1. **Initialize**: Load models, setup ComfyUI, prepare environment
2. **Execute**: Process inference requests, convert tensors, call service logic
3. **Finalize**: Cleanup resources

#### 3.2 Key Implementation Details

**Model Initialization**:
```python
def initialize(self, args):
    # Get model directory
    model_dir = pb_utils.get_model_dir()
    
    # Setup paths
    sys.path.insert(0, os.path.join(model_dir, 'comfyui'))
    sys.path.insert(0, model_dir)
    
    # Load configuration
    from config import Config
    Config.model_dir = os.path.join(model_dir, 'models')
    
    # Initialize service (load models, setup ComfyUI)
    # This happens once per model instance
```

**Model Execution**:
```python
def execute(self, requests):
    responses = []
    for request in requests:
        # Extract input tensors
        image_tensor = pb_utils.get_input_tensor_by_name(request, "input_image")
        image_array = image_tensor.as_numpy()
        
        # Call service function
        result = encode_image_to_latent(image_array, ...)
        
        # Convert to output tensor
        output_tensor = pb_utils.Tensor("latent", result['latent_tensor'])
        response = pb_utils.InferenceResponse([output_tensor])
        responses.append(response)
    
    return responses
```

#### 3.3 Handle Tensor Conversions
- Convert numpy arrays to/from Triton tensors
- Handle batch dimensions
- Manage data type conversions (FP32, INT64, STRING)

---

### Phase 4: Environment & Dependency Management

**Critical Understanding**: Triton Python backend uses the Python environment from the Triton container, NOT the microservice venv.

#### 4.1 Dependency Strategy

**Option A: Install in Triton Container** (Recommended for VastAI)
- Build custom Triton Docker image with all dependencies
- Install ComfyUI requirements + microservice requirements
- Models use system Python environment

**Option B: Bundle Dependencies** (More complex)
- Package dependencies with each model
- Use virtual environments per model (complex)

**Recommendation**: Build custom Triton image with all dependencies.

#### 4.2 Custom Triton Dockerfile
```dockerfile
FROM nvcr.io/nvidia/tritonserver:25.10-py3

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt /tmp/
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Copy ComfyUI modules (or mount as volume)
COPY comfyui /opt/comfyui

# Set environment variables
ENV PYTHONPATH=/opt/comfyui:$PYTHONPATH
ENV COMFYUI_PATH=/opt/comfyui
ENV MODEL_DIR=/models/shared_models

# Copy model repository
COPY triton_model_repository /models

# Expose ports
EXPOSE 8000 8001 8002
```

#### 4.3 Model Download Integration

**Current setup.sh downloads models to**: `microservices/<service>/models/`

**For Triton, we need**:
1. **Development/Testing**: Keep current structure, symlink or copy to Triton repo
2. **Production/VastAI**: Download models directly to Triton model repository

**Updated setup.sh Strategy**:
```bash
# Add Triton model repository setup option
if [ "$SETUP_FOR_TRITON" = "true" ]; then
    TRITON_REPO="${TRITON_MODEL_REPOSITORY:-../triton_model_repository}"
    MODELS_DIR="${TRITON_REPO}/shared_models"
else
    MODELS_DIR="${MICROSERVICE_DIR}/models"
fi
```

**Or create separate script**: `setup_triton_models.sh`

---

### Phase 5: Ensemble Configuration

**Goal**: Create ensemble model that chains all services together.

#### 5.1 Ensemble Config Structure
```protobuf
name: "vtryon_pipeline"
platform: "ensemble"
max_batch_size: 1

input [
  {
    name: "image1"
    data_type: TYPE_FP32
    dims: [ 1, 3, 1024, 1024 ]
  },
  {
    name: "image2"
    data_type: TYPE_FP32
    dims: [ 1, 3, 1024, 1024 ]
  },
  {
    name: "prompt"
    data_type: TYPE_STRING
    dims: [ 1 ]
  }
]

output [
  {
    name: "output_image"
    data_type: TYPE_FP32
    dims: [ 1, 3, 1024, 1024 ]
  }
]

ensemble_scheduling {
  step [
    {
      model_name: "latent_encoder"
      model_version: -1
      input_map { key: "input_image", value: "image1" }
      output_map { key: "latent", value: "latent_enc" }
    },
    {
      model_name: "text_encoder"
      model_version: -1
      input_map { key: "image1", value: "image1" }
      input_map { key: "image2", value: "image2" }
      input_map { key: "prompt", value: "prompt" }
      output_map { key: "positive_encoding", value: "pos_enc" }
      output_map { key: "negative_encoding", value: "neg_enc" }
    },
    {
      model_name: "sampling"
      model_version: -1
      input_map { key: "positive_encoding", value: "pos_enc" }
      input_map { key: "negative_encoding", value: "neg_enc" }
      input_map { key: "latent", value: "latent_enc" }
      output_map { key: "sampled_latent", value: "sampled_lat" }
    },
    {
      model_name: "decoding"
      model_version: -1
      input_map { key: "latent", value: "sampled_lat" }
      output_map { key: "image", value: "output_image" }
    }
  ]
}
```

---

### Phase 6: Local Testing

#### 6.1 Test Individual Models
```bash
# Start Triton
docker run --gpus=1 --rm -p 8000:8000 -p 8001:8001 -p 8002:8002 \
  -v $(pwd)/triton_model_repository:/models \
  nvcr.io/nvidia/tritonserver:25.10-py3 \
  tritonserver --model-repository=/models

# Test each model
curl -X POST http://localhost:8000/v2/models/latent_encoder/infer \
  -H "Content-Type: application/json" \
  -d @test_request.json
```

#### 6.2 Test Ensemble
```bash
curl -X POST http://localhost:8000/v2/models/vtryon_pipeline/infer \
  -H "Content-Type: application/json" \
  -d @test_pipeline_request.json
```

---

### Phase 7: VastAI Deployment

#### 7.1 Build Custom Triton Image
```bash
docker build -t vtryon-triton:latest -f Dockerfile.triton .
```

#### 7.2 Push to Registry
```bash
docker tag vtryon-triton:latest your-registry/vtryon-triton:latest
docker push your-registry/vtryon-triton:latest
```

#### 7.3 Deploy on VastAI
- Create instance with GPU
- Pull image
- Mount model repository (or download models on instance)
- Run Triton server

---

## How setup.sh Ties into Triton

### Current setup.sh Flow:
1. Creates venv → **Not used by Triton** (Triton uses container Python)
2. Installs PyTorch → **Needed in Triton container**
3. Clones ComfyUI → **Needed in Triton model repo or shared location**
4. Installs requirements → **Needed in Triton container**
5. Downloads models → **Needed in Triton model repo structure**

### For Triton Integration:

**setup.sh becomes**:
1. **Development setup**: Keep current functionality for standalone testing
2. **Triton preparation**: New mode that prepares Triton model repository

**New script: `setup_triton_repository.sh`**:
- Copies service code to model directories
- Sets up ComfyUI (shared or per-model)
- Downloads/copies models to shared_models directory
- Creates symlinks or configs for model paths
- Generates config.pbtxt files (or templates)

**Dockerfile.triton**:
- Uses setup.sh to install dependencies in container
- Copies prepared model repository
- Sets up environment variables

---

## Model Download Concerns - Addressed

### Concern 1: Duplicate Downloads
**Solution**: Use shared_models directory, download once, reference from all models.

### Concern 2: Model Paths in Code
**Solution**: 
- Use environment variables: `MODEL_DIR=/models/shared_models`
- Or use `pb_utils.get_model_dir()` and relative paths
- Update config.py to support both standalone and Triton modes

### Concern 3: Model Size
**Solution**: 
- Download models during Docker build (cached in image)
- Or download on first run (with caching)
- Or mount models as volume on VastAI

### Concern 4: Model Updates
**Solution**:
- Models in shared_models can be updated independently
- Use model versioning in Triton
- Hot-reload models without restarting server

---

## Updated Timeline

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Phase 1: Extract Info via Testing | 1-2 days | ✅ Ready now |
| Phase 2: Setup Repository | 1 day | Phase 1 complete |
| Phase 3: Python Backend | 2-3 days | Phase 2 complete |
| Phase 4: Environment Setup | 1-2 days | Phase 3 complete |
| Phase 5: Ensemble Config | 1 day | Phase 3 complete |
| Phase 6: Local Testing | 1-2 days | All phases |
| Phase 7: VastAI Deployment | 1 day | Phase 6 complete |
| **Total** | **8-12 days** | |

---

## Next Immediate Steps

1. **Test each service** to extract tensor shapes and dependencies
2. **Document extracted information** in `TRITON_CONFIG_EXTRACTED.md`
3. **Create Triton model repository structure**
4. **Create `setup_triton_repository.sh`** script
5. **Implement Python backend models** based on extracted info

---

## Key Files to Create

1. `triton_model_repository/` - Model repository structure
2. `setup_triton_repository.sh` - Setup script for Triton
3. `Dockerfile.triton` - Custom Triton container
4. `TRITON_CONFIG_EXTRACTED.md` - Extracted configuration info
5. `triton_model_repository/*/1/model.py` - Python backend implementations
6. `triton_model_repository/*/config.pbtxt` - Model configurations


## Key Insights from Triton Server Analysis

### 1. **Model Repository Structure**
```
triton_model_repository/
├── latent_encoder/
│   ├── config.pbtxt
│   └── 1/                          # Version directory
│       ├── model.py                 # Python backend entry point
│       ├── service.py               # Copied from microservice
│       ├── config.py                # Copied from microservice
│       ├── utils.py                 # Copied from microservice
│       ├── comfyui/                 # ComfyUI modules (symlink or copy)
│       └── models/                  # Model files (VAE encoder)
│           └── vae/
│               └── qwen_image_vae.safetensors
├── text_encoder/
│   ├── config.pbtxt
│   └── 1/
│       ├── model.py
│       ├── service.py
│       ├── config.py
│       ├── utils.py
│       ├── comfyui/
│       └── models/
│           ├── clip/
│           └── vae/
├── sampling/
│   └── (similar structure)
├── decoding/
│   └── (similar structure)
└── vtryon_pipeline/
    └── config.pbtxt                 # Ensemble config only
```

### 2. **Python Backend Model Access**
- Models access files via `pb_utils.get_model_dir()` - returns path to `<model-name>/<version>/`
- Can import Python modules from model directory
- Environment variables are accessible via `os.environ`
- Model initialization happens once per model instance

### 3. **Model Download Strategy**
**Problem**: Current setup.sh downloads models to `microservices/<service>/models/`, but Triton models need models in their own directories.

**Solution Options**:
1. **Shared Models Directory** (Recommended for VastAI)
   - Download models once to `/models/shared/`
   - Symlink or reference from each model directory
   - Reduces storage and download time

2. **Per-Model Directory** (Better isolation)
   - Copy models to each model's `1/models/` directory
   - More storage but better isolation

3. **Hybrid Approach** (Best for development)
   - Shared models for large files (VAE, UNET)
   - Per-model for service-specific models

---

## Updated Implementation Plan

### Phase 1: Information Extraction via Testing (Current Priority)

**Goal**: Run each service in standalone mode to extract Triton configuration requirements.

**Why This First**: 
- Need actual input/output shapes and data types
- Need to understand tensor formats
- Need to identify model file paths and dependencies
- Need to measure performance characteristics

**Tasks**:

#### 1.1 Test Latent Encoder
```bash
cd microservices/latent_encoder
source venv/bin/activate
python main.py --mode standalone --image_path test.jpg --no-save
```

**Extract**:
- Input: Image tensor shape (e.g., `[1, 3, 1024, 1024]` FP32)
- Output: Latent tensor shape (e.g., `[1, 4, 64, 64]` FP32)
- Model files needed: VAE encoder path
- ComfyUI dependencies: Which modules are used
- Processing time: For performance tuning

#### 1.2 Test Text Encoder
```bash
cd microservices/text_encoder
source venv/bin/activate
python main.py --mode standalone --image1_path test1.jpg --image2_path test2.jpg --prompt "test" --no-save
```

**Extract**:
- Inputs: 
  - image1: `[1, 3, 1024, 1024]` FP32
  - image2: `[1, 3, 1024, 1024]` FP32
  - prompt: STRING
- Outputs:
  - positive_encoding: `[1, 77, 2048]` FP32
  - negative_encoding: `[1, 77, 2048]` FP32
- Model files: CLIP + VAE paths

#### 1.3 Test Sampling
```bash
cd microservices/sampling
source venv/bin/activate
python main.py --mode standalone \
  --positive_encoding ../text_encoder/output/positive.pt \
  --negative_encoding ../text_encoder/output/negative.pt \
  --latent_image ../latent_encoder/output/latent.pt \
  --no-save
```

**Extract**:
- Inputs: Encodings + latent shapes
- Output: Sampled latent shape
- Model files: UNET + LoRA paths

#### 1.4 Test Decoding
```bash
cd microservices/decoding
source venv/bin/activate
python main.py --mode standalone \
  --latent ../sampling/output/sampled_latent.pt \
  --no-save
```

**Extract**:
- Input: Latent tensor shape
- Output: Image tensor shape
- Model files: VAE decoder path

#### 1.5 Document Extracted Information
Create `TRITON_CONFIG_EXTRACTED.md` with:
- Tensor shapes and data types for each service
- Model file paths and structure
- ComfyUI module dependencies
- Performance characteristics
- Memory requirements

---

### Phase 2: Triton Model Repository Setup

**Goal**: Create proper Triton model repository structure with all dependencies.

#### 2.1 Create Repository Structure
```bash
mkdir -p triton_model_repository/{latent_encoder,text_encoder,sampling,decoding,vtryon_pipeline}/{1}
```

#### 2.2 Setup Shared Models Directory
**Strategy**: Create shared models directory that all models can access.

```bash
# Create shared models directory
mkdir -p triton_model_repository/shared_models/{vae,clip,diffusion_models,loras}

# Download models once (or symlink from microservices)
# Models will be referenced via environment variable or absolute path
```

**Model Organization**:
```
triton_model_repository/
├── shared_models/              # Shared model files
│   ├── vae/
│   │   └── qwen_image_vae.safetensors
│   ├── clip/
│   │   └── qwen_2.5_vl_7b_fp8_scaled.safetensors
│   ├── diffusion_models/
│   │   └── qwen_image_edit_2509_fp8_e4m3fn.safetensors
│   └── loras/
│       └── Qwen-Image-Lightning-4steps-V2.0.safetensors
├── latent_encoder/
│   └── 1/
│       └── models -> ../../shared_models  # Symlink or env var
└── ...
```

#### 2.3 Copy Service Code to Model Directories
**Strategy**: Copy necessary files from microservices to each model's version directory.

```bash
# For each service:
cp microservices/latent_encoder/{service.py,config.py,utils.py,errors.py} \
   triton_model_repository/latent_encoder/1/
```

#### 2.4 Setup ComfyUI in Model Directories
**Options**:

**Option A: Shared ComfyUI** (Recommended - saves space)
```bash
# Copy ComfyUI once to shared location
cp -r microservices/latent_encoder/comfyui triton_model_repository/shared_comfyui/

# In each model's model.py, add to sys.path:
import sys
sys.path.insert(0, '/path/to/triton_model_repository/shared_comfyui')
```

**Option B: Per-Model ComfyUI** (Better isolation)
```bash
# Copy ComfyUI to each model directory
cp -r microservices/latent_encoder/comfyui triton_model_repository/latent_encoder/1/
```

**Recommendation**: Use shared ComfyUI with environment variable pointing to it.

#### 2.5 Create Model Configuration Files
Based on extracted information from Phase 1, create `config.pbtxt` for each model.

---

### Phase 3: Python Backend Implementation

**Goal**: Create `model.py` for each service that implements Triton Python backend interface.

#### 3.1 Template Structure
Each `model.py` will:
1. **Initialize**: Load models, setup ComfyUI, prepare environment
2. **Execute**: Process inference requests, convert tensors, call service logic
3. **Finalize**: Cleanup resources

#### 3.2 Key Implementation Details

**Model Initialization**:
```python
def initialize(self, args):
    # Get model directory
    model_dir = pb_utils.get_model_dir()
    
    # Setup paths
    sys.path.insert(0, os.path.join(model_dir, 'comfyui'))
    sys.path.insert(0, model_dir)
    
    # Load configuration
    from config import Config
    Config.model_dir = os.path.join(model_dir, 'models')
    
    # Initialize service (load models, setup ComfyUI)
    # This happens once per model instance
```

**Model Execution**:
```python
def execute(self, requests):
    responses = []
    for request in requests:
        # Extract input tensors
        image_tensor = pb_utils.get_input_tensor_by_name(request, "input_image")
        image_array = image_tensor.as_numpy()
        
        # Call service function
        result = encode_image_to_latent(image_array, ...)
        
        # Convert to output tensor
        output_tensor = pb_utils.Tensor("latent", result['latent_tensor'])
        response = pb_utils.InferenceResponse([output_tensor])
        responses.append(response)
    
    return responses
```

#### 3.3 Handle Tensor Conversions
- Convert numpy arrays to/from Triton tensors
- Handle batch dimensions
- Manage data type conversions (FP32, INT64, STRING)

---

### Phase 4: Environment & Dependency Management

**Critical Understanding**: Triton Python backend uses the Python environment from the Triton container, NOT the microservice venv.

#### 4.1 Dependency Strategy

**Option A: Install in Triton Container** (Recommended for VastAI)
- Build custom Triton Docker image with all dependencies
- Install ComfyUI requirements + microservice requirements
- Models use system Python environment

**Option B: Bundle Dependencies** (More complex)
- Package dependencies with each model
- Use virtual environments per model (complex)

**Recommendation**: Build custom Triton image with all dependencies.

#### 4.2 Custom Triton Dockerfile
```dockerfile
FROM nvcr.io/nvidia/tritonserver:25.10-py3

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt /tmp/
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Copy ComfyUI modules (or mount as volume)
COPY comfyui /opt/comfyui

# Set environment variables
ENV PYTHONPATH=/opt/comfyui:$PYTHONPATH
ENV COMFYUI_PATH=/opt/comfyui
ENV MODEL_DIR=/models/shared_models

# Copy model repository
COPY triton_model_repository /models

# Expose ports
EXPOSE 8000 8001 8002
```

#### 4.3 Model Download Integration

**Current setup.sh downloads models to**: `microservices/<service>/models/`

**For Triton, we need**:
1. **Development/Testing**: Keep current structure, symlink or copy to Triton repo
2. **Production/VastAI**: Download models directly to Triton model repository

**Updated setup.sh Strategy**:
```bash
# Add Triton model repository setup option
if [ "$SETUP_FOR_TRITON" = "true" ]; then
    TRITON_REPO="${TRITON_MODEL_REPOSITORY:-../triton_model_repository}"
    MODELS_DIR="${TRITON_REPO}/shared_models"
else
    MODELS_DIR="${MICROSERVICE_DIR}/models"
fi
```

**Or create separate script**: `setup_triton_models.sh`

---

### Phase 5: Ensemble Configuration

**Goal**: Create ensemble model that chains all services together.

#### 5.1 Ensemble Config Structure
```protobuf
name: "vtryon_pipeline"
platform: "ensemble"
max_batch_size: 1

input [
  {
    name: "image1"
    data_type: TYPE_FP32
    dims: [ 1, 3, 1024, 1024 ]
  },
  {
    name: "image2"
    data_type: TYPE_FP32
    dims: [ 1, 3, 1024, 1024 ]
  },
  {
    name: "prompt"
    data_type: TYPE_STRING
    dims: [ 1 ]
  }
]

output [
  {
    name: "output_image"
    data_type: TYPE_FP32
    dims: [ 1, 3, 1024, 1024 ]
  }
]

ensemble_scheduling {
  step [
    {
      model_name: "latent_encoder"
      model_version: -1
      input_map { key: "input_image", value: "image1" }
      output_map { key: "latent", value: "latent_enc" }
    },
    {
      model_name: "text_encoder"
      model_version: -1
      input_map { key: "image1", value: "image1" }
      input_map { key: "image2", value: "image2" }
      input_map { key: "prompt", value: "prompt" }
      output_map { key: "positive_encoding", value: "pos_enc" }
      output_map { key: "negative_encoding", value: "neg_enc" }
    },
    {
      model_name: "sampling"
      model_version: -1
      input_map { key: "positive_encoding", value: "pos_enc" }
      input_map { key: "negative_encoding", value: "neg_enc" }
      input_map { key: "latent", value: "latent_enc" }
      output_map { key: "sampled_latent", value: "sampled_lat" }
    },
    {
      model_name: "decoding"
      model_version: -1
      input_map { key: "latent", value: "sampled_lat" }
      output_map { key: "image", value: "output_image" }
    }
  ]
}
```

---

### Phase 6: Local Testing

#### 6.1 Test Individual Models
```bash
# Start Triton
docker run --gpus=1 --rm -p 8000:8000 -p 8001:8001 -p 8002:8002 \
  -v $(pwd)/triton_model_repository:/models \
  nvcr.io/nvidia/tritonserver:25.10-py3 \
  tritonserver --model-repository=/models

# Test each model
curl -X POST http://localhost:8000/v2/models/latent_encoder/infer \
  -H "Content-Type: application/json" \
  -d @test_request.json
```

#### 6.2 Test Ensemble
```bash
curl -X POST http://localhost:8000/v2/models/vtryon_pipeline/infer \
  -H "Content-Type: application/json" \
  -d @test_pipeline_request.json
```

---

### Phase 7: VastAI Deployment

#### 7.1 Build Custom Triton Image
```bash
docker build -t vtryon-triton:latest -f Dockerfile.triton .
```

#### 7.2 Push to Registry
```bash
docker tag vtryon-triton:latest your-registry/vtryon-triton:latest
docker push your-registry/vtryon-triton:latest
```

#### 7.3 Deploy on VastAI
- Create instance with GPU
- Pull image
- Mount model repository (or download models on instance)
- Run Triton server

---

## How setup.sh Ties into Triton

### Current setup.sh Flow:
1. Creates venv → **Not used by Triton** (Triton uses container Python)
2. Installs PyTorch → **Needed in Triton container**
3. Clones ComfyUI → **Needed in Triton model repo or shared location**
4. Installs requirements → **Needed in Triton container**
5. Downloads models → **Needed in Triton model repo structure**

### For Triton Integration:

**setup.sh becomes**:
1. **Development setup**: Keep current functionality for standalone testing
2. **Triton preparation**: New mode that prepares Triton model repository

**New script: `setup_triton_repository.sh`**:
- Copies service code to model directories
- Sets up ComfyUI (shared or per-model)
- Downloads/copies models to shared_models directory
- Creates symlinks or configs for model paths
- Generates config.pbtxt files (or templates)

**Dockerfile.triton**:
- Uses setup.sh to install dependencies in container
- Copies prepared model repository
- Sets up environment variables

---

## Model Download Concerns - Addressed

### Concern 1: Duplicate Downloads
**Solution**: Use shared_models directory, download once, reference from all models.

### Concern 2: Model Paths in Code
**Solution**: 
- Use environment variables: `MODEL_DIR=/models/shared_models`
- Or use `pb_utils.get_model_dir()` and relative paths
- Update config.py to support both standalone and Triton modes

### Concern 3: Model Size
**Solution**: 
- Download models during Docker build (cached in image)
- Or download on first run (with caching)
- Or mount models as volume on VastAI

### Concern 4: Model Updates
**Solution**:
- Models in shared_models can be updated independently
- Use model versioning in Triton
- Hot-reload models without restarting server

---

## Updated Timeline

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Phase 1: Extract Info via Testing | 1-2 days | ✅ Ready now |
| Phase 2: Setup Repository | 1 day | Phase 1 complete |
| Phase 3: Python Backend | 2-3 days | Phase 2 complete |
| Phase 4: Environment Setup | 1-2 days | Phase 3 complete |
| Phase 5: Ensemble Config | 1 day | Phase 3 complete |
| Phase 6: Local Testing | 1-2 days | All phases |
| Phase 7: VastAI Deployment | 1 day | Phase 6 complete |
| **Total** | **8-12 days** | |

---

## Next Immediate Steps

1. **Test each service** to extract tensor shapes and dependencies
2. **Document extracted information** in `TRITON_CONFIG_EXTRACTED.md`
3. **Create Triton model repository structure**
4. **Create `setup_triton_repository.sh`** script
5. **Implement Python backend models** based on extracted info

---

## Key Files to Create

1. `triton_model_repository/` - Model repository structure
2. `setup_triton_repository.sh` - Setup script for Triton
3. `Dockerfile.triton` - Custom Triton container
4. `TRITON_CONFIG_EXTRACTED.md` - Extracted configuration info
5. `triton_model_repository/*/1/model.py` - Python backend implementations
6. `triton_model_repository/*/config.pbtxt` - Model configurations







