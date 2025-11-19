# Microservice Setup Files - Dependency Configuration Guide

## Overview

Each microservice has a `setup.sh` script that automatically configures all essential dependencies for running the service. This document explains how each setup file handles dependency management.

## Setup Process Flow

All microservice setup scripts follow a consistent pattern:

```
Step 0: Python Virtual Environment Setup
  ↓
Step 1: Clone ComfyUI Core Modules
  ↓
Step 1.5: Merge Requirements (ComfyUI + Microservice-specific)
  ↓
Step 1.6: Install All Dependencies
  ↓
Step 2: Download Required Models
```

---

## Step 0: Python Virtual Environment & Core Dependencies

### What It Does:
1. **Python Version Detection**
   - Prefers Python 3.13, falls back to Python 3.8+
   - Validates Python version compatibility

2. **Virtual Environment Creation**
   - Creates isolated `venv/` directory in each microservice
   - Ensures dependency isolation between services

3. **PyTorch Installation**
   - Installs PyTorch with CUDA 13.0 support
   - Uses PyTorch's official CUDA wheel repository
   - Falls back to default PyTorch if CUDA 13.0 fails

```bash
# Example from setup.sh
pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu130
```

**Why This Matters:**
- Each microservice needs GPU-accelerated PyTorch for model inference
- CUDA 13.0 provides latest GPU optimizations
- Virtual environment prevents dependency conflicts

---

## Step 1: ComfyUI Core Modules Cloning

### What It Does:
Clones essential ComfyUI directories and files needed by the microservice:

**Core Directories Cloned:**
- `comfy/` - Core ComfyUI library
- `comfy_api/` - API definitions
- `comfy_api_nodes/` - API node implementations
- `comfy_config/` - Configuration management
- `comfy_execution/` - Execution engine
- `comfy_extras/` - Extra utilities
- `custom_nodes/` - Custom node support
- `utils/` - Utility functions

**Essential Files Cloned:**
- `nodes.py` - Node registry
- `folder_paths.py` - Model path management
- `main.py` - Main entry point
- `requirements.txt` - Base ComfyUI dependencies

**Why This Matters:**
- Microservices reuse ComfyUI's model loading and processing code
- Avoids code duplication
- Maintains compatibility with ComfyUI ecosystem

---

## Step 1.5: Requirements.txt Merging

### What It Does:
Merges ComfyUI base requirements with microservice-specific dependencies.

**Process:**
1. Copies ComfyUI's `requirements.txt` to microservice directory
2. Appends microservice-specific dependencies
3. Checks for duplicates before adding

### Microservice-Specific Dependencies

All microservices add these common dependencies:

```python
# Kafka Integration (for async message processing)
confluent-kafka>=2.3.0

# Configuration Management (for .env files)
python-dotenv>=1.0.0

# Data Validation (for Kafka message schemas)
pydantic>=2.0.0
```

**Service-Specific Additions:**

#### Decoding Service
```python
Pillow>=9.0.0  # Image processing (explicitly added for safety)
```

#### Text Encoder Service
```python
# Uses same base dependencies
# No additional packages beyond common ones
```

#### Latent Encoder Service
```python
# Uses same base dependencies
# No additional packages beyond common ones
```

#### Sampling Service
```python
# Uses same base dependencies
# No additional packages beyond common ones
```

**Why This Matters:**
- `confluent-kafka`: Enables Kafka-based async communication
- `python-dotenv`: Loads environment variables from `.env` files
- `pydantic`: Validates Kafka message schemas and API requests
- Each service only installs what it needs

---

## Step 1.6: Dependency Installation

### What It Does:
Installs all dependencies from the merged `requirements.txt` file.

**Process:**
1. Activates virtual environment
2. Runs `pip install -r requirements.txt`
3. Continues even if some packages fail (with warning)

**What Gets Installed:**

#### From ComfyUI Base Requirements:
- `torch>=2.0.0` - PyTorch (already installed in Step 0, but version pinned)
- `torchvision>=0.15.0` - Computer vision utilities
- `numpy>=1.24.0` - Numerical computing
- `Pillow>=9.0.0` - Image processing
- `transformers` - Hugging Face transformers
- `safetensors` - Safe model loading
- `accelerate` - Model acceleration
- `xformers` - Attention optimization
- And many more ComfyUI dependencies...

#### From Microservice Additions:
- `confluent-kafka>=2.3.0`
- `python-dotenv>=1.0.0`
- `pydantic>=2.0.0`

**Why This Matters:**
- Ensures all dependencies are available before service starts
- Handles version conflicts automatically
- Provides clear error messages if installation fails

---

## Step 2: Model Downloads

### What It Does:
Downloads required ML models for each microservice.

### Service-Specific Models:

#### Text Encoder Service
```bash
models/
├── clip/
│   └── qwen_2.5_vl_7b_fp8_scaled.safetensors  # CLIP model for text/image encoding
└── vae/
    └── qwen_image_vae.safetensors              # VAE model (shared with other services)
```

#### Latent Encoder Service
```bash
models/
└── vae/
    └── qwen_image_vae.safetensors              # VAE encoder for image→latent
```

#### Sampling Service
```bash
models/
├── diffusion_models/
│   └── qwen_image_edit_2509_fp8_e4m3fn.safetensors  # UNET model for diffusion
└── loras/
    └── Qwen-Image-Lightning-4steps-V2.0.safetensors  # LoRA for fast sampling
```

