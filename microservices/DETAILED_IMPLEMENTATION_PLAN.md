# Detailed Step-by-Step Implementation Plan - Triton Ensemble Deployment

## Overview
This plan ensures we capture ALL information needed for Triton configuration during individual service testing, preventing any need to backtrack.

---

## Phase 1: Early Structure Setup & Import Validation

**Goal**: Set up Triton repository structure and validate code imports early to catch structural issues before comprehensive testing.

### Step 1.1: Create Repository Directory Structure

**Goal**: Set up proper Triton model repository structure

```bash
mkdir -p triton_model_repository/{latent_encoder,text_encoder,sampling,decoding,vtryon_pipeline}/{1}
mkdir -p triton_model_repository/shared_models/{vae,clip,diffusion_models,loras}
mkdir -p triton_model_repository/shared_comfyui
```

**Deliverable**: Directory structure created

**Checkpoint**: ✅ Repository structure ready

---

### Step 1.2: Setup Shared ComfyUI (Initial)

**Goal**: Create shared ComfyUI location and test imports

**Tasks**:
- [ ] Copy ComfyUI from one microservice to `triton_model_repository/shared_comfyui/`
- [ ] Verify all required modules are present
- [ ] Test import: `python -c "import sys; sys.path.insert(0, 'shared_comfyui'); import comfy"`
- [ ] Document any missing modules or import errors
- [ ] Fix import issues if found

**Deliverable**: Shared ComfyUI ready with imports validated

**Checkpoint**: ✅ ComfyUI imports working

---

### Step 1.3: Copy Service Code to Model Directories

**Goal**: Copy necessary service files to each model's version directory and test imports

**For each service**:
```bash
# Example for latent_encoder
cp microservices/latent_encoder/{service.py,config.py,utils.py,errors.py} \
   triton_model_repository/latent_encoder/1/
```

**Tasks**:
- [ ] Copy latent_encoder code
- [ ] Copy text_encoder code
- [ ] Copy sampling code
- [ ] Copy decoding code

**Deliverable**: Service code in model directories

**Checkpoint**: ✅ Code copied

---

### Step 1.4: Validate Imports in Triton Context

**Goal**: Test that all imports work in the Triton model directory structure

**For each service**:
```bash
cd triton_model_repository/latent_encoder/1
python -c "
import sys
sys.path.insert(0, '../../shared_comfyui')
sys.path.insert(0, '.')
try:
    from service import *
    from config import *
    from utils import *
    print('✓ All imports successful')
except ImportError as e:
    print(f'✗ Import error: {e}')
    exit(1)
"
```

**Tasks**:
- [ ] Test latent_encoder imports
- [ ] Test text_encoder imports
- [ ] Test sampling imports
- [ ] Test decoding imports
- [ ] Fix any import errors found
- [ ] Document any path adjustments needed

**Common Issues to Check**:
- [ ] ComfyUI path resolution
- [ ] Relative vs absolute imports
- [ ] Missing dependencies
- [ ] Circular import issues
- [ ] Path conflicts

**Deliverable**: All imports validated, errors fixed

**Checkpoint**: ✅ All imports working - NO IMPORT ERRORS

---

### Step 1.5: Create Minimal Python Backend Template

**Goal**: Create basic model.py template to test Triton Python backend structure

**Create**: `triton_model_repository/latent_encoder/1/model.py` (minimal version)

```python
import triton_python_backend_utils as pb_utils
import sys
import os

# Add paths
model_dir = pb_utils.get_model_dir()
sys.path.insert(0, os.path.join(model_dir, '../../shared_comfyui'))
sys.path.insert(0, model_dir)

# Test imports
try:
    from service import encode_image_to_latent
    from config import Config
    print("✓ Service imports successful")
except ImportError as e:
    print(f"✗ Import error: {e}")
    raise

class TritonPythonModel:
    def initialize(self, args):
        """Test initialization - just verify imports work"""
        print("Initializing model...")
        # Don't load models yet, just verify structure
        print("✓ Model structure validated")
    
    def execute(self, requests):
        """Placeholder - will implement after testing"""
        pass
    
    def finalize(self):
        """Cleanup"""
        pass
```

