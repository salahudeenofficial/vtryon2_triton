# Comprehensive Testing Checklist - Extract ALL Information

## Purpose
This checklist ensures we capture EVERY piece of information needed for Triton configuration during individual service testing, preventing any need to backtrack.

---

## For EACH Service (latent_encoder, text_encoder, sampling, decoding)

### ✅ Tensor Information (CRITICAL for config.pbtxt)
- [ ] **Input Tensor Name**: `___`
- [ ] **Input Tensor Shape**: `[batch, dim1, dim2, ...]` = `[___, ___, ___, ___]`
- [ ] **Input Data Type**: `TYPE_FP32` / `TYPE_INT32` / `TYPE_STRING` / etc.
- [ ] **Output Tensor Name(s)**: `___` (and `___` if multiple)
- [ ] **Output Tensor Shape(s)**: `[___, ___, ___, ___]`
- [ ] **Output Data Type(s)**: `TYPE_FP32` / etc.
- [ ] **Batch Dimension**: First dimension? Yes/No
- [ ] **Variable Dimensions**: Which dimensions can vary? `___`

**Deliverable**: Tensor shapes and types documented

---

### ✅ Batch Processing (CRITICAL for dynamic_batching config)
- [ ] **Supports Batching**: Yes/No
- [ ] **Maximum Batch Size**: `___` (test until OOM/error)
- [ ] **Optimal Batch Size**: `___` (best throughput/latency)
- [ ] **Batch Size 1 Latency**: `___ ms`
- [ ] **Batch Size 2 Latency**: `___ ms`
- [ ] **Batch Size 4 Latency**: `___ ms`
- [ ] **Batch Size 8 Latency**: `___ ms`
- [ ] **Throughput at Batch 1**: `___ req/sec`
- [ ] **Throughput at Batch 4**: `___ req/sec`
- [ ] **Throughput at Batch 8**: `___ req/sec`

**Deliverable**: Batch size capabilities documented

---

### ✅ Resource Requirements (CRITICAL for instance_group config)
- [ ] **GPU Memory - Model Loading**: `___ MB`
- [ ] **GPU Memory - Inference (batch 1)**: `___ MB`
- [ ] **GPU Memory - Inference (batch 4)**: `___ MB`
- [ ] **GPU Memory - Inference (batch 8)**: `___ MB`
- [ ] **Peak GPU Memory**: `___ MB`
- [ ] **Available GPU Memory**: `___ MB` (total VRAM)
- [ ] **CPU Usage (average)**: `___ %`
- [ ] **Model Size on Disk**: `___ MB`
- [ ] **Model Loading Time**: `___ seconds`

**Deliverable**: Resource profile documented

---

### ✅ Concurrency (CRITICAL for instance_group count)
- [ ] **Maximum Concurrent Requests**: `___` (test until errors)
- [ ] **Optimal Concurrency**: `___` (best throughput)
- [ ] **Latency at Concurrency 1**: `___ ms`
- [ ] **Latency at Concurrency 2**: `___ ms`
- [ ] **Latency at Concurrency 4**: `___ ms`
- [ ] **Throughput at Optimal Concurrency**: `___ req/sec`
- [ ] **GPU Utilization at Optimal Concurrency**: `___ %`
- [ ] **Recommended Instance Count**: `___` (based on VRAM and concurrency)

**Deliverable**: Concurrency analysis documented

---

### ✅ Performance Characteristics (CRITICAL for dynamic_batching and optimization)
- [ ] **P50 Latency**: `___ ms`
- [ ] **P95 Latency**: `___ ms`
- [ ] **P99 Latency**: `___ ms`
- [ ] **Min Latency**: `___ ms`
- [ ] **Max Latency**: `___ ms`
- [ ] **Average Latency**: `___ ms`
- [ ] **Latency Standard Deviation**: `___ ms`

**Deliverable**: Latency profile documented

---

### ✅ Model Information (CRITICAL for model repository structure)
- [ ] **Model Files Required**:
  - [ ] File 1: `___` (path, size: `___ MB`)
  - [ ] File 2: `___` (path, size: `___ MB`)
  - [ ] File 3: `___` (path, size: `___ MB`)
- [ ] **ComfyUI Dependencies**:
  - [ ] Modules: `comfy/`, `comfy_extras/`, etc.
  - [ ] Custom nodes: List all
- [ ] **Model Stateful**: Yes/No (maintains state between requests?)
- [ ] **Model Thread-Safe**: Yes/No (can be shared across instances?)
- [ ] **Model Sharing Strategy**: Shared / Per-Instance / Hybrid

**Deliverable**: Model dependencies documented

---

### ✅ Service-Specific Information

#### For latent_encoder:
- [ ] Input: Single image
- [ ] Output: Latent tensor
- [ ] Model: VAE encoder only

#### For text_encoder:
- [ ] Inputs: image1, image2, prompt (STRING)
- [ ] Outputs: positive_encoding, negative_encoding
- [ ] Models: CLIP + VAE
- [ ] VAE Sharing: Can share with latent_encoder/decoding?

#### For sampling:
- [ ] Inputs: positive_encoding, negative_encoding, latent
- [ ] Output: sampled_latent
- [ ] Models: UNET + LoRA
- [ ] Longest processing time? Yes/No
- [ ] Bottleneck service? Yes/No

#### For decoding:
- [ ] Input: Latent tensor
- [ ] Output: Image tensor
- [ ] Model: VAE decoder
- [ ] VAE Sharing: Can share with latent_encoder/text_encoder?

---

## Pipeline-Level Information

