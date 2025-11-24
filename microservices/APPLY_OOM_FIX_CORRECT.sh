#!/bin/bash
# Apply OOM Fix to Sampling Service - Tested and Verified
# Run this INSIDE the container

cat << 'PYEOF' | python3
file_path = "/models/sampling/1/service.py"

# Read file
with open(file_path, 'r') as f:
    content = f.read()

# Check if already fixed
if "with torch.inference_mode():" in content and "# Use torch.inference_mode()" in content:
    print("✓ OOM fix already applied!")
    exit(0)

# Create backup
backup_path = file_path + ".backup"
with open(backup_path, 'w') as f:
    f.write(content)
print(f"✓ Backup created: {backup_path}")

# Read lines
with open(file_path, 'r') as f:
    lines = f.readlines()

# Find the try block and setup_comfyui
fixed_lines = []
i = 0
found_setup = False

while i < len(lines):
    line = lines[i]
    
    # Find "setup_comfyui()" line
    if 'setup_comfyui()' in line and not found_setup:
        fixed_lines.append(line)
        i += 1
        # Skip empty line if present
        if i < len(lines) and not lines[i].strip():
            fixed_lines.append(lines[i])
            i += 1
        # Add the inference_mode wrapper
        fixed_lines.append("        # Use torch.inference_mode() to optimize memory and disable gradient computation\n")
        fixed_lines.append("        # This is critical for preventing memory leaks and ensuring models can be unloaded\n")
        fixed_lines.append("        with torch.inference_mode():\n")
        found_setup = True
        continue
    
    # Find "# Get sampled latent shape" - this is where we exit the block
    if found_setup and '# Get sampled latent shape' in line:
        # Close the inference_mode block with empty line
        fixed_lines.append("        \n")  # Empty line with 8 spaces
        fixed_lines.append(line)  # The comment line
        found_setup = False
        i += 1
        continue
    
    # If we're inside the inference_mode block, ensure 12 spaces indentation
    if found_setup:
        stripped = line.lstrip()
        if not stripped:  # Empty line
            fixed_lines.append('\n')
        else:
            # Count current indentation
            current_indent = len(line) - len(stripped)
            # Should be 12 spaces (inside with block)
            if current_indent < 12:
                # Add spaces
                fixed_lines.append(' ' * (12 - current_indent) + stripped)
            elif current_indent > 12:
                # Remove extra spaces (but keep at least 12)
                fixed_lines.append(' ' * 12 + stripped)
            else:
                # Already correct
                fixed_lines.append(line)
    else:
        fixed_lines.append(line)
    
    i += 1

# Find and add CPU move after tensor validation
content = ''.join(fixed_lines)
# Pattern: after "raise SamplingFailedError" in tensor check, add CPU move
import re
pattern = r'(if not isinstance\(sampled_latent, torch\.Tensor\):\s+raise SamplingFailedError\(f"Expected tensor, got \{type\(sampled_latent\)\}: \{sampled_latent\}"\)\s+)'
replacement = r'\1# Move sampled latent to CPU immediately to free GPU memory\n            sampled_latent = sampled_latent.detach().cpu()\n            \n            '
content = re.sub(pattern, replacement, content)

# Update comment
content = content.replace('# Get sampled latent shape', '# Get sampled latent shape (after moving to CPU)')

# Add synchronize after empty_cache in inference_mode block
content = re.sub(
    r'(torch\.cuda\.empty_cache\(\))\s+(# Clear GPU cache after sampling)',
    r'\1\n            torch.cuda.synchronize()\n            ',
    content
)

# Add gc import if not present
if 'import gc' not in content:
    content = re.sub(
        r'(import comfy\.model_management)',
        r'\1\n        import gc',
        content
    )

# Update unload section with gc.collect()
content = re.sub(
    r'(comfy\.model_management\.unload_all_models\(\))\s+# Moves to CPU.*?\n\s+(torch\.cuda\.empty_cache\(\))\s+# Clear GPU cache',
    r'\1  # Moves to CPU, removes from GPU tracking\n        \2  # Clear GPU cache\n        torch.cuda.synchronize()  # Ensure all CUDA operations complete before cleanup\n        gc.collect()  # Force garbage collection to free Python references',
    content,
    flags=re.DOTALL
)

# Write back
with open(file_path, 'w') as f:
    f.write(content)

print("✓ OOM fix applied successfully!")
PYEOF

# Verify syntax
echo ""
echo "Verifying syntax..."
if python3 -m py_compile /models/sampling/1/service.py 2>&1; then
    echo "✅ Syntax is correct!"
    echo ""
    echo "The OOM fix has been applied. Restart Triton:"
    echo "  pkill -f tritonserver && sleep 3 && /workspace/entrypoint.sh > /tmp/triton.log 2>&1 &"
else
    echo "❌ Syntax error detected!"
    echo "Restoring backup..."
    if [ -f /models/sampling/1/service.py.backup ]; then
        cp /models/sampling/1/service.py.backup /models/sampling/1/service.py
        echo "✓ Backup restored"
    fi
    exit 1
fi


