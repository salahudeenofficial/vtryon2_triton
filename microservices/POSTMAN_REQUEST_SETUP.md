# Postman Request Setup for Triton Inference Server

## Request Configuration

### Method & URL
- **Method**: `POST`
- **URL**: `http://localhost:8000/v2/models/vtryon_pipeline/infer`
  - For Vast AI: `http://<vast-ai-ip>:<port>/v2/models/vtryon_pipeline/infer`

### Headers
```
Content-Type: application/json
```

### Request Body (JSON)

**Option A: Base64-Encoded Images (Recommended - No File Upload Needed)**

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
  "outputs": [
    {
      "name": "output_image"
    }
  ]
}
```

**Option B: File Paths (Files Must Exist in Container)**

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
  "outputs": [
    {
      "name": "output_image"
    }
  ]
}
```

---

## Postman Setup Steps

### Step 1: Create New Request
1. Open Postman
2. Click **New** → **HTTP Request**
3. Name it: `Triton VTryon Pipeline Inference`

### Step 2: Configure Request
1. **Method**: Select `POST`
2. **URL**: Enter `http://localhost:8000/v2/models/vtryon_pipeline/infer`

### Step 3: Set Headers
1. Go to **Headers** tab
2. Add header:
   - **Key**: `Content-Type`
   - **Value**: `application/json`

### Step 4: Set Body
1. Go to **Body** tab
2. Select **raw**
3. Select **JSON** from dropdown
4. Paste the JSON body above

### Step 5: Add Images

**Option A: Base64-Encoded Images (Recommended)**
1. Convert your images to base64 (use online tool or Postman Pre-request Script)
2. Use format: `"data:image/png;base64,<base64_string>"`
3. Paste the full base64 string in the `data` field

**Option B: File Paths**
1. Upload files to container first: `docker cp /local/path/image.png <container>:/workspace/test_images/`
2. Use file paths in the request

**How to Get Base64 in Postman:**
- Use Postman's Pre-request Script to convert files to base64
- Or use online tool: https://www.base64-image.de/
- Or use command line: `base64 -i image.png`

---

## Example Request (Copy-Paste Ready)

### For Local Testing
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

## Expected Response

### Success Response
```json
{
  "model_name": "vtryon_pipeline",
  "model_version": "1",
  "id": "<request-id>",
  "parameters": {},
  "outputs": [
    {
      "name": "output_image",
      "shape": [1, 1176, 880, 3],
      "datatype": "FP32",
      "data": [/* large array of float32 values */]
    }
  ]
}
```

### Error Response (Missing Inputs)
```json
{
  "error": "[request id: <id>] expected 4 inputs but got 0 inputs for model 'vtryon_pipeline'. Got input(s) [], but missing required input(s) ['image1_path','image2_path','prompt','seed']. Please provide all required input(s)."
}
```

### Error Response (File Not Found)
```json
{
  "error": "Image file not found: /path/to/image.png"
}
```

---

## Testing Checklist

- [ ] Server is running (`ps aux | grep tritonserver`)
- [ ] Images exist at specified paths in container
- [ ] Request body has all 4 required inputs
- [ ] Headers include `Content-Type: application/json`
- [ ] URL is correct (check port if using Vast AI)

---

## Troubleshooting

### Error: "expected 4 inputs but got 0"
- Check that request body is valid JSON
- Verify `inputs` array has 4 items
- Check Content-Type header

### Error: "Image file not found"
- Verify image paths exist in container
- Use absolute paths (e.g., `/workspace/test_images/image.png`)
- Check file permissions

### Error: Connection refused
- Verify Triton is running: `ps aux | grep tritonserver`
- Check port: `curl http://localhost:8000/v2/health/live`
- For Vast AI: Check firewall/port forwarding

### Empty Response
- Check server logs: `tail -f /tmp/triton.log`
- Verify models are initialized
- Check GPU memory: `nvidia-smi`

---

## Notes

1. **Image Paths**: Must be absolute paths to files that exist inside the container
2. **Seed**: Integer value, typically 0-2147483647
3. **Prompt**: String describing the virtual try-on task
4. **Output**: Large FP32 array (1176 × 880 × 3 = 3,105,600 floats)
5. **Response Size**: Can be large (~12MB for full image), ensure Postman timeout is sufficient

---

## Quick Test Command (cURL Alternative)

```bash
curl -X POST http://localhost:8000/v2/models/vtryon_pipeline/infer \
  -H "Content-Type: application/json" \
  -d '{
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
  }'
```