**Tasks**:
- [ ] Create minimal model.py for each service
- [ ] Test that Triton can load the model structure
- [ ] Verify no import errors at Triton startup
- [ ] Document any structural issues

**Deliverable**: Minimal model.py files that load without errors

**Checkpoint**: ✅ Basic structure validated with Triton

---

## Phase 2: Comprehensive Service Testing & Information Extraction

**Goal**: Now that structure is validated, extract ALL information needed for Triton config

### Step 2.1: Prepare Testing Environment
**Goal**: Set up consistent testing environment for all services

**Tasks**:
- [ ] Create test data directory: `test_data/`
  - [ ] Sample images: `test_data/images/person.jpg`, `test_data/images/cloth.jpg`
  - [ ] Expected outputs directory: `test_data/expected_outputs/`
- [ ] Create test results directory: `test_results/`
  - [ ] Per-service subdirectories: `test_results/latent_encoder/`, etc.
- [ ] Create test script template: `test_service.sh`
- [ ] Document GPU specifications: GPU model, VRAM, CUDA version

**Deliverable**: `test_data/` directory with sample inputs

**Checkpoint**: ✅ Test data ready before proceeding

---

### Step 1.2: Test Latent Encoder - Comprehensive Profiling

**Goal**: Extract ALL information needed for Triton config

#### 1.2.1: Basic Functionality Test
```bash
cd microservices/latent_encoder
source venv/bin/activate
python main.py --mode standalone \
  --image_path ../../test_data/images/person.jpg \
  --output_dir ../../test_results/latent_encoder \
  --no-save
```

**Extract & Document**:
- [ ] **Input Tensor Shape**: `[batch, channels, height, width]`
  - Example: `[1, 3, 1024, 1024]`
- [ ] **Input Data Type**: FP32, INT8, etc.
- [ ] **Output Tensor Shape**: `[batch, channels, height, width]`
  - Example: `[1, 4, 64, 64]`
- [ ] **Output Data Type**: FP32, etc.
- [ ] **Model Files Required**:
  - [ ] VAE encoder path: `models/vae/qwen_image_vae.safetensors`
  - [ ] File size: `___ MB`
- [ ] **ComfyUI Dependencies**:
  - [ ] Modules used: `comfy/`, `comfy_extras/`, etc.
  - [ ] Custom nodes required: List all

**Deliverable**: `test_results/latent_encoder/basic_test_results.json`

#### 1.2.2: Batch Processing Test
**Goal**: Determine if service supports batching and optimal batch sizes

```bash
# Test with batch size 1
python main.py --mode standalone --image_path test.jpg --no-save

# Test with batch size 2 (if supported)
# Modify service to accept multiple images
# Test with batch size 4, 8, 16
```

**Extract & Document**:
- [ ] **Batch Support**: Yes/No
- [ ] **Maximum Batch Size**: `___` (test until OOM or error)
- [ ] **Optimal Batch Size**: `___` (best throughput/latency tradeoff)
- [ ] **Batch Processing Time**: 
  - Batch 1: `___ ms`
  - Batch 2: `___ ms`
  - Batch 4: `___ ms`
  - Batch 8: `___ ms`
- [ ] **Throughput**: Requests/second for each batch size

**Deliverable**: `test_results/latent_encoder/batch_test_results.json`

#### 1.2.3: Resource Profiling
**Goal**: Understand GPU memory, CPU usage, model loading requirements

```bash
# Use nvidia-smi or Python profiling
# Monitor during inference
```

**Extract & Document**:
- [ ] **GPU Memory Usage**:
  - [ ] Model loading: `___ MB`
  - [ ] Inference (batch 1): `___ MB`
  - [ ] Inference (batch 4): `___ MB`
  - [ ] Inference (batch 8): `___ MB`
  - [ ] Peak memory: `___ MB`
- [ ] **CPU Usage**: `___ %` (average during inference)
- [ ] **Model Loading Time**: `___ seconds`
- [ ] **Model Size on Disk**: `___ MB`
- [ ] **VRAM Available**: `___ MB` (total GPU memory)

**Deliverable**: `test_results/latent_encoder/resource_profile.json`

