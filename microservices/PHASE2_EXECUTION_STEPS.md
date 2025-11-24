# Phase 2: Execution Steps - Comprehensive Service Testing

## Overview
Phase 2 extracts all information needed for Triton configuration by testing each service individually on a VastAI GPU instance.

---

## Step 1: Deploy to VastAI Instance

### 1.1 Get VastAI Instance
1. Go to https://vast.ai
2. Rent a GPU instance (recommended: RTX 3090/4090 or A100 with 24GB+ VRAM)
3. Note the instance IP and SSH credentials

### 1.2 Connect to Instance
```bash
ssh root@<vastai-instance-ip>
```

### 1.3 Clone Repository
```bash
cd /root
git clone https://github.com/salahudeenofficial/vtryon2_triton.git
cd vtryon2_triton
```

---

## Step 2: Run Setup Script

### 2.1 Execute Setup
```bash
cd microservices
chmod +x setup_vastai.sh
./setup_vastai.sh
```

**This will:**
- Install system dependencies (git, wget, etc.)
- Create Python virtual environment
- Install PyTorch with CUDA
- Setup ComfyUI modules
- Download all models (VAE, CLIP, UNET, LoRA)
- Create test directories

**Expected Duration:** 30-60 minutes (depends on model download speeds)

### 2.2 Verify Setup
```bash
# Activate environment
source ../venv/bin/activate

# Check GPU
nvidia-smi

# Check PyTorch CUDA
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"

# Check models downloaded
ls -lh triton_model_repository/shared_models/*/
```

---

## Step 3: Prepare Test Data

### 3.1 Create Test Images Directory
```bash
mkdir -p test_data/images
```

### 3.2 Add Test Images
You need:
- `test_data/images/person.jpg` - Person image with green mask
- `test_data/images/cloth.jpg` - Clothing image

**Option 1: Upload your own images**
```bash
# Use scp from your local machine
scp person.jpg root@<vastai-ip>:/root/vtryon2_triton/microservices/test_data/images/
scp cloth.jpg root@<vastai-ip>:/root/vtryon2_triton/microservices/test_data/images/
```

**Option 2: Download sample images**
```bash
cd test_data/images
# Download sample images (replace with your URLs)
wget <your-image-url> -O person.jpg
wget <your-image-url> -O cloth.jpg
```

---

## Step 4: Run Individual Service Tests

### 4.1 Test Latent Encoder
```bash
cd /root/vtryon2_triton/microservices
source ../venv/bin/activate
python test_latent_encoder.py
```

**What it extracts:**
- Input tensor shape (image → latent)
- Output tensor shape
- Data types
- Performance metrics
- GPU memory usage
- Model loading time

**Output:** `test_results/latent_encoder/TRITON_CONFIG_DATA.json`

### 4.2 Test Text Encoder
```bash
python test_text_encoder.py
```

**What it extracts:**
- Multiple inputs (image1, image2, prompt)
- Multiple outputs (positive_encoding, negative_encoding)
- Tensor shapes for all I/O
- Performance characteristics
- Resource usage

**Output:** `test_results/text_encoder/TRITON_CONFIG_DATA.json`

**Note:** Uses the Chinese prompt from `ensemble_prompts.json`

### 4.3 Test Sampling
```bash
python test_sampling.py
```

**What it extracts:**
- Input shapes (conditioning, latent, seed, steps, cfg)
- Output shape (sampled latent)
- UNET + LoRA model requirements
- Processing time (likely bottleneck)
- GPU memory (likely highest usage)

**Output:** `test_results/sampling/TRITON_CONFIG_DATA.json`

### 4.4 Test Decoding
```bash
python test_decoding.py
```

**What it extracts:**
- Input shape (latent)
- Output shape (image tensor)
- VAE decoder requirements
- Performance metrics

**Output:** `test_results/decoding/TRITON_CONFIG_DATA.json`

---

## Step 5: Run Comprehensive Tests (Optional but Recommended)

### 5.1 Batch Processing Tests
For each service, test with different batch sizes:

```bash
# Modify test scripts to test batch sizes: 1, 2, 4, 8
# Or create separate batch test scripts
```

**Extract:**
- Maximum batch size (until OOM)
- Optimal batch size (best throughput)
- Batch processing times
- Throughput (req/sec)

### 5.2 Concurrency Tests
Test multiple simultaneous requests:

```bash
# Create concurrency test script
# Test with 1, 2, 4 concurrent requests
```

