# Solutions for Uploading Local Images to Triton Server

## Problem
Images are on your local machine, but Triton expects file paths inside the container.

---

## Solution 1: Quick - Copy Files to Container (Docker)

### Step 1: Copy Files to Container

**From your local machine** (not inside container):

```bash
# Find container name/ID
docker ps

# Copy files to container
docker cp /local/path/to/masked_person.png <container-name>:/workspace/test_images/
docker cp /local/path/to/cloth.png <container-name>:/workspace/test_images/

# Verify files are there
docker exec <container-name> ls -lh /workspace/test_images/
```

### Step 2: Use Paths in JSON Request

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
      "shape": [1],
      "datatype": "INT64",
      "data": [42]
    }
  ],
  "outputs": [{"name": "output_image"}]
}
```

**Pros**: Quick, no code changes  
**Cons**: Manual step, files must be copied each time

---

## Solution 2: Base64 Images in JSON (Recommended)

Modify model files to accept base64-encoded images directly.

### Implementation

I'll modify the model.py files to detect and decode base64 data URIs.

### Postman Setup

**Method**: `POST`  
**URL**: `http://localhost:8000/v2/models/vtryon_pipeline/infer`  
**Headers**: `Content-Type: application/json`

**Body** (with base64 images):
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
      "shape": [1],
      "datatype": "INT64",
      "data": [42]
    }
  ],
  "outputs": [{"name": "output_image"}]
}
```

**How to get base64 in Postman**:
1. Use Postman's "Code" button → Generate code
2. Or use online tool to convert image to base64
3. Or use JavaScript in Postman Pre-request Script

**Pros**: No file upload needed, works directly from Postman  
**Cons**: Requires code changes (I can do this for you)

---

## Solution 3: File Upload Endpoint

Create a simple HTTP server that accepts multipart form data.

### Implementation

Create a Flask/FastAPI endpoint that:
1. Accepts multipart form data with image files
2. Saves files to `/workspace/uploads/`
3. Returns file paths
4. Use paths in Triton inference request

**Pros**: Professional, reusable  
**Cons**: Requires additional service/endpoint

---

## Quick Commands for Solution 1

```bash
# 1. Create upload directory in container
docker exec <container-name> mkdir -p /workspace/test_images

# 2. Copy your local images
docker cp /path/to/your/masked_person.png <container-name>:/workspace/test_images/
docker cp /path/to/your/cloth.png <container-name>:/workspace/test_images/

# 3. Verify
docker exec <container-name> ls -lh /workspace/test_images/

# 4. Use in Postman JSON request
# image1_path: "/workspace/test_images/masked_person.png"
# image2_path: "/workspace/test_images/cloth.png"
```

---

## Recommendation

**For immediate testing**: Use Solution 1 (docker cp)

**For production**: Implement Solution 2 (base64 support) - I can modify the code for you

Would you like me to:
1. Implement base64 support in model.py files?
2. Create a file upload endpoint?
3. Or just use docker cp for now?


