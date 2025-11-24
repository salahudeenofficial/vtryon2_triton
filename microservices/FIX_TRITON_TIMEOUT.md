# Fix Triton Model Unloading During Startup

## Problem

Triton is unloading models during startup with this error:
```
Timeout 30: Found 0 model versions that have in-flight inferences
All models are stopped, unloading models
error: creating server: Internal - failed to load all models
```

## Root Cause

Triton has a default exit timeout that unloads models if they're idle for too long. During startup, models are being initialized (which can take time for Python backend), and Triton thinks they're idle and unloads them.

## Solution

Add these flags to Triton server startup:

1. **`--exit-timeout-secs=0`** - Disables automatic model unloading on timeout
2. **`--strict-model-config=false`** - Allows more flexible model configuration

## Fix Applied

Updated `entrypoint.sh` to include:
```bash
exec tritonserver \
    --model-repository=/models \
    --log-verbose=1 \
    --cuda-memory-pool-byte-size=0:178257920 \
    --exit-timeout-secs=0 \
    --strict-model-config=false \
    "$@"
```

## Apply Fix in Container

If you need to apply this fix inside a running container:

```bash
# Edit entrypoint.sh
sed -i 's/--cuda-memory-pool-byte-size=0:178257920/--cuda-memory-pool-byte-size=0:178257920 \\\n    --exit-timeout-secs=0 \\\n    --strict-model-config=false/' /workspace/entrypoint.sh

# Restart Triton
pkill -f tritonserver && sleep 3 && /workspace/entrypoint.sh > /tmp/triton.log 2>&1 &
```

## Alternative: One-Liner

```bash
sed -i '/--cuda-memory-pool-byte-size=0:178257920/a\    --exit-timeout-secs=0 \\\n    --strict-model-config=false' /workspace/entrypoint.sh && pkill -f tritonserver && sleep 3 && /workspace/entrypoint.sh > /tmp/triton.log 2>&1 &
```

## Expected Behavior After Fix

- Models will stay loaded after initialization
- No automatic unloading during startup
- Models only unload when explicitly requested or container stops
- Server should start successfully

## Verification

After applying fix, check logs:
```bash
tail -f /tmp/triton.log | grep -E "(LOADING|READY|UNLOADING)"
```

You should see:
- Models go from LOADING → READY
- No UNLOADING messages during startup
- Server starts successfully


