# Quick Fix: ComfyUI Not Found Error

## Problem
The test script can't find ComfyUI directory. This means either:
1. `setup_vastai.sh` hasn't been run yet
2. ComfyUI source doesn't exist in project root
3. Setup script failed to copy ComfyUI

## Solution 1: Run Setup Script (Recommended)

If you haven't run the setup script yet:

```bash
cd /workspace/vtryon2_triton/microservices
chmod +x setup_vastai.sh
./setup_vastai.sh
```

This will copy ComfyUI from project root to `triton_model_repository/shared_comfyui`.

## Solution 2: Manual ComfyUI Copy

If setup script failed or ComfyUI source is in a different location:

### Step 1: Find ComfyUI Source
```bash
# Check if ComfyUI exists in project root
ls -la /workspace/vtryon2_triton/comfy 2>/dev/null
ls -la /workspace/vtryon2_triton/ComfyUI 2>/dev/null

# Or check parent directory
ls -la /workspace/comfy 2>/dev/null
ls -la /workspace/ComfyUI 2>/dev/null
```

### Step 2: Copy ComfyUI to Shared Location
```bash
cd /workspace/vtryon2_triton/microservices
mkdir -p triton_model_repository/shared_comfyui

# If ComfyUI is in project root
if [ -d "/workspace/vtryon2_triton/comfy" ]; then
    cp -r /workspace/vtryon2_triton/comfy triton_model_repository/shared_comfyui/
    cp -r /workspace/vtryon2_triton/comfy_api triton_model_repository/shared_comfyui/ 2>/dev/null
    cp -r /workspace/vtryon2_triton/comfy_execution triton_model_repository/shared_comfyui/ 2>/dev/null
    cp -r /workspace/vtryon2_triton/comfy_extras triton_model_repository/shared_comfyui/ 2>/dev/null
    cp /workspace/vtryon2_triton/nodes.py triton_model_repository/shared_comfyui/ 2>/dev/null
    cp /workspace/vtryon2_triton/folder_paths.py triton_model_repository/shared_comfyui/ 2>/dev/null
    cp /workspace/vtryon2_triton/execution.py triton_model_repository/shared_comfyui/ 2>/dev/null
    echo "✓ ComfyUI copied from project root"
fi
```

### Step 3: Verify
```bash
ls -la triton_model_repository/shared_comfyui/comfy
# Should show comfy directory exists
```

## Solution 3: Use Environment Variable

If ComfyUI is in a completely different location, set environment variable:

```bash
export COMFYUI_PATH=/path/to/your/comfyui
cd /workspace/vtryon2_triton/microservices
python test_latent_encoder.py
```

## Solution 4: Clone ComfyUI (If Not in Project)

If ComfyUI doesn't exist anywhere, you may need to clone it:

```bash
cd /workspace/vtryon2_triton
git clone https://github.com/comfyanonymous/ComfyUI.git
cd microservices
mkdir -p triton_model_repository/shared_comfyui
cp -r ../ComfyUI/comfy triton_model_repository/shared_comfyui/
cp -r ../ComfyUI/comfy_api triton_model_repository/shared_comfyui/
cp -r ../ComfyUI/comfy_execution triton_model_repository/shared_comfyui/
cp -r ../ComfyUI/comfy_extras triton_model_repository/shared_comfyui/
cp ../ComfyUI/nodes.py triton_model_repository/shared_comfyui/
cp ../ComfyUI/folder_paths.py triton_model_repository/shared_comfyui/
cp ../ComfyUI/execution.py triton_model_repository/shared_comfyui/
```

## Verify Fix

After applying any solution, verify:

```bash
cd /workspace/vtryon2_triton/microservices
python -c "
from pathlib import Path
comfyui_path = Path('triton_model_repository/shared_comfyui')
if (comfyui_path / 'comfy').exists():
    print('✓ ComfyUI found at:', comfyui_path)
else:
    print('✗ ComfyUI not found')
"
```

Then run the test:
```bash
python test_latent_encoder.py
```


