# Apply OOM Fix Inside Container

## Quick One-Liner (Copy-Paste This)

Run this **inside the container**:

```bash
python3 << 'EOF'
import sys, re
f = "/models/sampling/1/service.py"
with open(f, 'r') as file: c = file.read()
if "with torch.inference_mode():" in c and "# Use torch.inference_mode()" in c:
    print("Already fixed!"); sys.exit(0)
with open(f + ".backup", 'w') as file: file.write(c)
c = re.sub(r'(try:\s+# Setup ComfyUI\s+setup_comfyui\(\)\s+)', r'\1# Use torch.inference_mode() to optimize memory and disable gradient computation\n        # This is critical for preventing memory leaks and ensuring models can be unloaded\n        with torch.inference_mode():\n            ', c)
lines, new_lines, in_block = c.split('\n'), [], False
for line in lines:
    if "with torch.inference_mode():" in line: in_block = True; new_lines.append(line); continue
    if in_block and "# Get sampled latent shape" in line: new_lines.append("        "); in_block = False; new_lines.append(line); continue
    if in_block and line.strip() and not line.startswith('            '): new_lines.append('            ' + line.lstrip())
    else: new_lines.append(line)
c = '\n'.join(new_lines)
c = re.sub(r'(if not isinstance\(sampled_latent, torch\.Tensor\):\s+raise SamplingFailedError\(f"Expected tensor, got \{type\(sampled_latent\)\}: \{sampled_latent\}"\)\s+)', r'\1# Move sampled latent to CPU immediately to free GPU memory\n            sampled_latent = sampled_latent.detach().cpu()\n            \n            ', c)
c = c.replace('# Get sampled latent shape', '# Get sampled latent shape (after moving to CPU)')
c = re.sub(r'(torch\.cuda\.empty_cache\(\))\s+(# Clear GPU cache after sampling)', r'\1\n            torch.cuda.synchronize()\n            ', c)
if 'import gc' not in c: c = re.sub(r'(import comfy\.model_management)', r'\1\n        import gc', c)
c = re.sub(r'(comfy\.model_management\.unload_all_models\(\))\s+# Moves to CPU.*?\n\s+(torch\.cuda\.empty_cache\(\))\s+# Clear GPU cache', r'\1  # Moves to CPU, removes from GPU tracking\n        \2  # Clear GPU cache\n        torch.cuda.synchronize()  # Ensure all CUDA operations complete before cleanup\n        gc.collect()  # Force garbage collection to free Python references', c, flags=re.DOTALL)
with open(f, 'w') as file: file.write(c)
print("✓ Fix applied!")
EOF
```

## Step-by-Step (More Readable)

### Step 1: Create Fix Script

```bash
cat > /tmp/fix_oom.py << 'PYEOF'
#!/usr/bin/env python3
import sys
import re

file_path = "/models/sampling/1/service.py"

# Read file
with open(file_path, 'r') as f:
    content = f.read()

# Check if already fixed
if "with torch.inference_mode():" in content and "# Use torch.inference_mode()" in content:
    print("Already fixed!")
    sys.exit(0)

# Backup
with open(file_path + ".backup", 'w') as f:
    f.write(content)

# Fix 1: Add inference_mode wrapper after setup_comfyui()
content = re.sub(
    r'(try:\s+# Setup ComfyUI\s+setup_comfyui\(\)\s+)',
    r'\1# Use torch.inference_mode() to optimize memory and disable gradient computation\n        # This is critical for preventing memory leaks and ensuring models can be unloaded\n        with torch.inference_mode():\n            ',
    content
)

# Fix 2: Indent the inference block
lines = content.split('\n')
new_lines = []
in_block = False
for line in lines:
    if "with torch.inference_mode():" in line:
        in_block = True
        new_lines.append(line)
        continue
    if in_block and "# Get sampled latent shape" in line:
        new_lines.append("        ")  # Empty line
        in_block = False
        new_lines.append(line)
        continue
    if in_block and line.strip() and not line.startswith('            '):
        new_lines.append('            ' + line.lstrip())
    else:
        new_lines.append(line)

content = '\n'.join(new_lines)

# Fix 3: Move tensor to CPU after validation
content = re.sub(
    r'(if not isinstance\(sampled_latent, torch\.Tensor\):\s+raise SamplingFailedError\(f"Expected tensor, got \{type\(sampled_latent\)\}: \{sampled_latent\}"\)\s+)',
    r'\1# Move sampled latent to CPU immediately to free GPU memory\n            sampled_latent = sampled_latent.detach().cpu()\n            \n            ',
    content
)

# Fix 4: Update comment
content = content.replace('# Get sampled latent shape', '# Get sampled latent shape (after moving to CPU)')

# Fix 5: Add synchronize after empty_cache
content = re.sub(
    r'(torch\.cuda\.empty_cache\(\))\s+(# Clear GPU cache after sampling)',
    r'\1\n            torch.cuda.synchronize()\n            ',
    content
)

# Fix 6: Add gc import
if 'import gc' not in content:
    content = re.sub(r'(import comfy\.model_management)', r'\1\n        import gc', content)

# Fix 7: Update unload section with gc.collect()
content = re.sub(
    r'(comfy\.model_management\.unload_all_models\(\))\s+# Moves to CPU.*?\n\s+(torch\.cuda\.empty_cache\(\))\s+# Clear GPU cache',
    r'\1  # Moves to CPU, removes from GPU tracking\n        \2  # Clear GPU cache\n        torch.cuda.synchronize()  # Ensure all CUDA operations complete before cleanup\n        gc.collect()  # Force garbage collection to free Python references',
    content,
    flags=re.DOTALL
)

# Write back
with open(file_path, 'w') as f:
    f.write(content)

print("✓ Fix applied successfully!")
PYEOF
```

### Step 2: Run the Fix

```bash
python3 /tmp/fix_oom.py
```

### Step 3: Restart Triton

```bash
pkill -f tritonserver && sleep 3 && /workspace/entrypoint.sh > /tmp/triton.log 2>&1 &
```

### Step 4: Verify

```bash
# Check if Triton started
sleep 5 && tail -20 /tmp/triton.log

# Check if fix was applied
grep "torch.inference_mode()" /models/sampling/1/service.py
```

## What the Fix Does

1. **Wraps inference in `torch.inference_mode()`** - Disables gradient computation, reduces memory
2. **Moves sampled tensor to CPU** - Frees GPU memory immediately after sampling
3. **Adds `torch.cuda.synchronize()`** - Ensures all CUDA ops complete before cleanup
4. **Adds `gc.collect()`** - Forces garbage collection to free Python references

## Expected Result

After applying the fix and restarting Triton:
- GPU memory should drop to <1 GB after sampling completes
- No more OOM errors when decoding step tries to load VAE
- Models properly unload between ensemble steps

## Troubleshooting

If the fix fails:
1. Check backup: `ls -lh /models/sampling/1/service.py.backup`
2. Restore backup: `cp /models/sampling/1/service.py.backup /models/sampling/1/service.py`
3. Check Python errors: `python3 /tmp/fix_oom.py 2>&1`


