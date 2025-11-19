# VastAI Deployment Plan - Phases 3-8

## Overview
Since local resources are limited, **all of Phases 3-8 will be executed entirely on VastAI instances**. This document outlines the complete workflow.

---

## ✅ Phase 2 Complete (Done Locally)
- All services tested individually
- All tensor information extracted
- All performance data collected
- Test results saved: `/home/fashionx/Desktop/test_results/`
- Triton config files generated: `microservices/triton_model_repository/*/config.pbtxt`

---

## 🎯 Phase 3-8: Complete on VastAI

### Prerequisites
1. VastAI instance with:
   - GPU: RTX 3090/4090 or A100 (24GB+ VRAM recommended)
   - Storage: 100GB+ free space
   - Docker installed
   - Git installed

2. Repository pushed to GitHub (already done)

---

## Phase 3: Complete Repository Setup with Models (VastAI)

### Step 3.1: Clone Repository on VastAI

```bash
# SSH into VastAI instance
ssh root@<vastai-instance-ip>

# Clone repository
cd /workspace  # or /root
git clone https://github.com/salahudeenofficial/vtryon2_triton.git
cd vtryon2_triton
git checkout microservice
```

### Step 3.2: Run Setup Script

```bash
cd microservices
chmod +x setup_vastai.sh
./setup_vastai.sh
```

**This will:**
- Install system dependencies
- Create Python virtual environment
- Install PyTorch with CUDA
- Setup ComfyUI modules in `triton_model_repository/shared_comfyui/`
- Download all models to `triton_model_repository/shared_models/`
- Verify all files are in place

### Step 3.3: Verify Setup

```bash
# Activate environment
source ../venv/bin/activate

# Check GPU
nvidia-smi

# Verify models
ls -lh triton_model_repository/shared_models/*/

# Verify ComfyUI
ls -la triton_model_repository/shared_comfyui/comfy

# Verify config files
ls -la triton_model_repository/*/config.pbtxt
```

**Checkpoint**: ✅ All models and ComfyUI ready on VastAI

---

## Phase 4: Python Backend Implementation (VastAI)

### Step 4.1: Create Model Template

**Create**: `triton_model_repository/_templates/model_template.py`

This will be created on VastAI instance.

### Step 4.2: Copy Service Code to Model Directories

```bash
cd microservices/triton_model_repository

# For each service
for service in latent_encoder text_encoder sampling decoding; do
    mkdir -p ${service}/1
    cp ../${service}/{service.py,config.py,utils.py,errors.py} ${service}/1/
done
```

### Step 4.3: Implement model.py for Each Service

**For each service**, create `triton_model_repository/{service}/1/model.py`:

1. **Latent Encoder**: `triton_model_repository/latent_encoder/1/model.py`
2. **Text Encoder**: `triton_model_repository/text_encoder/1/model.py`
3. **Sampling**: `triton_model_repository/sampling/1/model.py`
4. **Decoding**: `triton_model_repository/decoding/1/model.py`

**Key Implementation Points**:
- Use `pb_utils.get_model_dir()` to get model directory
- Access shared models: `../../shared_models/`
- Access shared ComfyUI: `../../../shared_comfyui/`
- Set environment variables: `MODEL_DIR`, `COMFYUI_PATH`
- Convert Triton tensors ↔ service format

**Checkpoint**: ✅ All model.py files implemented

---

## Phase 5: Triton Testing on VastAI

### Step 5.1: Verify Docker Setup

**First, check your VastAI instance type:**

```bash
# Check if Docker is available
docker --version
docker ps

# Check GPU access
nvidia-smi

# Check if you're in a container (optional)
cat /proc/1/cgroup | grep docker
```

**Most VastAI instances are VMs with Docker installed** - this works normally.

**If your VastAI instance IS a Docker container**, see `TRITON_DOCKER_SETUP.md` for Docker-in-Docker solutions.

### Step 5.2: Install Triton Server

```bash
# Pull Triton Docker image
docker pull nvcr.io/nvidia/tritonserver:25.10-py3
```

### Step 5.3: Start Triton Server

**Standard approach (works for most VastAI instances):**

```bash
cd /workspace/vtryon2_triton/microservices

# Use the helper script (created by setup_triton_vastai.sh)
./start_triton.sh
```

**Or manually:**

```bash
docker run --gpus=all \
  --shm-size=1g \
  -p 8000:8000 \
  -p 8001:8001 \
  -p 8002:8002 \
  -v $(pwd)/triton_model_repository:/models \
  nvcr.io/nvidia/tritonserver:25.10-py3 \
  tritonserver --model-repository=/models \
  --log-verbose=1
```

**Note**: Keep this running in a separate terminal or use `screen`/`tmux`