#### 1.2.4: Concurrency Test
**Goal**: Test multiple simultaneous requests to understand concurrency limits

```bash
# Run multiple requests in parallel
# Use Python threading or multiprocessing
```

**Extract & Document**:
- [ ] **Concurrent Requests Supported**: `___` (test until errors)
- [ ] **Optimal Concurrency**: `___` (best throughput)
- [ ] **Latency at Concurrency 1**: `___ ms`
- [ ] **Latency at Concurrency 2**: `___ ms`
- [ ] **Latency at Concurrency 4**: `___ ms`
- [ ] **Throughput at Optimal Concurrency**: `___ req/sec`
- [ ] **GPU Utilization**: `___ %` at optimal concurrency

**Deliverable**: `test_results/latent_encoder/concurrency_test_results.json`

#### 1.2.5: Model Duplication Analysis
**Goal**: Determine if model can be shared or needs per-instance copies

**Questions to Answer**:
- [ ] **Is model stateful?**: Yes/No (does it maintain state between requests?)
- [ ] **Can model be shared?**: Yes/No (thread-safe?)
- [ ] **Memory per instance**: `___ MB` (if duplicated)
- [ ] **Recommended instance count**: `___` (based on VRAM and concurrency)

**Deliverable**: `test_results/latent_encoder/model_sharing_analysis.json`

#### 1.2.6: Latency Profiling
**Goal**: Understand latency characteristics for Triton dynamic batching config

**Extract & Document**:
- [ ] **P50 Latency**: `___ ms`
- [ ] **P95 Latency**: `___ ms`
- [ ] **P99 Latency**: `___ ms`
- [ ] **Min Latency**: `___ ms`
- [ ] **Max Latency**: `___ ms`
- [ ] **Average Latency**: `___ ms`
- [ ] **Latency Distribution**: Histogram data

**Deliverable**: `test_results/latent_encoder/latency_profile.json`

#### 1.2.7: Create Latent Encoder Test Summary
**Deliverable**: `test_results/latent_encoder/TRITON_CONFIG_DATA.json`

```json
{
  "service": "latent_encoder",
  "tensor_info": {
    "input": {
      "name": "input_image",
      "shape": [1, 3, 1024, 1024],
      "data_type": "TYPE_FP32",
      "batch_support": true
    },
    "output": {
      "name": "latent",
      "shape": [1, 4, 64, 64],
      "data_type": "TYPE_FP32"
    }
  },
  "batch_config": {
    "max_batch_size": 8,
    "optimal_batch_size": 4,
    "supports_batching": true
  },
  "resource_requirements": {
    "gpu_memory_mb": 2048,
    "model_size_mb": 512,
    "peak_memory_mb": 2560
  },
  "performance": {
    "optimal_concurrency": 2,
    "throughput_req_per_sec": 10,
    "p95_latency_ms": 500
  },
  "model_files": {
    "vae_encoder": "models/vae/qwen_image_vae.safetensors"
  },
  "triton_config": {
    "recommended_instance_count": 2,
    "recommended_max_batch_size": 8,
    "dynamic_batching": true,
    "model_sharing": "shared"
  }
}
```

**Checkpoint**: ✅ All latent encoder data extracted and documented

---

### Step 1.3: Test Text Encoder - Comprehensive Profiling

**Repeat Steps 1.2.1 through 1.2.7 for text_encoder**

**Additional Considerations**:
- [ ] **Multiple Inputs**: image1, image2, prompt (STRING)
- [ ] **Multiple Outputs**: positive_encoding, negative_encoding
- [ ] **Model Files**: CLIP + VAE (shared with latent_encoder?)
- [ ] **Model Sharing**: Can VAE be shared with latent_encoder?

**Deliverable**: `test_results/text_encoder/TRITON_CONFIG_DATA.json`

**Checkpoint**: ✅ All text encoder data extracted

---

### Step 1.4: Test Sampling - Comprehensive Profiling

**Repeat Steps 1.2.1 through 1.2.7 for sampling**