#### Decoding Service
```bash
models/
└── vae/
    └── qwen_image_vae.safetensors              # VAE decoder for latent→image
```

**Why This Matters:**
- Models are large (GBs), so downloading during setup prevents runtime delays
- Models are cached locally for faster subsequent runs
- Each service only downloads models it needs

---

## Dependency Categories

### 1. **Core ML Dependencies** (Step 0)
- **PyTorch** - Deep learning framework
- **CUDA Support** - GPU acceleration
- **Purpose**: Enables model inference on GPU

### 2. **ComfyUI Framework** (Step 1)
- **ComfyUI Modules** - Model loading, processing, execution
- **Purpose**: Reuses ComfyUI's battle-tested code

### 3. **Communication Dependencies** (Step 1.5)
- **confluent-kafka** - Kafka client for async messaging
- **Purpose**: Enables Kafka-based microservice communication

### 4. **Configuration Dependencies** (Step 1.5)
- **python-dotenv** - Environment variable management
- **pydantic** - Data validation and settings
- **Purpose**: Manages service configuration and validates inputs

### 5. **Model Files** (Step 2)
- **Pre-trained Models** - ML model weights
- **Purpose**: Actual models needed for inference

---

## Integration with Triton & Kafka

### Triton Integration

**Current Setup:**
- Setup scripts prepare dependencies for **direct ComfyUI execution**
- For Triton deployment, models need to be converted to ONNX/TensorRT
- Triton client library (`tritonclient`) would need to be added to requirements

**To Add Triton Support:**
```bash
# Add to Step 1.5 in setup.sh
ADDITIONAL_DEPS+=(
    "tritonclient[grpc]>=2.40.0"  # Triton gRPC client
    "tritonclient[http]>=2.40.0"  # Triton HTTP client (optional)
)
```

**Triton Model Repository:**
- Models must be converted to ONNX/TensorRT format
- Triton config files (`config.pbtxt`) define input/output shapes
- See `TRITON_CONFIG.md` for model repository structure

### Kafka Integration

**Current Setup:**
- ✅ `confluent-kafka` is already installed
- ✅ Kafka handlers are implemented in each service
- ✅ Environment variables configure Kafka connection

**Kafka Dependencies Already Configured:**
```python
# In requirements.txt (added by setup.sh)
confluent-kafka>=2.3.0  # Kafka producer/consumer client
python-dotenv>=1.0.0     # Loads KAFKA_BOOTSTRAP_SERVERS from .env
pydantic>=2.0.0          # Validates Kafka message schemas
```

**Kafka Configuration:**
- Bootstrap servers: `KAFKA_BOOTSTRAP_SERVERS` env var
- Topics: Defined in `config.py` (e.g., `text-encoder-requests`)
- Consumer groups: Defined per service (e.g., `text-encoder-group`)

---

## Running Setup

### For Each Microservice:

```bash
cd microservices/text_encoder  # or latent_encoder, sampling, decoding
chmod +x setup.sh
./setup.sh
```

### What Happens:
1. ✅ Python 3.13 virtual environment created
2. ✅ PyTorch with CUDA 13.0 installed
3. ✅ ComfyUI modules cloned
4. ✅ All dependencies installed
5. ✅ Models downloaded

### After Setup:
```bash
# Activate virtual environment
source venv/bin/activate

# Run service in standalone mode
python main.py --mode standalone --image1_path <path> --image2_path <path> --prompt "..."

# Or run with Kafka
export KAFKA_BOOTSTRAP_SERVERS=localhost:9092
python main.py --mode kafka
```

---

## Dependency Isolation

### Why Each Service Has Its Own Virtual Environment:

1. **Version Independence**
   - Different services might need different package versions
   - Prevents conflicts between services

2. **Deployment Flexibility**
   - Each service can be deployed separately
   - Docker containers can use different base images

3. **Development Isolation**
   - Developers can work on one service without affecting others
   - Testing one service doesn't break others

---

## Troubleshooting

### Common Issues:

#### 1. PyTorch CUDA Installation Fails
```bash
# Setup script falls back to default PyTorch
# Check CUDA version: nvidia-smi
# Manually install matching PyTorch version if needed
```

#### 2. ComfyUI Modules Not Found
```bash
# Ensure you're running setup.sh from microservice directory
# Check COMFYUI_ROOT environment variable
# Verify parent directory has ComfyUI files
```

#### 3. Kafka Connection Errors
```bash
# Verify Kafka is running: docker ps | grep kafka
# Check KAFKA_BOOTSTRAP_SERVERS in .env file
# Test connection: kafka-console-producer --bootstrap-server localhost:9092
```

#### 4. Model Download Fails
```bash
# Check internet connection
# Verify Hugging Face URLs are accessible
# Models are cached, so re-running setup.sh won't re-download
```

---

## Summary

Each microservice setup file:

1. ✅ **Creates isolated Python environment** (Step 0)
2. ✅ **Installs PyTorch with GPU support** (Step 0)
3. ✅ **Clones ComfyUI core modules** (Step 1)
4. ✅ **Merges ComfyUI + microservice dependencies** (Step 1.5)
5. ✅ **Installs all Python packages** (Step 1.6)
6. ✅ **Downloads required ML models** (Step 2)

**Result:** Each microservice is fully self-contained with all dependencies needed to run independently, communicate via Kafka, and optionally integrate with Triton Inference Server.

