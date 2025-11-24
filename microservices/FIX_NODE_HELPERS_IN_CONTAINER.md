# Fix: Missing node_helpers.py in Container

## Problem
Error: `No module named 'node_helpers'`

The `node_helpers.py` file was missing from `/workspace/shared_comfyui/` in the container.

## ✅ Local Fix (Already Done)
The file has been copied to:
- `/home/fashionx/vtryon2/microservices/triton_model_repository/shared_comfyui/node_helpers.py`

This will be included in the next Docker image build.

---

## 🔧 Fix in Running Container (Vast AI)

### Option 1: Copy from Project Root (If Available)

```bash
# On Vast AI instance, inside container or via docker exec
CONTAINER_NAME="<your-container-name>"

# If node_helpers.py exists in project root on Vast AI:
docker exec ${CONTAINER_NAME} cp /workspace/node_helpers.py /workspace/shared_comfyui/node_helpers.py

# Or if you're already inside container:
cp /workspace/node_helpers.py /workspace/shared_comfyui/node_helpers.py
```

### Option 2: Create the File Directly

```bash
# On Vast AI instance
CONTAINER_NAME="<your-container-name>"

# Create node_helpers.py in container
docker exec ${CONTAINER_NAME} bash -c 'cat > /workspace/shared_comfyui/node_helpers.py << "EOF"
import hashlib
import torch

from comfy.cli_args import args

from PIL import ImageFile, UnidentifiedImageError

def conditioning_set_values(conditioning, values={}, append=False):
    c = []
    for t in conditioning:
        n = [t[0], t[1].copy()]
        for k in values:
            val = values[k]
            if append:
                old_val = n[1].get(k, None)
                if old_val is not None:
                    val = old_val + val

            n[1][k] = val
        c.append(n)

    return c

def pillow(fn, arg):
    prev_value = None
    try:
        x = fn(arg)
    except (OSError, UnidentifiedImageError, ValueError):
        prev_value = ImageFile.LOAD_TRUNCATED_IMAGES
        ImageFile.LOAD_TRUNCATED_IMAGES = True
        try:
            x = fn(arg)
        except:
            ImageFile.LOAD_TRUNCATED_IMAGES = prev_value
            raise
        ImageFile.LOAD_TRUNCATED_IMAGES = prev_value
    return x

def string_to_torch_dtype(dtype_str):
    if dtype_str == "float32":
        return torch.float32
    elif dtype_str == "float16":
        return torch.float16
    elif dtype_str == "bfloat16":
        return torch.bfloat16
    elif dtype_str == "int8":
        return torch.int8
    elif dtype_str == "int16":
        return torch.int16
    elif dtype_str == "int32":
        return torch.int32
    elif dtype_str == "int64":
        return torch.int64
    elif dtype_str == "uint8":
        return torch.uint8
    else:
        return None

def hasher():
    return hashlib.sha256()
EOF
'
```

### Option 3: Copy from Local Machine (via SCP + docker cp)

```bash
# From your local machine
VAST_AI_IP="<your-vast-ai-ip>"
CONTAINER_NAME="<container-name>"

# Copy file to Vast AI instance
scp /home/fashionx/vtryon2/node_helpers.py root@${VAST_AI_IP}:/tmp/

# Copy into container
ssh root@${VAST_AI_IP} "docker cp /tmp/node_helpers.py ${CONTAINER_NAME}:/workspace/shared_comfyui/"

# Cleanup
ssh root@${VAST_AI_IP} "rm /tmp/node_helpers.py"
```

---

## ✅ Verify Fix

```bash
# Check file exists
docker exec ${CONTAINER_NAME} ls -lh /workspace/shared_comfyui/node_helpers.py

# Test import
docker exec ${CONTAINER_NAME} python3 -c "
import sys
sys.path.insert(0, '/workspace/shared_comfyui')
import node_helpers
print('✓ node_helpers imported successfully')
"
```

---

## 🔄 Restart Container (If Needed)

After copying the file, you may need to restart the container for changes to take effect:

```bash
# Restart container
docker restart ${CONTAINER_NAME}

# Wait for Triton to be ready
sleep 10

# Check logs
docker logs ${CONTAINER_NAME} --tail 50
```

---

## 📝 Next Steps

1. **For Future Builds**: The file is now in the local repository, so it will be included in the next Docker image build.

2. **For Current Container**: Use one of the methods above to copy the file into the running container.

3. **Test**: Try the inference request again after fixing.