**Additional Considerations**:
- [ ] **Input Dependencies**: Requires outputs from text_encoder and latent_encoder
- [ ] **Model Files**: UNET + LoRA
- [ ] **Longest Processing Time**: Likely bottleneck service
- [ ] **Resource Intensive**: May need more GPU memory

**Deliverable**: `test_results/sampling/TRITON_CONFIG_DATA.json`

**Checkpoint**: ✅ All sampling data extracted

---

### Step 1.5: Test Decoding - Comprehensive Profiling

**Repeat Steps 1.2.1 through 1.2.7 for decoding**

**Additional Considerations**:
- [ ] **Model Files**: VAE decoder (shared with encoder?)
- [ ] **Output Format**: Image tensor vs. file
- [ ] **Post-processing**: Image format conversion

**Deliverable**: `test_results/decoding/TRITON_CONFIG_DATA.json`

**Checkpoint**: ✅ All decoding data extracted

---

### Step 1.6: End-to-End Pipeline Test

**Goal**: Test complete pipeline to understand ensemble characteristics

```bash
# Run all services in sequence
# Measure total latency, identify bottlenecks
```

**Extract & Document**:
- [ ] **Total Pipeline Latency**: `___ ms`
- [ ] **Per-Service Latency Breakdown**:
  - [ ] Latent encoder: `___ ms`
  - [ ] Text encoder: `___ ms`
  - [ ] Sampling: `___ ms`
  - [ ] Decoding: `___ ms`
- [ ] **Bottleneck Service**: `___` (longest processing time)
- [ ] **Pipeline Throughput**: `___ req/sec`
- [ ] **Total GPU Memory**: `___ MB` (all services loaded)
- [ ] **Memory Overlap**: Can models share memory? (VAE encoder/decoder)

**Deliverable**: `test_results/pipeline/TRITON_CONFIG_DATA.json`

**Checkpoint**: ✅ Pipeline characteristics understood

---

### Step 1.7: Model Sharing Analysis

**Goal**: Determine optimal model sharing strategy

**Analysis**:
- [ ] **VAE Model**: Used by latent_encoder, text_encoder, decoding
  - [ ] **Sharing Strategy**: Shared instance or per-service?
  - [ ] **Memory Savings if Shared**: `___ MB`
  - [ ] **Complexity Impact**: Low/Medium/High
- [ ] **CLIP Model**: Used by text_encoder only
  - [ ] **Sharing Strategy**: N/A (single service)
- [ ] **UNET Model**: Used by sampling only
  - [ ] **Sharing Strategy**: N/A (single service)
- [ ] **LoRA Model**: Used by sampling only
  - [ ] **Sharing Strategy**: N/A (single service)

**Decision Matrix**:
| Model | Services Using | Share? | Reason |
|-------|---------------|--------|--------|
| VAE | latent_encoder, text_encoder, decoding | ? | ? |
| CLIP | text_encoder | No | Single service |
| UNET | sampling | No | Single service |
| LoRA | sampling | No | Single service |

**Deliverable**: `test_results/MODEL_SHARING_STRATEGY.md`

**Checkpoint**: ✅ Model sharing strategy decided

---

### Step 1.8: Create Master Configuration Document

**Goal**: Compile all extracted information into single source of truth

**Create**: `test_results/TRITON_MASTER_CONFIG.json`

This document contains:
- All tensor shapes and data types
- All batch size capabilities
- All resource requirements
- All performance characteristics
- All model file paths
- All sharing strategies
- Recommended Triton configurations

**Checkpoint**: ✅ Master config document complete - NO BACKTRACKING NEEDED

---

## Phase 3: Complete Repository Setup with Models

### Step 3.1: Setup Shared Models Directory

**Goal**: Download/copy models to shared location

**Tasks**:
- [ ] Copy VAE model to `triton_model_repository/shared_models/vae/`
- [ ] Copy CLIP model to `triton_model_repository/shared_models/clip/`
- [ ] Copy UNET model to `triton_model_repository/shared_models/diffusion_models/`
- [ ] Copy LoRA model to `triton_model_repository/shared_models/loras/`
- [ ] Verify all model files exist and are accessible
- [ ] Document model paths in `triton_model_repository/MODEL_PATHS.md`