**Extract:**
- Maximum concurrent requests
- Optimal concurrency
- Latency at different concurrency levels
- GPU utilization

### 5.3 Resource Profiling
Monitor resources during each test:

```bash
# Use nvidia-smi in separate terminal
watch -n 1 nvidia-smi

# Or use Python profiling in test scripts
```

**Extract:**
- GPU memory per service
- Peak memory usage
- CPU usage
- Model loading time

---

## Step 6: End-to-End Pipeline Test

### 6.1 Create Pipeline Test Script
```bash
# Create test_pipeline.py that runs all services in sequence
# Measures total latency and per-service breakdown
```

### 6.2 Run Pipeline Test
```bash
python test_pipeline.py
```

**Extract:**
- Total pipeline latency
- Per-service latency breakdown
- Bottleneck identification
- Total GPU memory (all services)
- Memory overlap analysis (can VAE be shared?)

**Output:** `test_results/pipeline/TRITON_CONFIG_DATA.json`

---

## Step 7: Compile Master Configuration

### 7.1 Review All Results
```bash
# Check all TRITON_CONFIG_DATA.json files
cat test_results/*/TRITON_CONFIG_DATA.json
```

### 7.2 Create Master Config
Create `test_results/TRITON_MASTER_CONFIG.json` with:

```json
{
  "services": {
    "latent_encoder": { /* from test_results/latent_encoder/ */ },
    "text_encoder": { /* from test_results/text_encoder/ */ },
    "sampling": { /* from test_results/sampling/ */ },
    "decoding": { /* from test_results/decoding/ */ }
  },
  "pipeline": { /* from test_results/pipeline/ */ },
  "model_sharing": {
    "vae": {
      "used_by": ["latent_encoder", "text_encoder", "decoding"],
      "sharing_strategy": "shared",
      "memory_savings_mb": 0
    }
  },
  "triton_recommendations": {
    "instance_counts": { /* per service */ },
    "batch_sizes": { /* per service */ },
    "dynamic_batching": { /* per service */ }
  }
}
```

### 7.3 Model Sharing Analysis
Document which models can be shared:
- VAE: Used by latent_encoder, text_encoder, decoding
- CLIP: Used by text_encoder only
- UNET: Used by sampling only
- LoRA: Used by sampling only

**Output:** `test_results/MODEL_SHARING_STRATEGY.md`

---

## Step 8: Download Results

### 8.1 Compress Results
```bash
cd /root/vtryon2_triton/microservices
tar -czf phase2_results.tar.gz test_results/
```

### 8.2 Download to Local Machine
```bash
# From your local machine
scp root@<vastai-ip>:/root/vtryon2_triton/microservices/phase2_results.tar.gz ./
```

### 8.3 Review Results Locally
```bash
tar -xzf phase2_results.tar.gz
# Review all JSON files
```

---

## Step 9: Validate Phase 2 Completion

### Checklist
- [ ] All 4 services tested individually
- [ ] All `TRITON_CONFIG_DATA.json` files generated
- [ ] Tensor shapes documented for all inputs/outputs
- [ ] Data types documented
- [ ] Performance metrics collected
- [ ] Resource usage profiled
- [ ] Batch size capabilities tested
- [ ] Concurrency limits identified
- [ ] Pipeline test completed
- [ ] Master configuration compiled
- [ ] Model sharing strategy decided

### Success Criteria
✅ All information needed for Triton `config.pbtxt` creation is documented
✅ No need to backtrack - all data captured
✅ Ready to proceed to Phase 3 (Triton config creation)

---

## Troubleshooting

### Import Errors
```bash
# Verify ComfyUI setup
./validate_imports.sh

# Check Python path
python -c "import sys; print('\n'.join(sys.path))"
```

### GPU Out of Memory
- Reduce batch size in test scripts
- Test services one at a time
- Close other processes using GPU

### Model Download Failures
- Check internet connection
- Verify Hugging Face URLs
- Models are large - be patient
- Retry failed downloads manually

### Test Script Errors
- Check test data exists: `ls test_data/images/`
- Verify model paths in config
- Check service code imports
- Review error messages in test output

---

## Next Steps After Phase 2

Once Phase 2 is complete:

1. **Phase 3**: Create Triton `config.pbtxt` files using extracted data
2. **Phase 4**: Implement full Python backend models (`model.py`)
3. **Phase 5**: Create ensemble model configuration
4. **Phase 6**: Test Triton server locally
5. **Phase 7**: Containerize with Docker
6. **Phase 8**: Deploy to VastAI for final testing