**If Docker-in-Docker is needed** (VastAI is a container), see `TRITON_DOCKER_SETUP.md`.

### Step 5.3: Test Individual Models

**For each model**, test from another terminal:

```bash
# Check model status
curl http://localhost:8000/v2/models/latent_encoder

# Test inference (example for latent_encoder)
python test_triton_latent_encoder.py
```

**Checkpoint**: ✅ All individual models working

### Step 5.4: Create and Test Ensemble Model

1. Create `triton_model_repository/vtryon_pipeline/config.pbtxt`
2. Test complete pipeline
3. Verify tensor flow between models

**Checkpoint**: ✅ Ensemble model working

---

## Phase 6: Performance Testing on VastAI

### Step 6.1: Install perf_analyzer

```bash
# Download perf_analyzer
wget https://github.com/triton-inference-server/server/releases/download/v2.45.0/perf_analyzer
chmod +x perf_analyzer
```

### Step 6.2: Run Performance Tests

```bash
# Test each model
./perf_analyzer -m latent_encoder -u localhost:8000
./perf_analyzer -m text_encoder -u localhost:8000
./perf_analyzer -m sampling -u localhost:8000
./perf_analyzer -m decoding -u localhost:8000

# Test ensemble
./perf_analyzer -m vtryon_pipeline -u localhost:8000
```

**Checkpoint**: ✅ Performance verified

---

## Phase 7: Docker Container Preparation (VastAI)

### Step 7.1: Create Dockerfile

**Create**: `Dockerfile.triton` on VastAI instance

**Include**:
- Base: `nvcr.io/nvidia/tritonserver:25.10-py3`
- Python dependencies
- ComfyUI setup
- Model repository structure
- Environment variables

### Step 7.2: Build Docker Image

```bash
docker build -t vtryon-triton:latest -f Dockerfile.triton .
```

### Step 7.3: Test Docker Image

```bash
docker run --gpus=all \
  --shm-size=1g \
  -p 8000:8000 \
  -p 8001:8001 \
  -p 8002:8002 \
  vtryon-triton:latest \
  tritonserver --model-repository=/models
```

**Checkpoint**: ✅ Docker image working

---

## Phase 8: Final Testing & Documentation (VastAI)

### Step 8.1: Complete Testing

- [ ] All individual models tested
- [ ] Ensemble model tested
- [ ] Performance benchmarks completed
- [ ] Resource usage verified
- [ ] Error handling tested

### Step 8.2: Document Results

- [ ] Create `DEPLOYMENT_RESULTS.md`
- [ ] Document any issues encountered
- [ ] Document performance metrics
- [ ] Create troubleshooting guide

**Checkpoint**: ✅ All testing complete, documentation ready

---

## 📋 Quick Reference: VastAI Workflow

### Initial Setup (One Time)
```bash
# 1. Clone repository
git clone https://github.com/salahudeenofficial/vtryon2_triton.git
cd vtryon2_triton
git checkout microservice

# 2. Run setup
cd microservices
./setup_vastai.sh

# 3. Activate environment
source ../venv/bin/activate
```

### Daily Workflow
```bash
# 1. Start Triton server
cd microservices
docker run --gpus=all -p 8000:8000 -p 8001:8001 -p 8002:8002 \
  -v $(pwd)/triton_model_repository:/models \
  nvcr.io/nvidia/tritonserver:25.10-py3 \
  tritonserver --model-repository=/models

# 2. Test models (in another terminal)
cd microservices
python test_triton_*.py
```

---

## 🔄 Workflow Summary

1. **Phase 3**: Setup models and ComfyUI on VastAI (use `setup_vastai.sh`)
2. **Phase 4**: Create Python backend models (implement `model.py` files)
3. **Phase 5**: Test with Triton server on VastAI
4. **Phase 6**: Performance testing on VastAI
5. **Phase 7**: Build Docker image on VastAI
6. **Phase 8**: Final testing and documentation on VastAI

**All work happens on VastAI - no local setup needed!**

---

## 📝 Files to Create on VastAI

1. `triton_model_repository/_templates/model_template.py`
2. `triton_model_repository/latent_encoder/1/model.py`
3. `triton_model_repository/text_encoder/1/model.py`
4. `triton_model_repository/sampling/1/model.py`
5. `triton_model_repository/decoding/1/model.py`
6. `triton_model_repository/vtryon_pipeline/config.pbtxt`
7. `Dockerfile.triton`
8. Test scripts: `test_triton_*.py`

---

## 🚀 Next Steps

1. **Push current code to GitHub** (already done)
2. **SSH into VastAI instance**
3. **Clone repository and run setup_vastai.sh**
4. **Begin Phase 4: Implement Python backend models**

