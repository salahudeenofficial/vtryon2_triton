# Check Triton Initialization Errors

## Problem

After recent edits, Triton is unloading models during startup with timeout errors. This suggests models are failing to initialize properly.

## Diagnostic Commands

Run these **inside the container** to diagnose:

### 1. Check if models are actually initializing

```bash
# Check Triton logs for initialization errors
grep -i "error\|fail\|exception" /tmp/triton.log | tail -50

# Check for Python import errors
grep -i "import\|module\|traceback" /tmp/triton.log | tail -50

# Check model initialization status
grep -E "(Initializing|initialized|LOADING|READY|UNLOADING)" /tmp/triton.log | tail -30
```

### 2. Check if service files have syntax errors

```bash
# Check sampling service for syntax errors
python3 -m py_compile /models/sampling/1/service.py 2>&1
python3 -m py_compile /models/sampling/1/model.py 2>&1

# Check all service files
for model in latent_encoder text_encoder sampling decoding; do
    echo "Checking $model..."
    python3 -m py_compile /models/$model/1/service.py 2>&1
    python3 -m py_compile /models/$model/1/model.py 2>&1
done
```

### 3. Test if service can be imported

```bash
# Test sampling service import
cd /models/sampling/1
python3 << 'EOF'
import sys
import os
sys.path.insert(0, '/workspace/shared_comfyui')
sys.path.insert(0, '/models/sampling/1')
try:
    from service import sample_latent
    print("✓ Service import successful")
except Exception as e:
    print(f"✗ Service import failed: {e}")
    import traceback
    traceback.print_exc()
EOF
```

### 4. Check if the torch.inference_mode() wrapper is causing issues

The recent OOM fix wrapped the sampling code in `torch.inference_mode()`. This shouldn't affect initialization, but let's verify:

```bash
# Check if the wrapper is correctly placed (should be inside execute, not initialize)
grep -A 5 "with torch.inference_mode()" /models/sampling/1/service.py | head -10
```

### 5. Check Triton server startup

```bash
# Start Triton with full output to see initialization
pkill -f tritonserver
sleep 2
/workspace/entrypoint.sh 2>&1 | tee /tmp/triton_full.log &
sleep 10
tail -100 /tmp/triton_full.log
```

## Common Issues

### Issue 1: Syntax Error in service.py

If there's a syntax error from the OOM fix:

```bash
# Restore backup if it exists
if [ -f /models/sampling/1/service.py.backup ]; then
    cp /models/sampling/1/service.py.backup /models/sampling/1/service.py
    echo "Backup restored"
fi
```

### Issue 2: Indentation Error

The torch.inference_mode() wrapper might have incorrect indentation:

```bash
# Check indentation around the wrapper
sed -n '260,280p' /models/sampling/1/service.py
```

### Issue 3: Import Error

If service imports are failing:

```bash
# Check if all dependencies are available
python3 -c "import torch; import sys; sys.path.insert(0, '/workspace/shared_comfyui'); from nodes import UNETLoader; print('OK')"
```

## Quick Fix: Revert Recent Changes

If the issue started after the OOM fix, you can temporarily revert:

```bash
# Restore sampling service from backup (if exists)
if [ -f /models/sampling/1/service.py.backup ]; then
    cp /models/sampling/1/service.py.backup /models/sampling/1/service.py
    echo "✓ Reverted to backup"
fi

# Restart Triton
pkill -f tritonserver && sleep 3 && /workspace/entrypoint.sh > /tmp/triton.log 2>&1 &
```

## Expected Output

After running diagnostics, you should see:
- ✓ All Python files compile without errors
- ✓ Service imports work
- ✓ Models initialize successfully
- ✓ No timeout/unloading during startup

If you see errors, share them and we can fix the specific issue.