**Deliverable**: All models in shared_models directory

**Checkpoint**: ✅ Models ready

---

## Phase 4: Triton Configuration Files Creation

### Step 4.1: Create Individual Model Config Files

**Goal**: Create config.pbtxt for each model using extracted data

**Use Data From**: `test_results/*/TRITON_CONFIG_DATA.json`

#### 4.1.1: Latent Encoder Config
**Source**: `test_results/latent_encoder/TRITON_CONFIG_DATA.json`

**Create**: `triton_model_repository/latent_encoder/config.pbtxt`

**Include**:
- [ ] Platform: `backend: "python"`
- [ ] Max batch size: From extracted data
- [ ] Input tensor: Shape and data type from extracted data
- [ ] Output tensor: Shape and data type from extracted data
- [ ] Instance group: Count from extracted data
- [ ] Dynamic batching: Configuration from extracted data
- [ ] Model directory: Path to shared models

**Deliverable**: `latent_encoder/config.pbtxt`

#### 4.1.2: Text Encoder Config
**Repeat for text_encoder**

**Deliverable**: `text_encoder/config.pbtxt`

#### 4.1.3: Sampling Config
**Repeat for sampling**

**Deliverable**: `sampling/config.pbtxt`

#### 4.1.4: Decoding Config
**Repeat for decoding**

**Deliverable**: `decoding/config.pbtxt`

**Checkpoint**: ✅ All individual model configs created

---

### Step 4.2: Create Ensemble Config

**Goal**: Create ensemble model configuration

**Use Data From**: `test_results/pipeline/TRITON_CONFIG_DATA.json`

**Create**: `triton_model_repository/vtryon_pipeline/config.pbtxt`

**Include**:
- [ ] Platform: `platform: "ensemble"`
- [ ] Inputs: image1, image2, prompt (from extracted data)
- [ ] Outputs: output_image (from extracted data)
- [ ] Ensemble steps: All 4 services in sequence
- [ ] Input/output mappings: Based on extracted tensor names
- [ ] Max inflight requests: Based on concurrency analysis

**Deliverable**: `vtryon_pipeline/config.pbtxt`

**Checkpoint**: ✅ Ensemble config created

---

## Phase 5: Python Backend Implementation

### Step 5.1: Create Model Template

**Goal**: Create base template for Python backend models

**Create**: `triton_model_repository/_templates/model_template.py`

**Include**:
- [ ] TritonPythonModel class structure
- [ ] Initialize method template
- [ ] Execute method template
- [ ] Finalize method template
- [ ] Error handling patterns
- [ ] Logging setup

**Deliverable**: Model template

**Checkpoint**: ✅ Template ready

---

### Step 5.2: Implement Latent Encoder Model

**Goal**: Create `triton_model_repository/latent_encoder/1/model.py`

**Tasks**:
- [ ] Copy template
- [ ] Implement initialize():
  - [ ] Setup ComfyUI path (shared)
  - [ ] Setup model paths (shared_models)
  - [ ] Load models (VAE encoder)
  - [ ] Initialize service
- [ ] Implement execute():
  - [ ] Extract input tensor
  - [ ] Convert to numpy
  - [ ] Call service function
  - [ ] Convert output to tensor
  - [ ] Return response
- [ ] Implement finalize():
  - [ ] Cleanup resources
- [ ] Test with Triton server

**Use Data From**: `test_results/latent_encoder/TRITON_CONFIG_DATA.json`

**Deliverable**: Working `latent_encoder/1/model.py`

**Checkpoint**: ✅ Latent encoder model working

---

### Step 5.3: Implement Text Encoder Model

**Repeat Step 4.2 for text_encoder**

**Additional Considerations**:
- [ ] Multiple inputs (image1, image2, prompt)
- [ ] Multiple outputs (positive_encoding, negative_encoding)
- [ ] String input handling (prompt)

**Deliverable**: Working `text_encoder/1/model.py`

**Checkpoint**: ✅ Text encoder model working

---

### Step 5.4: Implement Sampling Model

**Repeat Step 4.2 for sampling**

**Additional Considerations**:
- [ ] Multiple inputs from previous services
- [ ] Longest processing time (may need optimization)

