# Fix CUDA OOM Error in Container

## Problem
You're getting: `CUDA out of memory. Tried to allocate 66.00 MiB. GPU 0 has a total capacity of 44.35 GiB of which 40.81 MiB is free.`

This happens because all models (UNET 33GB, CLIP 10GB, VAE) are loaded on GPU simultaneously.

## Solution
Apply memory management fixes to unload models after each step.

---

## Quick Fix (Copy-Paste Ready)

Run this **ENTIRE block** inside the container:

```bash
# Fix all service files
for file in /models/latent_encoder/1/service.py /models/text_encoder/1/service.py /models/sampling/1/service.py /models/decoding/1/service.py; do
    if [ -f "$file" ] && ! grep -q "unload_all_models" "$file"; then
        echo "Fixing: $file"
        python3 << PYEOF
import sys
f = sys.argv[1]
with open(f, 'r') as file:
    lines = file.readlines()
for i in range(len(lines)-1, -1, -1):
    if 'return result' in lines[i] and 'unload_all_models' not in lines[i]:
        j = i + 1
        while j < len(lines) and lines[j].strip() == '':
            j += 1
        if j < len(lines) and 'except Exception' in lines[j]:
            indent = len(lines[i]) - len(lines[i].lstrip())
            memory_lines = [
                '        # Unload models to CPU (critical for memory management)\n',
                '        import comfy.model_management\n',
                '        comfy.model_management.unload_all_models()\n',
                '        torch.cuda.empty_cache()\n'
            ]
            indent_str = ' ' * indent
            for line in memory_lines:
                lines.insert(i, indent_str + line)
            with open(f, 'w') as out:
                out.writelines(lines)
            print("✓ Fixed " + f)
            sys.exit(0)
        break
PYEOF
        "$file"
    else
        echo "✓ Already fixed: $file"
    fi
done

# Fix entrypoint
if ! grep -q "PYTORCH_CUDA_ALLOC_CONF" /workspace/entrypoint.sh 2>/dev/null; then
    sed -i '/^exec tritonserver/i\export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True' /workspace/entrypoint.sh
    echo "✓ Fixed entrypoint.sh"
fi

# Set for current session
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

echo ""
echo "✅ Fixes applied! Now RESTART Triton:"
echo "   pkill -f tritonserver && sleep 3 && nohup /workspace/entrypoint.sh > /tmp/triton.log 2>&1 &"
```

---

## What This Does

1. **Adds memory management to each service file:**
   - `comfy.model_management.unload_all_models()` - Moves models from GPU to CPU
   - `torch.cuda.empty_cache()` - Clears GPU cache
   - This ensures only ONE model is on GPU at a time

2. **Sets PyTorch memory optimization:**
   - `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True` - Reduces fragmentation

3. **Restarts Triton** to apply changes

---

## Verify Fixes Are Applied

```bash
# Check service files
for file in /models/latent_encoder/1/service.py /models/text_encoder/1/service.py /models/sampling/1/service.py /models/decoding/1/service.py; do
    [ -f "$file" ] && grep -q "unload_all_models" "$file" && echo "✓ $(basename $(dirname $(dirname $file)))" || echo "✗ $(basename $(dirname $(dirname $file)))"
done

# Check entrypoint
grep -q "PYTORCH_CUDA_ALLOC_CONF" /workspace/entrypoint.sh && echo "✓ Entrypoint fixed" || echo "✗ Entrypoint not fixed"
```

---

## After Restarting

1. **Monitor logs:**
   ```bash
   tail -f /tmp/triton.log
   ```

2. **Check GPU memory:**
   ```bash
   nvidia-smi
   ```

3. **Test inference again** - should not OOM

---

## Expected Behavior After Fix

- **Before each step:** Models are on CPU
- **During step:** Only the active model loads to GPU
- **After step:** Model unloads back to CPU
- **Result:** Only 1 model on GPU at a time (max ~33GB instead of 44GB+)

---

## Troubleshooting

If OOM still occurs:

1. **Check if fixes were applied:**
   ```bash
   grep -A 2 "return result" /models/sampling/1/service.py | head -5
   ```

2. **Check GPU memory before inference:**
   ```bash
   nvidia-smi
   ```

3. **Check Triton logs for errors:**
   ```bash
   grep -i "error\|oom\|memory" /tmp/triton.log | tail -20
   ```

4. **Verify models are unloading:**
   - Watch `nvidia-smi` during inference
   - Memory should drop after each step completes


