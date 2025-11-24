# Container Memory Fix Commands

## Quick Copy-Paste Commands

Run this **ENTIRE block** inside the container:

```bash
# Fix all services at once
for file in /models/latent_encoder/1/service.py /models/text_encoder/1/service.py /models/sampling/1/service.py /models/decoding/1/service.py; do
    [ -f "$file" ] && ! grep -q "unload_all_models()" "$file" && python3 << PYEOF
import sys
f = sys.argv[1]
with open(f, 'r') as file:
    lines = file.readlines()
for i in range(len(lines)-1, -1, -1):
    if 'except Exception' in lines[i]:
        for j in range(i-1, max(0, i-30), -1):
            if 'return result' in lines[j] and 'unload_all_models' not in lines[j]:
                indent = len(lines[j]) - len(lines[j].lstrip())
                code = f'''        # Unload models to CPU
        import comfy.model_management
        comfy.model_management.unload_all_models()
        torch.cuda.empty_cache()
'''
                lines.insert(j, '\n'.join([' ' * indent + l for l in code.split('\n')]))
                with open(f, 'w') as file:
                    file.writelines(lines)
                print(f"✓ Fixed {f}")
                sys.exit(0)
        break
PYEOF
"$file"
done

# Add to entrypoint.sh
[ -f /workspace/entrypoint.sh ] && ! grep -q "PYTORCH_CUDA_ALLOC_CONF" /workspace/entrypoint.sh && \
    sed -i '/^exec tritonserver/i\export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True' /workspace/entrypoint.sh && \
    echo "✓ Updated entrypoint.sh"

# Set for current session
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
echo "✓ Set PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True"

# Verify
echo ""
echo "Verification:"
grep -l "unload_all_models()" /models/*/1/service.py 2>/dev/null | wc -l | xargs -I {} echo "Fixed services: {}"
[ -n "$PYTORCH_CUDA_ALLOC_CONF" ] && echo "✓ Environment variable set" || echo "✗ Not set"

echo ""
echo "✅ Done! Restart container to apply all changes."
```

---

## Individual Service Fixes (If Above Doesn't Work)

### Fix latent_encoder
```bash
python3 << 'PYEOF'
file_path = "/models/latent_encoder/1/service.py"
with open(file_path, 'r') as f:
    lines = f.readlines()
for i in range(len(lines)-1, -1, -1):
    if 'except Exception' in lines[i]:
        for j in range(i-1, max(0, i-30), -1):
            if 'return result' in lines[j] and 'unload_all_models' not in lines[j]:
                indent = len(lines[j]) - len(lines[j].lstrip())
                code = '''        # Unload models to CPU
        import comfy.model_management
        comfy.model_management.unload_all_models()
        torch.cuda.empty_cache()
'''
                lines.insert(j, '\n'.join([' ' * indent + l for l in code.split('\n')]))
                with open(file_path, 'w') as f:
                    f.writelines(lines)
                print("✓ Fixed latent_encoder")
                break
        break
PYEOF
```

### Fix text_encoder
```bash
python3 << 'PYEOF'
file_path = "/models/text_encoder/1/service.py"
with open(file_path, 'r') as f:
    lines = f.readlines()
for i in range(len(lines)-1, -1, -1):
    if 'except Exception' in lines[i]:
        for j in range(i-1, max(0, i-30), -1):
            if 'return result' in lines[j] and 'unload_all_models' not in lines[j]:
                indent = len(lines[j]) - len(lines[j].lstrip())
                code = '''        # Unload models to CPU
        import comfy.model_management
        comfy.model_management.unload_all_models()
        torch.cuda.empty_cache()
'''
                lines.insert(j, '\n'.join([' ' * indent + l for l in code.split('\n')]))
                with open(file_path, 'w') as f:
                    f.writelines(lines)
                print("✓ Fixed text_encoder")
                break
        break
PYEOF
```

### Fix sampling
```bash
python3 << 'PYEOF'
file_path = "/models/sampling/1/service.py"
with open(file_path, 'r') as f:
    lines = f.readlines()
for i in range(len(lines)-1, -1, -1):
    if 'except Exception' in lines[i]:
        for j in range(i-1, max(0, i-30), -1):
            if 'return result' in lines[j] and 'unload_all_models' not in lines[j]:
                indent = len(lines[j]) - len(lines[j].lstrip())
                code = '''        # Unload models to CPU
        import comfy.model_management
        comfy.model_management.unload_all_models()
        torch.cuda.empty_cache()
'''
                lines.insert(j, '\n'.join([' ' * indent + l for l in code.split('\n')]))
                with open(file_path, 'w') as f:
                    f.writelines(lines)
                print("✓ Fixed sampling")
                break
        break
PYEOF
```

### Fix decoding
```bash
python3 << 'PYEOF'
file_path = "/models/decoding/1/service.py"
with open(file_path, 'r') as f:
    lines = f.readlines()
for i in range(len(lines)-1, -1, -1):
    if 'except Exception' in lines[i]:
        for j in range(i-1, max(0, i-30), -1):
            if 'return result' in lines[j] and 'unload_all_models' not in lines[j]:
                indent = len(lines[j]) - len(lines[j].lstrip())
                code = '''        # Unload models to CPU
        import comfy.model_management
        comfy.model_management.unload_all_models()
        torch.cuda.empty_cache()
'''
                lines.insert(j, '\n'.join([' ' * indent + l for l in code.split('\n')]))
                with open(file_path, 'w') as f:
                    f.writelines(lines)
                print("✓ Fixed decoding")
                break
        break
PYEOF
```

---

## Add Environment Variable

```bash
# Add to entrypoint.sh (permanent)
[ -f /workspace/entrypoint.sh ] && ! grep -q "PYTORCH_CUDA_ALLOC_CONF" /workspace/entrypoint.sh && \
    sed -i '/^exec tritonserver/i\export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True' /workspace/entrypoint.sh

# Set for current session (temporary)
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
```

---

## Verify Fixes

```bash
# Check which services have the fix
echo "Services with unload_all_models():"
grep -l "unload_all_models()" /models/*/1/service.py 2>/dev/null

# Check environment variable
echo "PYTORCH_CUDA_ALLOC_CONF: ${PYTORCH_CUDA_ALLOC_CONF:-not set}"

# Check entrypoint.sh
grep "PYTORCH_CUDA_ALLOC_CONF" /workspace/entrypoint.sh 2>/dev/null && echo "✓ In entrypoint.sh" || echo "✗ Not in entrypoint.sh"
```

---

## After Applying Fixes

1. **Restart the container** for changes to take effect
2. **Or restart Triton server** if possible
3. **Test inference** - should use much less memory now

---

## What These Fixes Do

1. **Model Unloading**: After each service completes, models are moved from GPU to CPU
2. **Memory Optimization**: PyTorch uses expandable segments to reduce fragmentation
3. **GPU Cache Clearing**: Clears GPU cache after each step

**Result**: Only one model on GPU at a time, preventing OOM errors.