---

**Status**: Ready to execute on VastAI instance


## Overview
Phase 2 extracts all information needed for Triton configuration by testing each service individually on a VastAI GPU instance.

---

## Step 1: Deploy to VastAI Instance

### 1.1 Get VastAI Instance
1. Go to https://vast.ai
2. Rent a GPU instance (recommended: RTX 3090/4090 or A100 with 24GB+ VRAM)
3. Note the instance IP and SSH credentials

### 1.2 Connect to Instance
```bash
ssh root@<vastai-instance-ip>
```

### 1.3 Clone Repository
```bash
cd /root
git clone https://github.com/salahudeenofficial/vtryon2_triton.git
cd vtryon2_triton
```

---

## Step 2: Run Setup Script

### 2.1 Execute Setup
```bash
cd microservices
chmod +x setup_vastai.sh
./setup_vastai.sh
```

**This will:**
- Install system dependencies (git, wget, etc.)
- Create Python virtual environment
- Install PyTorch with CUDA
- Setup ComfyUI modules
- Download all models (VAE, CLIP, UNET, LoRA)
- Create test directories

**Expected Duration:** 30-60 minutes (depends on model download speeds)

### 2.2 Verify Setup
```bash
# Activate environment
source ../venv/bin/activate

# Check GPU
nvidia-smi

# Check PyTorch CUDA
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"

# Check models downloaded
ls -lh triton_model_repository/shared_models/*/
```

---

## Step 3: Prepare Test Data

### 3.1 Create Test Images Directory
```bash
mkdir -p test_data/images
```

### 3.2 Add Test Images
You need:
- `test_data/images/person.jpg` - Person image with green mask
- `test_data/images/cloth.jpg` - Clothing image

**Option 1: Upload your own images**
```bash
# Use scp from your local machine
scp person.jpg root@<vastai-ip>:/root/vtryon2_triton/microservices/test_data/images/
scp cloth.jpg root@<vastai-ip>:/root/vtryon2_triton/microservices/test_data/images/
```

**Option 2: Download sample images**
```bash
cd test_data/images
# Download sample images (replace with your URLs)
wget <your-image-url> -O person.jpg
wget <your-image-url> -O cloth.jpg
```

---

## Step 4: Run Individual Service Tests

### 4.1 Test Latent Encoder
```bash
cd /root/vtryon2_triton/microservices
source ../venv/bin/activate
python test_latent_encoder.py
```

**What it extracts:**
- Input tensor shape (image → latent)
- Output tensor shape
- Data types
- Performance metrics
- GPU memory usage
- Model loading time

**Output:** `test_results/latent_encoder/TRITON_CONFIG_DATA.json`

### 4.2 Test Text Encoder
```bash
python test_text_encoder.py
```

**What it extracts:**
- Multiple inputs (image1, image2, prompt)
- Multiple outputs (positive_encoding, negative_encoding)
- Tensor shapes for all I/O
- Performance characteristics
- Resource usage

**Output:** `test_results/text_encoder/TRITON_CONFIG_DATA.json`

**Note:** Uses the Chinese prompt from `ensemble_prompts.json`

### 4.3 Test Sampling
```bash
python test_sampling.py
```

**What it extracts:**
- Input shapes (conditioning, latent, seed, steps, cfg)
- Output shape (sampled latent)
- UNET + LoRA model requirements
- Processing time (likely bottleneck)
- GPU memory (likely highest usage)

**Output:** `test_results/sampling/TRITON_CONFIG_DATA.json`

### 4.4 Test Decoding
```bash
python test_decoding.py
```

**What it extracts:**
- Input shape (latent)
- Output shape (image tensor)
- VAE decoder requirements
- Performance metrics

**Output:** `test_results/decoding/TRITON_CONFIG_DATA.json`

---

## Step 5: Run Comprehensive Tests (Optional but Recommended)

### 5.1 Batch Processing Tests
For each service, test with different batch sizes:

```bash
# Modify test scripts to test batch sizes: 1, 2, 4, 8
# Or create separate batch test scripts
```

**Extract:**
- Maximum batch size (until OOM)
- Optimal batch size (best throughput)
- Batch processing times
- Throughput (req/sec)

### 5.2 Concurrency Tests
Test multiple simultaneous requests:

```bash
# Create concurrency test script
# Test with 1, 2, 4 concurrent requests
```

**Extract:**
- Maximum concurrent requests
- Optimal concurrency
- Latency at different concurrency levels
- GPU utilization