**Deliverable**: Working `sampling/1/model.py`

**Checkpoint**: ✅ Sampling model working

---

### Step 5.5: Implement Decoding Model

**Repeat Step 4.2 for decoding**

**Additional Considerations**:
- [ ] Image output format
- [ ] Post-processing if needed

**Deliverable**: Working `decoding/1/model.py`

**Checkpoint**: ✅ Decoding model working

---

## Phase 6: Local Triton Testing

### Step 6.1: Setup Local Triton Server

**Goal**: Run Triton server locally for testing

**Tasks**:
- [ ] Pull Triton container: `docker pull nvcr.io/nvidia/tritonserver:25.10-py3`
- [ ] Start Triton: `docker run --gpus=1 ... tritonserver --model-repository=/models`
- [ ] Verify server starts: Check logs
- [ ] Verify models load: Check model status API

**Deliverable**: Running Triton server

**Checkpoint**: ✅ Triton server running

---

### Step 6.2: Test Individual Models

**Goal**: Verify each model works independently

**For each model**:
- [ ] Check model status: `curl http://localhost:8000/v2/models/{model_name}`
- [ ] Send test inference request
- [ ] Verify output shape and data type
- [ ] Measure latency
- [ ] Compare with standalone test results

**Deliverable**: All individual models tested and verified

**Checkpoint**: ✅ Individual models working

---

### Step 6.3: Test Ensemble Model

**Goal**: Verify complete pipeline works

**Tasks**:
- [ ] Send request to ensemble model
- [ ] Verify output
- [ ] Measure total latency
- [ ] Compare with pipeline test results
- [ ] Verify tensor flow between models

**Deliverable**: Ensemble model working

**Checkpoint**: ✅ Ensemble model working

---

### Step 6.4: Performance Testing

**Goal**: Verify performance matches expectations

**Tasks**:
- [ ] Test with perf_analyzer
- [ ] Measure throughput
- [ ] Measure latency (P50, P95, P99)
- [ ] Compare with extracted performance data
- [ ] Tune configuration if needed

**Deliverable**: Performance test results

**Checkpoint**: ✅ Performance verified

---

## Phase 7: Docker Container Preparation

### Step 7.1: Create Dockerfile

**Goal**: Create custom Triton Docker image

**Create**: `Dockerfile.triton`

**Include**:
- [ ] Base image: `nvcr.io/nvidia/tritonserver:25.10-py3`
- [ ] System dependencies
- [ ] Python dependencies (from requirements.txt)
- [ ] ComfyUI setup
- [ ] Model repository copy
- [ ] Environment variables
- [ ] Expose ports

**Deliverable**: `Dockerfile.triton`

**Checkpoint**: ✅ Dockerfile created

---

### Step 7.2: Build Docker Image

**Goal**: Build and test Docker image

**Tasks**:
- [ ] Build image: `docker build -t vtryon-triton:latest -f Dockerfile.triton .`
- [ ] Test image: Run container locally
- [ ] Verify models load
- [ ] Test inference
- [ ] Optimize image size if needed

**Deliverable**: Working Docker image

**Checkpoint**: ✅ Docker image ready

---

### Step 7.3: Create Docker Compose (Optional)

**Goal**: Easy local testing with docker-compose

**Create**: `docker-compose.triton.yml`

**Include**:
- [ ] Triton service
- [ ] Volume mounts
- [ ] GPU access
- [ ] Port mappings
- [ ] Environment variables

**Deliverable**: `docker-compose.triton.yml`

**Checkpoint**: ✅ Docker compose ready

---

## Phase 8: VastAI Deployment Preparation

### Step 8.1: Prepare Git Repository

**Goal**: Clean repository for VastAI push

**Tasks**:
- [ ] Create `.gitignore` for large files
- [ ] Document deployment process
- [ ] Create deployment README
- [ ] Tag repository version
- [ ] Push to Git

**Deliverable**: Clean Git repository

**Checkpoint**: ✅ Repository ready

---

### Step 8.2: Create Deployment Scripts

**Goal**: Scripts for VastAI deployment

