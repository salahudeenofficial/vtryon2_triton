#!/bin/bash

# Simple fix for OOM in sampling service - Run inside container
# Copy-paste this entire block into the container

cat << 'EOF' > /tmp/fix_oom.py
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

# Fix 2: Indent the inference block (from "# Import ComfyUI nodes" to before "# Get sampled latent shape")
lines = content.split('\n')
new_lines = []
in_block = False
for i, line in enumerate(lines):
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

# Fix 3: Add CPU move after tensor check
content = re.sub(
    r'(if not isinstance\(sampled_latent, torch\.Tensor\):\s+raise SamplingFailedError\(f"Expected tensor, got \{type\(sampled_latent\)\}: \{sampled_latent\}"\)\s+)',
    r'\1# Move sampled latent to CPU immediately to free GPU memory\n            sampled_latent = sampled_latent.detach().cpu()\n            \n            ',
    content
)

# Fix 4: Update comment
content = content.replace('# Get sampled latent shape', '# Get sampled latent shape (after moving to CPU)')

# Fix 5: Add synchronize
content = re.sub(
    r'(torch\.cuda\.empty_cache\(\))\s+(# Clear GPU cache after sampling)',
    r'\1\n            torch.cuda.synchronize()\n            ',
    content
)

# Fix 6: Add gc import and collect
if 'import gc' not in content:
    content = re.sub(
        r'(import comfy\.model_management)',
        r'\1\n        import gc',
        content
    )

# Fix 7: Update unload section
content = re.sub(
    r'(comfy\.model_management\.unload_all_models\(\))\s+# Moves to CPU.*?\n\s+(torch\.cuda\.empty_cache\(\))\s+# Clear GPU cache',
    r'\1  # Moves to CPU, removes from GPU tracking\n        \2  # Clear GPU cache\n        torch.cuda.synchronize()  # Ensure all CUDA operations complete before cleanup\n        gc.collect()  # Force garbage collection to free Python references',
    content,
    flags=re.DOTALL
)

# Write back
with open(file_path, 'w') as f:
    f.write(content)

print("✓ Fix applied!")
EOF

python3 /tmp/fix_oom.py && echo "✅ Success! Restart Triton: pkill -f tritonserver && sleep 3 && /workspace/entrypoint.sh > /tmp/triton.log 2>&1 &" || echo "❌ Failed"


