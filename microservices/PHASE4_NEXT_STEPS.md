# Phase 4: Next Steps - Python Backend Implementation

## ✅ Prerequisites Check

Before starting Phase 4, ensure Phase 3 is complete:

```bash
# On your VastAI instance
cd /workspace/vtryon2_triton/microservices

# Verify models exist
ls -lh triton_model_repository/shared_models/*/

# Verify ComfyUI exists
ls -la triton_model_repository/shared_comfyui/comfy

# Verify service code is copied
ls -la triton_model_repository/latent_encoder/1/service.py
ls -la triton_model_repository/text_encoder/1/service.py
ls -la triton_model_repository/sampling/1/service.py
ls -la triton_model_repository/decoding/1/service.py

# Verify config files exist
ls -la triton_model_repository/*/config.pbtxt
```

---

## 🎯 Phase 4 Implementation Order

### Step 1: Create Model Template (15 minutes)

**File**: `triton_model_repository/_templates/model_template.py`

**Action**: Copy the template from `PHASE4_IMPLEMENTATION_GUIDE.md` and save it.

**Verify**: Template file exists and has correct structure.

---

### Step 2: Implement Latent Encoder (30-45 minutes)

**File**: `triton_model_repository/latent_encoder/1/model.py`

**Key Implementation**:
1. Copy template
2. Import `encode_image_to_latent` from service
3. In `initialize()`: Call `setup_comfyui()` to load models
4. In `execute()`: 
   - Extract `input_image` (STRING) from request
   - Decode bytes to string path
   - Call `encode_image_to_latent(image_path)`
   - Convert output tensor to numpy
   - Return as Triton tensor

**Test**: After implementation, start Triton and test:
```bash
./start_triton_direct.sh
curl http://localhost:8000/v2/models/latent_encoder
```

---

### Step 3: Implement Text Encoder (45-60 minutes)

**File**: `triton_model_repository/text_encoder/1/model.py`

**Key Implementation**:
1. Similar to latent_encoder
2. Extract 3 inputs: `image1`, `image2`, `prompt` (all STRING)
3. Call `encode_text_and_images(image1_path, image2_path, prompt, negative_prompt)`
4. Return 2 outputs: `positive_encoding`, `negative_encoding`

**Note**: You may need to handle negative prompt (use empty string or default).

---

### Step 4: Implement Sampling (45-60 minutes)

**File**: `triton_model_repository/sampling/1/model.py`

**Key Implementation**:
1. Extract inputs: `positive_encoding` (STRING path), `negative_encoding` (STRING path), `latent_image` (STRING path), `seed` (INT64), `steps` (INT32), `cfg` (FP32)
2. Call `sample_latent(positive_encoding_path, negative_encoding_path, latent_image_path, seed, steps, cfg)`
3. Return `sampled_latent` tensor

**Note**: Inputs are file paths to tensors. The service function should handle loading these.

---

### Step 5: Implement Decoding (30-45 minutes)

**File**: `triton_model_repository/decoding/1/model.py`

**Key Implementation**:
1. Extract input: `latent` (STRING path)
2. Call `decode_latent_to_image(latent_path)`
3. Return `image` tensor (shape: `[1, 1176, 880, 3]`)

---

### Step 6: Create Ensemble Config (30 minutes)

**File**: `triton_model_repository/vtryon_pipeline/config.pbtxt`

**Action**: Create ensemble configuration that chains all 4 services.

**Note**: You may need to handle intermediate tensor file paths. Triton ensemble passes tensors directly, but your services use file paths. Consider:
- Option A: Modify services to accept tensors directly (more complex)
- Option B: Use intermediate file storage (simpler, but less efficient)
- Option C: Use Triton's tensor passing and convert in model.py (recommended)

---

## 📝 Implementation Checklist

For each model (`latent_encoder`, `text_encoder`, `sampling`, `decoding`):

- [ ] Copy template to `model.py`
- [ ] Implement `initialize()`:
  - [ ] Setup paths (ComfyUI, models)
  - [ ] Set environment variables
  - [ ] Import service functions
  - [ ] Call setup functions (e.g., `setup_comfyui()`)
- [ ] Implement `execute()`:
  - [ ] Extract input tensors
  - [ ] Convert to appropriate format (string paths, etc.)
  - [ ] Call service function
  - [ ] Convert output to Triton tensor format
  - [ ] Return response
- [ ] Implement `finalize()`:
  - [ ] Cleanup GPU memory
  - [ ] Unload models if needed
- [ ] Test with Triton server
- [ ] Verify output shapes match config.pbtxt

---

## 🧪 Testing Strategy

### After Each Model Implementation:

1. **Start Triton**:
   ```bash
   cd microservices
   ./start_triton_direct.sh
   ```

2. **Check Model Status**:
   ```bash
   curl http://localhost:8000/v2/models/{model_name}
   ```

3. **Test Inference** (create simple test script):
   ```python
   import tritonclient.http as httpclient
   
   client = httpclient.InferenceServerClient("localhost:8000")
   
   # Prepare inputs
   inputs = [httpclient.InferInput("input_image", [1], "BYTES")]
   inputs[0].set_data_from_numpy(np.array([b"/path/to/image.jpg"], dtype=object))
   
   # Get outputs
   outputs = [httpclient.InferRequestedOutput("latent")]
   
   # Run inference
   result = client.infer("latent_encoder", inputs, outputs=outputs)
   output = result.as_numpy("latent")
   print(f"Output shape: {output.shape}")
   ```

---

## 🚀 Quick Start Commands

```bash
# 1. Navigate to microservices directory
cd /workspace/vtryon2_triton/microservices

# 2. Create template (copy from PHASE4_IMPLEMENTATION_GUIDE.md)
mkdir -p triton_model_repository/_templates
# Edit triton_model_repository/_templates/model_template.py

# 3. Implement each model (one at a time)
# Start with latent_encoder:
# - Edit triton_model_repository/latent_encoder/1/model.py
# - Test it
# - Then move to next service

# 4. After all models implemented, create ensemble config
# Edit triton_model_repository/vtryon_pipeline/config.pbtxt

# 5. Test everything
./start_triton_direct.sh
# In another terminal, test each model
```

---

## 📚 Reference Documentation

- **Implementation Guide**: `PHASE4_IMPLEMENTATION_GUIDE.md` (detailed code examples)
- **Service Functions**: `microservices/{service}/service.py`
- **Config Data**: `microservices/test_results/{service}/TRITON_CONFIG_DATA.json`
- **Triton Python Backend Docs**: https://github.com/triton-inference-server/python_backend

---

## ⚠️ Important Notes

1. **Path Resolution**: Use `pb_utils.get_model_dir()` to get model directory, then calculate relative paths to shared resources.

2. **Environment Variables**: Set `COMFYUI_PATH` and `MODEL_DIR` in `initialize()` so service code can find resources.

3. **Tensor Formats**: 
   - STRING inputs are bytes - decode to get file paths
   - Output tensors must be numpy arrays with correct dtype

4. **Error Handling**: Always wrap `execute()` logic in try-except and return error responses.

5. **GPU Memory**: Call `torch.cuda.empty_cache()` in `finalize()` to free GPU memory.

---

## 🎯 Success Criteria

Phase 4 is complete when:
- ✅ All 4 models (`model.py`) implemented
- ✅ All models can be loaded by Triton (no import errors)
- ✅ All models can process test requests
- ✅ Output shapes match config.pbtxt
- ✅ Ensemble config created (even if not fully working yet)

---

## Next: Phase 5

Once Phase 4 is complete, proceed to Phase 5: Testing with Triton server.