## Problem
The test script can't find ComfyUI directory. This means either:
1. `setup_vastai.sh` hasn't been run yet
2. ComfyUI source doesn't exist in project root
3. Setup script failed to copy ComfyUI

## Solution 1: Run Setup Script (Recommended)

If you haven't run the setup script yet:

```bash
cd /workspace/vtryon2_triton/microservices
chmod +x setup_vastai.sh
./setup_vastai.sh
```

This will copy ComfyUI from project root to `triton_model_repository/shared_comfyui`.

## Solution 2: Manual ComfyUI Copy

If setup script failed or ComfyUI source is in a different location:

### Step 1: Find ComfyUI Source
```bash
# Check if ComfyUI exists in project root
ls -la /workspace/vtryon2_triton/comfy 2>/dev/null
ls -la /workspace/vtryon2_triton/ComfyUI 2>/dev/null

# Or check parent directory
ls -la /workspace/comfy 2>/dev/null
ls -la /workspace/ComfyUI 2>/dev/null
```

### Step 2: Copy ComfyUI to Shared Location
```bash
cd /workspace/vtryon2_triton/microservices
mkdir -p triton_model_repository/shared_comfyui

# If ComfyUI is in project root
if [ -d "/workspace/vtryon2_triton/comfy" ]; then
    cp -r /workspace/vtryon2_triton/comfy triton_model_repository/shared_comfyui/
    cp -r /workspace/vtryon2_triton/comfy_api triton_model_repository/shared_comfyui/ 2>/dev/null
    cp -r /workspace/vtryon2_triton/comfy_execution triton_model_repository/shared_comfyui/ 2>/dev/null
    cp -r /workspace/vtryon2_triton/comfy_extras triton_model_repository/shared_comfyui/ 2>/dev/null
    cp /workspace/vtryon2_triton/nodes.py triton_model_repository/shared_comfyui/ 2>/dev/null
    cp /workspace/vtryon2_triton/folder_paths.py triton_model_repository/shared_comfyui/ 2>/dev/null
    cp /workspace/vtryon2_triton/execution.py triton_model_repository/shared_comfyui/ 2>/dev/null
    echo "✓ ComfyUI copied from project root"
fi
```

### Step 3: Verify
```bash
ls -la triton_model_repository/shared_comfyui/comfy
# Should show comfy directory exists
```

## Solution 3: Use Environment Variable

If ComfyUI is in a completely different location, set environment variable:

```bash
export COMFYUI_PATH=/path/to/your/comfyui
cd /workspace/vtryon2_triton/microservices
python test_latent_encoder.py
```

## Solution 4: Clone ComfyUI (If Not in Project)

If ComfyUI doesn't exist anywhere, you may need to clone it:

```bash
cd /workspace/vtryon2_triton
git clone https://github.com/comfyanonymous/ComfyUI.git
cd microservices
mkdir -p triton_model_repository/shared_comfyui
cp -r ../ComfyUI/comfy triton_model_repository/shared_comfyui/
cp -r ../ComfyUI/comfy_api triton_model_repository/shared_comfyui/
cp -r ../ComfyUI/comfy_execution triton_model_repository/shared_comfyui/
cp -r ../ComfyUI/comfy_extras triton_model_repository/shared_comfyui/
cp ../ComfyUI/nodes.py triton_model_repository/shared_comfyui/
cp ../ComfyUI/folder_paths.py triton_model_repository/shared_comfyui/
cp ../ComfyUI/execution.py triton_model_repository/shared_comfyui/
```

## Verify Fix

After applying any solution, verify:

```bash
cd /workspace/vtryon2_triton/microservices
python -c "
from pathlib import Path
comfyui_path = Path('triton_model_repository/shared_comfyui')
if (comfyui_path / 'comfy').exists():
    print('✓ ComfyUI found at:', comfyui_path)
else:
    print('✗ ComfyUI not found')
"
```

Then run the test:
```bash
python test_latent_encoder.py
```







