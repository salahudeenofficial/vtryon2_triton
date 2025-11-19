# Quick Fix: Missing protocol.py

## Problem
Error: `No module named 'protocol'`

The `protocol.py` file is missing from `shared_comfyui` directory.

## Quick Fix (On VastAI)

Copy the missing file from project root:

```bash
cd /workspace/vtryon2_triton/microservices
cp /workspace/vtryon2_triton/protocol.py triton_model_repository/shared_comfyui/ 2>/dev/null || \
cp ../protocol.py triton_model_repository/shared_comfyui/ 2>/dev/null || \
echo "⚠️  protocol.py not found in expected locations"
```

Or if you have the original vtryon2 repo:

```bash
cp /workspace/vtryon2/protocol.py /workspace/vtryon2_triton/microservices/triton_model_repository/shared_comfyui/
```

## Verify

```bash
ls -la triton_model_repository/shared_comfyui/protocol.py
# Should show the file exists
```

Then run the test again:
```bash
python test_latent_encoder.py
```

## Permanent Fix

The `setup_vastai.sh` script has been updated to include `protocol.py` in future runs. Also, if you pull the latest changes, `protocol.py` should be in the git repository.

