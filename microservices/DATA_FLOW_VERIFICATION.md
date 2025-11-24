# Data Flow Verification Between 4 Models

## Overview
This document verifies the data flow between all 4 models in the vtryon pipeline.

---

## Data Flow Diagram

```
Pipeline Input
├── image1_path (STRING)
├── image2_path (STRING)
├── prompt (STRING)
└── seed (INT64)

    │
    ├─► Step 1: latent_encoder
    │   Input:  image1_path
    │   Output: latent [16, 1, 147, 110] FP32
    │   └─► Internal: "latent_encoded"
    │
    ├─► Step 2: text_encoder (parallel)
    │   Input:  image1_path, image2_path, prompt
    │   Output: positive_encoding [437, 3584] FP32
    │           negative_encoding [407, 3584] FP32
    │
    └─► Step 3: sampling
        Input:  positive_encoding [437, 3584]
                negative_encoding [407, 3584]
                latent_image [16, 1, 147, 110] ← "latent_encoded"
                seed [1] INT64
        Output: sampled_latent [16, 1, 147, 110] FP32
        └─► Internal: "sampled_latent"
            │
            └─► Step 4: decoding
                Input:  latent [16, 1, 147, 110] ← "sampled_latent"
                Output: image [1176, 880, 3] FP32
                └─► Pipeline Output: "output_image"
```

---

## Model Configurations

### 1. latent_encoder
- **Input**: `image_path` (STRING, dims: [-1])
- **Output**: `latent` (FP32, dims: [16, 1, 147, 110])
- **Service Function**: `encode_image_to_latent()`
- **Returns**: `result['latent_tensor']`

### 2. text_encoder
- **Inputs**: 
  - `image1_path` (STRING, dims: [-1])
  - `image2_path` (STRING, dims: [-1])
  - `prompt` (STRING, dims: [-1])
- **Outputs**:
  - `positive_encoding` (FP32, dims: [437, 3584])
  - `negative_encoding` (FP32, dims: [407, 3584])
- **Service Function**: `encode_text_and_images()`
- **Returns**: `result['positive_encoding_tensor']`, `result['negative_encoding_tensor']`

### 3. sampling
- **Inputs**:
  - `positive_encoding` (FP32, dims: [437, 3584])
  - `negative_encoding` (FP32, dims: [407, 3584])
  - `latent_image` (FP32, dims: [16, 1, 147, 110])
  - `seed` (INT64, dims: [1])
- **Output**: `sampled_latent` (FP32, dims: [16, 1, 147, 110])
- **Service Function**: `sample_latent()`
- **Returns**: `result['sampled_latent_tensor']`

### 4. decoding
- **Input**: `latent` (FP32, dims: [16, 1, 147, 110])
- **Output**: `image` (FP32, dims: [1176, 880, 3])
- **Service Function**: `decode_latent_to_image()`
- **Returns**: `result['image_tensor']`

---

## Ensemble Configuration Mapping

### Step 1: latent_encoder
```protobuf
input_map {
  key: "image_path"
  value: "image1_path"  # From pipeline input
}
output_map {
  key: "latent"
  value: "latent_encoded"  # Internal name for next step
}
```

### Step 2: text_encoder
```protobuf
input_map {
  key: "image1_path"
  value: "image1_path"  # From pipeline input
}
input_map {
  key: "image2_path"
  value: "image2_path"  # From pipeline input
}
input_map {
  key: "prompt"
  value: "prompt"  # From pipeline input
}
output_map {
  key: "positive_encoding"
  value: "positive_encoding"  # Internal name
}
output_map {
  key: "negative_encoding"
  value: "negative_encoding"  # Internal name
}
```

### Step 3: sampling
```protobuf
input_map {
  key: "positive_encoding"
  value: "positive_encoding"  # From text_encoder output
}
input_map {
  key: "negative_encoding"
  value: "negative_encoding"  # From text_encoder output
}
input_map {
  key: "latent_image"
  value: "latent_encoded"  # From latent_encoder output
}
input_map {
  key: "seed"
  value: "seed"  # From pipeline input
}
output_map {
  key: "sampled_latent"
  value: "sampled_latent"  # Internal name for next step
}
```

### Step 4: decoding
```protobuf
input_map {
  key: "latent"
  value: "sampled_latent"  # From sampling output
}
output_map {
  key: "image"
  value: "output_image"  # Final pipeline output
}
```

---

## Batch Dimension Handling

### Important Notes:
1. **Triton Configuration**: All models have `max_batch_size: 1`
2. **Triton Expectation**: Tensors should NOT have batch dimension in output
3. **Service Functions**: May return tensors WITH or WITHOUT batch dimension
4. **Model.py Responsibility**: Handle batch dimension conversion