### 5.3 Resource Profiling
Monitor resources during each test:

```bash
# Use nvidia-smi in separate terminal
watch -n 1 nvidia-smi

# Or use Python profiling in test scripts
```

**Extract:**
- GPU memory per service
- Peak memory usage
- CPU usage
- Model loading time

---

## Step 6: End-to-End Pipeline Test

### 6.1 Create Pipeline Test Script
```bash
# Create test_pipeline.py that runs all services in sequence
# Measures total latency and per-service breakdown
```

### 6.2 Run Pipeline Test
```bash
python test_pipeline.py
```

**Extract:**
- Total pipeline latency
- Per-service latency breakdown
- Bottleneck identification
- Total GPU memory (all services)
- Memory overlap analysis (can VAE be shared?)

**Output:** `test_results/pipeline/TRITON_CONFIG_DATA.json`

---

## Step 7: Compile Master Configuration

### 7.1 Review All Results
```bash
# Check all TRITON_CONFIG_DATA.json files
cat test_results/*/TRITON_CONFIG_DATA.json
```

### 7.2 Create Master Config
Create `test_results/TRITON_MASTER_CONFIG.json` with:

```json
{
  "services": {
    "latent_encoder": { /* from test_results/latent_encoder/ */ },
    "text_encoder": { /* from test_results/text_encoder/ */ },
    "sampling": { /* from test_results/sampling/ */ },
    "decoding": { /* from test_results/decoding/ */ }
  },
  "pipeline": { /* from test_results/pipeline/ */ },
  "model_sharing": {
    "vae": {
      "used_by": ["latent_encoder", "text_encoder", "decoding"],
      "sharing_strategy": "shared",
      "memory_savings_mb": 0
    }
  },
  "triton_recommendations": {
    "instance_counts": { /* per service */ },
    "batch_sizes": { /* per service */ },
    "dynamic_batching": { /* per service */ }
  }
}
```

### 7.3 Model Sharing Analysis
Document which models can be shared:
- VAE: Used by latent_encoder, text_encoder, decoding
- CLIP: Used by text_encoder only
- UNET: Used by sampling only
- LoRA: Used by sampling only

**Output:** `test_results/MODEL_SHARING_STRATEGY.md`

---

## Step 8: Download Results

### 8.1 Compress Results
```bash
cd /root/vtryon2_triton/microservices
tar -czf phase2_results.tar.gz test_results/
```

### 8.2 Download to Local Machine
```bash
# From your local machine
scp root@<vastai-ip>:/root/vtryon2_triton/microservices/phase2_results.tar.gz ./
```

### 8.3 Review Results Locally
```bash
tar -xzf phase2_results.tar.gz
# Review all JSON files
```

---

## Step 9: Validate Phase 2 Completion

### Checklist
- [ ] All 4 services tested individually
- [ ] All `TRITON_CONFIG_DATA.json` files generated
- [ ] Tensor shapes documented for all inputs/outputs
- [ ] Data types documented
- [ ] Performance metrics collected
- [ ] Resource usage profiled
- [ ] Batch size capabilities tested
- [ ] Concurrency limits identified
- [ ] Pipeline test completed
- [ ] Master configuration compiled
- [ ] Model sharing strategy decided

### Success Criteria
✅ All information needed for Triton `config.pbtxt` creation is documented
✅ No need to backtrack - all data captured
✅ Ready to proceed to Phase 3 (Triton config creation)

---

## Troubleshooting

### Import Errors
```bash
# Verify ComfyUI setup
./validate_imports.sh

# Check Python path
python -c "import sys; print('\n'.join(sys.path))"
```

### GPU Out of Memory
- Reduce batch size in test scripts
- Test services one at a time
- Close other processes using GPU

### Model Download Failures
- Check internet connection
- Verify Hugging Face URLs
- Models are large - be patient
- Retry failed downloads manually

### Test Script Errors
- Check test data exists: `ls test_data/images/`
- Verify model paths in config
- Check service code imports
- Review error messages in test output

---

## Next Steps After Phase 2

Once Phase 2 is complete:

1. **Phase 3**: Create Triton `config.pbtxt` files using extracted data
2. **Phase 4**: Implement full Python backend models (`model.py`)
3. **Phase 5**: Create ensemble model configuration
4. **Phase 6**: Test Triton server locally
5. **Phase 7**: Containerize with Docker
6. **Phase 8**: Deploy to VastAI for final testing

---

**Status**: Ready to execute on VastAI instance







