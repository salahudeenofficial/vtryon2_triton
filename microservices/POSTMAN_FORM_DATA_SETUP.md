# Postman Form Data Request Setup for Triton

## Option 1: Multipart Form Data (Upload Files + JSON Request)

Since Triton expects JSON, we'll use a two-step approach:
1. Upload files via form data to a temporary location
2. Send JSON request with file paths

**OR** modify the service to accept base64-encoded images directly.

---

## Option 2: Base64-Encoded Images in JSON (Recommended)

This is the cleanest approach - encode images as base64 and send in JSON.

### Postman Setup

**Method**: `POST`  
**URL**: `http://localhost:8000/v2/models/vtryon_pipeline/infer`

**Headers**:
```
Content-Type: application/json
```

**Body (raw JSON with base64 images)**:
```json
{
  "inputs": [
    {
      "name": "image1_path",
      "shape": [1],
      "datatype": "BYTES",
      "data": ["data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..."]
    },
    {
      "name": "image2_path",
      "shape": [1],
      "datatype": "BYTES",
      "data": ["data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..."]
    },
    {
      "name": "prompt",
      "shape": [1],
      "datatype": "BYTES",
      "data": ["by using the green masked area, try on the cloth"]
    },
    {
      "name": "seed",
      "shape": [1, 1],
      "datatype": "INT64",
      "data": [42]
    }
  ],
  "outputs": [
    {
      "name": "output_image"
    }
  ]
}
```

**Note**: The service code would need to detect base64 data URIs and decode them.

---

## Option 3: Multipart Form Data (If Service Supports It)

If you modify the service to accept multipart form data:

### Postman Setup

**Method**: `POST`  
**URL**: `http://localhost:8000/v2/models/vtryon_pipeline/infer`

**Headers**: (Postman will set this automatically)
```
Content-Type: multipart/form-data
```

**Body (form-data tab)**:
- Key: `image1`, Type: `File`, Value: [Select file]
- Key: `image2`, Type: `File`, Value: [Select file]
- Key: `prompt`, Type: `Text`, Value: `by using the green masked area, try on the cloth`
- Key: `seed`, Type: `Text`, Value: `42`

**Note**: This requires modifying the Python backend to parse multipart form data instead of JSON.

---

## Recommended: Hybrid Approach

### Step 1: Upload Files (if needed)

**Method**: `POST`  
**URL**: `http://localhost:8000/v2/upload` (custom endpoint you'd need to create)

**Body (form-data)**:
- Key: `file`, Type: `File`, Value: [Select image file]

**Response**: Returns file path like `/tmp/uploaded_image_123.png`

### Step 2: Send Inference Request

Use the returned file path in the JSON request as shown in `POSTMAN_REQUEST_SETUP.md`.

---

## Current Implementation (File Paths)

The current implementation expects **file paths as strings**. So you have two options:

### Option A: Upload files first, then use paths

1. Upload files to container (via SSH, volume mount, or custom upload endpoint)
2. Use file paths in JSON request

### Option B: Modify service to accept base64

Modify the model.py files to:
1. Detect if input is a base64 data URI
2. Decode and save to temp file
3. Use temp file path

---

## Quick Implementation: Base64 Support

To add base64 support, modify the model files to check for base64:

```python
import base64
import tempfile
import os

def extract_string(tensor):
    data = tensor.as_numpy()
    if data.dtype == object:
        s = data.item()
        path = s.decode('utf-8') if isinstance(s, bytes) else str(s)
    else:
        path = data.tobytes().decode('utf-8').rstrip('\x00')
    
    # Check if it's a base64 data URI
    if path.startswith('data:image'):
        # Extract base64 part
        header, encoded = path.split(',', 1)
        # Decode base64
        image_data = base64.b64decode(encoded)
        # Save to temp file
        with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as tmp:
            tmp.write(image_data)
            return tmp.name
    return path
```

---

## Postman Form Data Example (Current - Requires File Upload First)

If files are already in container:

**Method**: `POST`  
**URL**: `http://localhost:8000/v2/models/vtryon_pipeline/infer`

**Headers**:
```
Content-Type: application/json
```

**Body (raw JSON)**:
```json
{
  "inputs": [
    {
      "name": "image1_path",
      "shape": [1],
      "datatype": "BYTES",
      "data": ["/workspace/test_images/masked_person.png"]
    },
    {
      "name": "image2_path",
      "shape": [1],
      "datatype": "BYTES",
      "data": ["/workspace/test_images/cloth.png"]
    },
    {
      "name": "prompt",
      "shape": [1],
      "datatype": "BYTES",
      "data": ["by using the green masked area, try on the cloth"]
    },
    {
      "name": "seed",
      "shape": [1, 1],
      "datatype": "INT64",
      "data": [42]
    }
  ],
  "outputs": [
    {
      "name": "output_image"
    }
  ]
}
```

---

## Summary

**Current Setup**: JSON with file paths (files must exist in container)

**Recommended for Form Data**: 
1. Add base64 support to model files (modify `model.py`)
2. Use JSON with base64-encoded images
3. OR create a file upload endpoint first

**Easiest Now**: Upload files to container first, then use JSON with paths.