### Batch Dimension Rules:

#### Input Processing (Triton → Service):
- **2D tensors** (encodings): Add batch if needed: `[437, 3584]` → `[1, 437, 3584]`
- **4D tensors** (latents): Add batch if needed: `[16, 1, 147, 110]` → `[1, 16, 1, 147, 110]`

#### Output Processing (Service → Triton):
- **2D tensors** (encodings): Remove batch if present: `[1, 437, 3584]` → `[437, 3584]`
- **4D tensors** (latents): Remove batch if present: `[1, 16, 1, 147, 110]` → `[16, 1, 147, 110]`
- **3D tensors** (images): Remove batch if present: `[1, 1176, 880, 3]` → `[1176, 880, 3]`

### Implementation in model.py:

#### latent_encoder/model.py:
```python
# Output: Remove batch dimension
if len(latent_np.shape) == 5 and latent_np.shape[0] == 1:
    latent_np = latent_np[0]  # [1, 16, 1, 147, 110] → [16, 1, 147, 110]
elif len(latent_np.shape) == 4:
    pass  # Already correct [16, 1, 147, 110]
```

#### text_encoder/model.py:
```python
# Output: Remove batch dimension
if len(positive_np.shape) == 3 and positive_np.shape[0] == 1:
    positive_np = positive_np[0]  # [1, 437, 3584] → [437, 3584]
elif len(positive_np.shape) == 2:
    pass  # Already correct [437, 3584]
```

#### sampling/model.py:
```python
# Input: Add batch dimension
if len(positive_pt.shape) == 2:
    positive_pt = positive_pt.unsqueeze(0)  # [437, 3584] → [1, 437, 3584]
if len(latent_pt.shape) == 4:
    latent_pt = latent_pt.unsqueeze(0)  # [16, 1, 147, 110] → [1, 16, 1, 147, 110]

# Output: Remove batch dimension
if len(sampled_np.shape) == 5 and sampled_np.shape[0] == 1:
    sampled_np = sampled_np[0]  # [1, 16, 1, 147, 110] → [16, 1, 147, 110]
```

#### decoding/model.py:
```python
# Input: Add batch dimension
if len(latent_pt.shape) == 4:
    latent_pt = latent_pt.unsqueeze(0)  # [16, 1, 147, 110] → [1, 16, 1, 147, 110]

# Output: Remove batch dimension
if len(image_np.shape) == 4 and image_np.shape[0] == 1:
    image_np = image_np[0]  # [1, 1176, 880, 3] → [1176, 880, 3]
```

---

## Tensor Shape Verification

### Expected Shapes at Each Step:

1. **latent_encoder output**: `[16, 1, 147, 110]` FP32
2. **text_encoder outputs**: 
   - `positive_encoding`: `[437, 3584]` FP32
   - `negative_encoding`: `[407, 3584]` FP32
3. **sampling input**: 
   - `positive_encoding`: `[437, 3584]` → Service expects `[1, 437, 3584]`
   - `negative_encoding`: `[407, 3584]` → Service expects `[1, 407, 3584]`
   - `latent_image`: `[16, 1, 147, 110]` → Service expects `[1, 16, 1, 147, 110]`
4. **sampling output**: `[16, 1, 147, 110]` FP32
5. **decoding input**: `[16, 1, 147, 110]` → Service expects `[1, 16, 1, 147, 110]`
6. **decoding output**: `[1176, 880, 3]` FP32

---

## Error Handling

All models follow consistent error handling:

1. **Input Validation**: Check for missing inputs
2. **Service Call**: Wrap in try/except
3. **Error Response**: Return `pb_utils.InferenceResponse` with error
4. **Logging**: Log errors with traceback

---

## Verification Checklist

- [x] Ensemble config maps all inputs/outputs correctly
- [x] Tensor shapes match between models
- [x] Batch dimension handling is consistent
- [x] Service functions return expected keys
- [x] Error handling is consistent
- [x] All models use COMFYUI_PATH environment variable
- [x] All models handle string inputs correctly
- [x] All models convert tensors to correct dtype (FP32)

---

## Fixed Issues

1. ✅ **service.py hardcoded path** - Fixed to use COMFYUI_PATH
2. ✅ **Batch dimension handling** - Fixed incorrect logic in sampling and decoding
3. ✅ **Shape checking** - Fixed incorrect checks (> 4 vs == 5, > 3 vs == 4)
4. ✅ **Consistent error handling** - All models follow same pattern

---

## Testing Recommendations

1. Test each model individually with sample inputs
2. Test ensemble pipeline end-to-end
3. Verify tensor shapes at each step
4. Check batch dimension handling
5. Verify error messages are clear


