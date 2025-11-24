#!/usr/bin/env python3
"""
Fix OOM issue in sampling service by applying memory management improvements.
Run this inside the container.
"""

import sys
import re

SERVICE_FILE = "/models/sampling/1/service.py"

def apply_fix():
    # Read the file
    with open(SERVICE_FILE, 'r') as f:
        lines = f.readlines()
    
    new_lines = []
    i = 0
    in_try_block = False
    in_inference_mode = False
    found_setup_comfyui = False
    
    while i < len(lines):
        line = lines[i]
        
        # Find the try block
        if 'try:' in line and not in_try_block:
            in_try_block = True
            new_lines.append(line)
            i += 1
            continue
        
        # Find setup_comfyui() and add inference_mode wrapper after it
        if in_try_block and 'setup_comfyui()' in line and not found_setup_comfyui:
            new_lines.append(line)
            i += 1
            # Skip empty line if present
            if i < len(lines) and lines[i].strip() == '':
                new_lines.append(lines[i])
                i += 1
            # Add inference_mode wrapper
            new_lines.append("        # Use torch.inference_mode() to optimize memory and disable gradient computation\n")
            new_lines.append("        # This is critical for preventing memory leaks and ensuring models can be unloaded\n")
            new_lines.append("        with torch.inference_mode():\n")
            found_setup_comfyui = True
            in_inference_mode = True
            continue
        
        # Find "# Get sampled latent shape" - this is where we exit inference_mode
        if in_inference_mode and "# Get sampled latent shape" in line:
            # First, check if we need to add the CPU move before this
            # Look back for the tensor validation
            if i > 0 and "Expected tensor" in lines[i-1]:
                # We need to add the CPU move after the tensor check
                # Find where that is
                pass
            
            # Close inference_mode block
            new_lines.append("        \n")  # Empty line
            in_inference_mode = False
            new_lines.append(line)
            i += 1
            continue
        
        # If in inference_mode, indent by 4 more spaces
        if in_inference_mode:
            # Add 4 spaces of indentation
            if line.strip():  # Non-empty line
                if not line.startswith('            '):  # Not already indented enough
                    new_lines.append('            ' + line.lstrip())
                else:
                    new_lines.append(line)
            else:
                new_lines.append(line)
        else:
            new_lines.append(line)
        
        i += 1
    
    # Now do string replacements for specific fixes
    content = ''.join(new_lines)
    
    # Fix 1: Add CPU move after tensor validation (inside inference_mode)
    pattern1 = r'(if not isinstance\(sampled_latent, torch\.Tensor\):\s+raise SamplingFailedError\(f"Expected tensor, got \{type\(sampled_latent\)\}: \{sampled_latent\}"\)\s+)'
    replacement1 = r'\1# Move sampled latent to CPU immediately to free GPU memory\n            sampled_latent = sampled_latent.detach().cpu()\n            \n            '
    content = re.sub(pattern1, replacement1, content)
    
    # Fix 2: Update comment
    content = content.replace('# Get sampled latent shape', '# Get sampled latent shape (after moving to CPU)')
    
    # Fix 3: Add synchronize after empty_cache in inference_mode
    content = re.sub(
        r'(torch\.cuda\.empty_cache\(\))\s+(# Clear GPU cache)',
        r'\1\n            torch.cuda.synchronize()\n            ',
        content
    )
    
    # Fix 4: Add gc import and collect
    if 'import gc' not in content:
        # Find the import comfy.model_management line
        content = re.sub(
            r'(import comfy\.model_management)',
            r'import comfy.model_management\n        import gc',
            content
        )
    
    # Fix 5: Update the unload section
    content = re.sub(
        r'(comfy\.model_management\.unload_all_models\(\))\s+# Moves to CPU.*?\n\s+(torch\.cuda\.empty_cache\(\))\s+# Clear GPU cache',
        r'\1  # Moves to CPU, removes from GPU tracking\n        \2  # Clear GPU cache\n        torch.cuda.synchronize()  # Ensure all CUDA operations complete before cleanup\n        gc.collect()  # Force garbage collection to free Python references',
        content,
        flags=re.DOTALL
    )
    
    # Write back
    with open(SERVICE_FILE, 'w') as f:
        f.write(content)
    
    print("✓ Fix applied successfully!")

if __name__ == '__main__':
    try:
        apply_fix()
        sys.exit(0)
    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