**Create**:
- [ ] `deploy_to_vastai.sh`: Setup script for VastAI instance
- [ ] `test_on_vastai.sh`: Test script
- [ ] `vastai_config.yaml`: VastAI configuration

**Deliverable**: Deployment scripts

**Checkpoint**: ✅ Deployment scripts ready

---

### Step 8.3: Document Deployment Process

**Goal**: Complete deployment documentation

**Create**: `DEPLOYMENT.md`

**Include**:
- [ ] VastAI instance setup
- [ ] Git clone instructions
- [ ] Docker build instructions
- [ ] Model download (if not in image)
- [ ] Triton server startup
- [ ] Testing instructions
- [ ] Troubleshooting

**Deliverable**: `DEPLOYMENT.md`

**Checkpoint**: ✅ Documentation complete

---

## Phase 9: VastAI Deployment & Testing

### Step 9.1: Deploy to VastAI

**Goal**: Deploy containerized Triton server

**Tasks**:
- [ ] Create VastAI instance
- [ ] Clone repository
- [ ] Build Docker image (or pull from registry)
- [ ] Run Triton server
- [ ] Verify server is running

**Deliverable**: Running Triton server on VastAI

**Checkpoint**: ✅ Server deployed

---

### Step 9.2: Test on VastAI

**Goal**: Verify everything works on VastAI

**Tasks**:
- [ ] Test individual models
- [ ] Test ensemble model
- [ ] Performance testing
- [ ] Load testing
- [ ] Monitor resources

**Deliverable**: Verified working deployment

**Checkpoint**: ✅ Deployment verified

---

## Critical Information Checklist

### Must Extract During Testing (Phase 1):

**Tensor Information**:
- [x] Input shapes and data types
- [x] Output shapes and data types
- [x] Batch dimension support

**Performance Information**:
- [x] Maximum batch size
- [x] Optimal batch size
- [x] Optimal concurrency
- [x] Throughput (req/sec)
- [x] Latency (P50, P95, P99)

**Resource Information**:
- [x] GPU memory per instance
- [x] Model size on disk
- [x] Peak memory usage
- [x] CPU usage
- [x] Model loading time

**Model Information**:
- [x] Model file paths
- [x] Model sharing capabilities
- [x] Stateful vs stateless
- [x] Thread safety

**Configuration Information**:
- [x] Recommended instance count
- [x] Dynamic batching settings
- [x] Max inflight requests
- [x] Model directory structure

---

## Success Criteria

### Phase 1 Complete When:
- ✅ Repository structure created
- ✅ ComfyUI copied and imports validated
- ✅ Service code copied to model directories
- ✅ All imports working in Triton context
- ✅ Minimal model.py structure validated
- ✅ NO IMPORT ERRORS

### Phase 2 Complete When:
- ✅ All services tested individually
- ✅ All tensor information extracted
- ✅ All performance data collected
- ✅ All resource requirements documented
- ✅ Model sharing strategy decided
- ✅ Master config document created

### Phase 3 Complete When:
- ✅ Models downloaded/copied to shared location
- ✅ All model files accessible

### Phase 4-5 Complete When:
- ✅ Triton repository structure created
- ✅ All models in shared location
- ✅ All config.pbtxt files created
- ✅ All configs use extracted data (no guessing)

### Phase 6 Complete When:
- ✅ All Python backend models implemented
- ✅ All models tested individually
- ✅ All models work with Triton

### Phase 7-8 Complete When:
- ✅ Ensemble model works
- ✅ Performance matches expectations
- ✅ No configuration changes needed

### Phase 9 Complete When:
- ✅ Docker image built and tested
- ✅ Deployment scripts ready
- ✅ Documentation complete

### Phase 8 Complete When:
- ✅ Deployed on VastAI
- ✅ All tests passing
- ✅ Performance verified

---

## Notes

- **NO GUESSING**: All Triton configs must use extracted data
- **NO BACKTRACKING**: Comprehensive testing in Phase 1 prevents this
- **DOCUMENT EVERYTHING**: Every decision and measurement documented
- **TEST EARLY**: Test each component as soon as it's ready
- **ITERATE IF NEEDED**: But only with new information, not missing information

