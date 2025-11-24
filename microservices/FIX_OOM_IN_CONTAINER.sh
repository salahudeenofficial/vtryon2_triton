#!/bin/bash

# Fix OOM issue in sampling service - Run this inside the container
# This script applies the memory management fixes to sampling/1/service.py

SERVICE_FILE="/models/sampling/1/service.py"
BACKUP_FILE="/models/sampling/1/service.py.backup"

echo "=========================================="
echo "FIXING OOM ISSUE IN SAMPLING SERVICE"
echo "=========================================="
echo ""

# Check if file exists
if [ ! -f "$SERVICE_FILE" ]; then
    echo "ERROR: Service file not found: $SERVICE_FILE"
    exit 1
fi

# Create backup
echo "Creating backup..."
cp "$SERVICE_FILE" "$BACKUP_FILE"
echo "✓ Backup created: $BACKUP_FILE"
echo ""

# Apply fix using Python (more reliable than sed for complex edits)
python3 << 'PYTHON_SCRIPT'
import re

service_file = "/models/sampling/1/service.py"

# Read the file
with open(service_file, 'r') as f:
    content = f.read()

# Check if fix already applied
if "with torch.inference_mode():" in content and "# Use torch.inference_mode()" in content:
    print("⚠ Fix already applied! Skipping...")
    exit(0)

# Find the try block start and wrap the inference code
# Pattern: find "try:\n        # Setup ComfyUI\n        setup_comfyui()\n        \n        # Import ComfyUI nodes"

# Step 1: Add torch.inference_mode() wrapper after setup_comfyui()
pattern1 = r'(try:\s+# Setup ComfyUI\s+setup_comfyui\(\)\s+)'
replacement1 = r'\1# Use torch.inference_mode() to optimize memory and disable gradient computation\n        # This is critical for preventing memory leaks and ensuring models can be unloaded\n        with torch.inference_mode():\n            '
content = re.sub(pattern1, replacement1, content)

# Step 2: Indent all code inside the inference_mode block (from "Import ComfyUI nodes" to end of sampling)
# We need to indent everything from "# Import ComfyUI nodes" to just before "# Get sampled latent shape"
# This is complex, so we'll do it in parts

# First, indent the block from "Import ComfyUI nodes" to "torch.cuda.empty_cache()" after sampling
# Pattern: from "# Import ComfyUI nodes" to "# Clear GPU cache after sampling"
lines = content.split('\n')
in_inference_mode = False
indent_level = 0
new_lines = []

for i, line in enumerate(lines):
    # Detect start of inference_mode block
    if "with torch.inference_mode():" in line:
        in_inference_mode = True
        new_lines.append(line)
        continue
    
    # Detect end of inference_mode block (before "# Get sampled latent shape")
    if in_inference_mode and "# Get sampled latent shape" in line:
        # Close the inference_mode block
        new_lines.append("        ")  # Empty line with proper indentation
        in_inference_mode = False
        new_lines.append(line)
        continue
    
    # If we're in inference_mode, add 4 spaces of indentation
    if in_inference_mode:
        # Skip lines that are already at the right indentation level
        if line.strip() and not line.startswith('            '):
            new_lines.append('            ' + line)
        else:
            new_lines.append(line)
    else:
        new_lines.append(line)

content = '\n'.join(new_lines)

# Step 3: Move sampled tensor to CPU (after "sampled_latent = sampled_latent[0]")
pattern3 = r'(# Ensure it\'s a tensor\s+if not isinstance\(sampled_latent, torch\.Tensor\):\s+raise SamplingFailedError\(f"Expected tensor, got \{type\(sampled_latent\)\}: \{sampled_latent\}"\)\s+)'
replacement3 = r'\1# Move sampled latent to CPU immediately to free GPU memory\n            sampled_latent = sampled_latent.detach().cpu()\n            \n            '
content = re.sub(pattern3, replacement3, content)

# Step 4: Update the comment before "Get sampled latent shape"
pattern4 = r'(# Get sampled latent shape)'
replacement4 = r'# Get sampled latent shape (after moving to CPU)'
content = re.sub(pattern4, replacement4, content)

# Step 5: Add torch.cuda.synchronize() after torch.cuda.empty_cache() in the inference_mode block
pattern5 = r'(torch\.cuda\.empty_cache\(\)\s+torch\.cuda\.synchronize\(\))'
if not re.search(pattern5, content):
    # Add synchronize if not present
    content = re.sub(r'(torch\.cuda\.empty_cache\(\))', r'\1\n            torch.cuda.synchronize()', content)

# Step 6: Add garbage collection after unload_all_models()
pattern6 = r'(import comfy\.model_management\s+comfy\.model_management\.unload_all_models\(\)\s+torch\.cuda\.empty_cache\(\))'
replacement6 = r'import comfy.model_management\n        import gc\n        comfy.model_management.unload_all_models()  # Moves to CPU, removes from GPU tracking\n        torch.cuda.empty_cache()  # Clear GPU cache\n        torch.cuda.synchronize()  # Ensure all CUDA operations complete before cleanup\n        gc.collect()  # Force garbage collection to free Python references'
content = re.sub(pattern6, replacement6, content)

# Write the modified content
with open(service_file, 'w') as f:
    f.write(content)

print("✓ Fix applied successfully!")
PYTHON_SCRIPT

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ FIX APPLIED SUCCESSFULLY"
    echo "=========================================="
    echo ""
    echo "Changes made:"
    echo "  1. ✓ Wrapped inference in torch.inference_mode()"
    echo "  2. ✓ Move sampled tensor to CPU immediately"
    echo "  3. ✓ Added garbage collection after model unloading"
    echo "  4. ✓ Added torch.cuda.synchronize()"
    echo ""
    echo "Next step: RESTART Triton server"
    echo "  pkill -f tritonserver && sleep 3 && /workspace/entrypoint.sh > /tmp/triton.log 2>&1 &"
    echo ""
else
    echo ""
    echo "=========================================="
    echo "❌ FIX FAILED"
    echo "=========================================="
    echo ""
    echo "Restoring backup..."
    cp "$BACKUP_FILE" "$SERVICE_FILE"
    echo "Backup restored. Please check the error above."
    exit 1
fi