### ✅ End-to-End Pipeline
- [ ] **Total Pipeline Latency**: `___ ms`
- [ ] **Latent Encoder Latency**: `___ ms` (`___ %` of total)
- [ ] **Text Encoder Latency**: `___ ms` (`___ %` of total)
- [ ] **Sampling Latency**: `___ ms` (`___ %` of total)
- [ ] **Decoding Latency**: `___ ms` (`___ %` of total)
- [ ] **Bottleneck Service**: `___` (longest processing time)
- [ ] **Pipeline Throughput**: `___ req/sec`
- [ ] **Total GPU Memory (all services)**: `___ MB`
- [ ] **Memory Overlap Possible**: Yes/No (which models can share?)

**Deliverable**: Pipeline characteristics documented

---

## Model Sharing Analysis

### ✅ VAE Model Sharing
- [ ] **Used By**: latent_encoder, text_encoder, decoding
- [ ] **Can Share?**: Yes/No
- [ ] **Memory Savings if Shared**: `___ MB`
- [ ] **Complexity**: Low/Medium/High
- [ ] **Decision**: Shared / Per-Service

### ✅ Other Models
- [ ] **CLIP**: Used by text_encoder only → No sharing needed
- [ ] **UNET**: Used by sampling only → No sharing needed
- [ ] **LoRA**: Used by sampling only → No sharing needed

**Deliverable**: Model sharing strategy decided

---

## Triton Configuration Decisions

### ✅ Based on Extracted Data, Determine:

#### For Each Model:
- [ ] **max_batch_size**: `___` (from batch testing)
- [ ] **instance_group count**: `___` (from concurrency analysis)
- [ ] **dynamic_batching**: Enabled? Yes/No
- [ ] **preferred_batch_size**: `[___, ___, ___]` (from optimal batch sizes)
- [ ] **max_queue_delay_microseconds**: `___` (from latency analysis)
- [ ] **Model sharing**: Shared / Per-Instance

#### For Ensemble:
- [ ] **max_inflight_requests**: `___` (from concurrency analysis)
- [ ] **Step ordering**: Correct sequence verified
- [ ] **Input/output mappings**: All tensor names match

**Deliverable**: All Triton config decisions made

---

## Output Format

### Create for Each Service: `test_results/<service>/TRITON_CONFIG_DATA.json`

```json
{
  "service": "<service_name>",
  "tensor_info": {
    "input": {
      "name": "<input_name>",
      "shape": [batch, dim1, dim2, dim3],
      "data_type": "TYPE_FP32",
      "batch_support": true/false
    },
    "output": {
      "name": "<output_name>",
      "shape": [batch, dim1, dim2, dim3],
      "data_type": "TYPE_FP32"
    }
  },
  "batch_config": {
    "max_batch_size": 8,
    "optimal_batch_size": 4,
    "supports_batching": true,
    "throughput_by_batch": {
      "1": 10,
      "2": 18,
      "4": 32,
      "8": 50
    }
  },
  "resource_requirements": {
    "gpu_memory_mb": 2048,
    "model_size_mb": 512,
    "peak_memory_mb": 2560,
    "cpu_usage_percent": 25
  },
  "concurrency": {
    "optimal_concurrency": 2,
    "max_concurrency": 4,
    "throughput_req_per_sec": 10,
    "latency_by_concurrency": {
      "1": 100,
      "2": 120,
      "4": 150
    }
  },
  "performance": {
    "p50_latency_ms": 100,
    "p95_latency_ms": 150,
    "p99_latency_ms": 200,
    "avg_latency_ms": 110
  },
  "model_files": {
    "model1": "path/to/model1.safetensors",
    "model2": "path/to/model2.safetensors"
  },
  "triton_config": {
    "recommended_instance_count": 2,
    "recommended_max_batch_size": 8,
    "dynamic_batching": true,
    "preferred_batch_sizes": [1, 2, 4, 8],
    "max_queue_delay_microseconds": 100000,
    "model_sharing": "shared"
  }
}
```

---

## Master Configuration Document

### Create: `test_results/TRITON_MASTER_CONFIG.json`

This document compiles ALL extracted information and serves as the single source of truth for Triton configuration.

**Must Include**:
- All tensor information from all services
- All batch size capabilities
- All resource requirements
- All performance characteristics
- All model file paths
- Model sharing strategy
- Recommended Triton configurations for all models
- Ensemble configuration

**Checkpoint**: ✅ Master config complete = NO BACKTRACKING NEEDED

---

## Testing Tools Needed

### For Resource Profiling:
- `nvidia-smi` - GPU memory monitoring
- `htop` / `top` - CPU monitoring
- Python `memory_profiler` - Memory profiling
- Python `cProfile` - Performance profiling

### For Concurrency Testing:
- Python `threading` / `multiprocessing`
- Python `concurrent.futures`
- Custom test scripts

### For Latency Profiling:
- Python `time` module
- Statistics collection
- Latency histogram generation

---

## Critical Reminders

1. **NO GUESSING**: Every Triton config value must come from extracted data
2. **TEST COMPREHENSIVELY**: Better to over-test than miss information
3. **DOCUMENT EVERYTHING**: Every measurement, every decision
4. **VALIDATE AS YOU GO**: Test each service immediately after extracting data
5. **DON'T SKIP STEPS**: Each test provides critical information

---

## Success Criteria

Phase 1 (Testing) is complete when:
- ✅ All services tested individually
- ✅ All tensor information extracted and documented
- ✅ All batch size capabilities known
- ✅ All resource requirements measured
- ✅ All performance characteristics profiled
- ✅ All concurrency limits tested
- ✅ Model sharing strategy decided
- ✅ Master configuration document created
- ✅ NO INFORMATION MISSING for Triton configuration

**Only then proceed to Phase 2 (Triton Repository Setup)**

