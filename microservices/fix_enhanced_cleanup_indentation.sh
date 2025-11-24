#!/bin/bash
# Fix indentation error in enhanced cleanup
# Run this INSIDE the container

echo "=========================================="
echo "Fixing Indentation in Enhanced Cleanup"
echo "=========================================="
echo ""

for service in latent_encoder text_encoder sampling decoding; do
    service_file="/models/$service/1/service.py"
    echo "Fixing: $service"
    
    python3 << PYEOF
import sys
file_path = "$service_file"
service_name = "$service"

with open(file_path, 'r') as f:
    lines = f.readlines()

# Find the cleanup section (lines with unload_all_models and soft_empty_cache)
# and replace with properly indented enhanced cleanup
new_lines = []
i = 0
in_cleanup = False
cleanup_start = None

while i < len(lines):
    line = lines[i]
    
    # Detect start of cleanup section
    if 'comfy.model_management.unload_all_models()' in line and '# Moves to CPU' in line:
        in_cleanup = True
        cleanup_start = i
        # Add the enhanced cleanup with proper indentation (8 spaces)
        new_lines.append('        # Aggressively unload models and force memory release\n')
        new_lines.append('        comfy.model_management.unload_all_models()  # Moves to CPU, removes from GPU tracking (calls soft_empty_cache which includes ipc_collect)\n')
        new_lines.append('        \n')
        new_lines.append('        # Force PyTorch to release memory back to CUDA driver (critical for multi-process GPU sharing)\n')
        new_lines.append('        comfy.model_management.soft_empty_cache(force=True)  # Includes ipc_collect() for multi-process scenarios\n')
        new_lines.append('        torch.cuda.synchronize()  # Ensure all CUDA operations complete\n')
        new_lines.append('        \n')
        new_lines.append('        # Multiple empty_cache calls to force allocator to release memory\n')
        new_lines.append('        for _ in range(3):\n')
        new_lines.append('            torch.cuda.empty_cache()\n')
        new_lines.append('            torch.cuda.ipc_collect()\n')
        new_lines.append('            torch.cuda.synchronize()\n')
        new_lines.append('        \n')
        new_lines.append('        # Force garbage collection multiple times to clear Python references\n')
        new_lines.append('        import gc\n')
        new_lines.append('        for _ in range(3):\n')
        new_lines.append('            gc.collect()\n')
        new_lines.append('        \n')
        new_lines.append('        # Final memory release\n')
        new_lines.append('        comfy.model_management.soft_empty_cache(force=True)\n')
        new_lines.append('        torch.cuda.synchronize()\n')
        
        # Skip the old cleanup lines
        while i < len(lines):
            if 'gc.collect()' in lines[i] and '# Force garbage collection' in lines[i]:
                i += 1
                # Skip blank line after gc.collect()
                if i < len(lines) and lines[i].strip() == '':
                    i += 1
                break
            i += 1
        continue
    
    # Skip old cleanup lines we're replacing
    if in_cleanup:
        if 'torch.cuda.synchronize()' in line and '# Ensure all CUDA operations complete before cleanup' in line:
            i += 1
            continue
        if 'gc.collect()' in line and '# Force garbage collection to free Python references' in line:
            in_cleanup = False
            i += 1
            # Skip blank line
            if i < len(lines) and lines[i].strip() == '':
                i += 1
            continue
        if in_cleanup and ('soft_empty_cache' in line or 'Use soft_empty_cache' in line):
            i += 1
            continue
    
    new_lines.append(line)
    i += 1

# Write back
with open(file_path, 'w') as f:
    f.writelines(new_lines)

# Verify syntax
import py_compile
try:
    py_compile.compile(file_path, doraise=True)
    print(f"  ✓ Fixed {service_name} - syntax OK")
except py_compile.PyCompileError as e:
    print(f"  ❌ Syntax error in {service_name}: {e}")
    sys.exit(1)

PYEOF
done

echo ""
echo "=== Verifying syntax ==="
for service in latent_encoder text_encoder sampling decoding; do
    python3 -m py_compile /models/$service/1/service.py 2>&1 && echo "✓ $service syntax OK" || echo "❌ $service has syntax errors"
done

echo ""
echo "=========================================="
echo "Indentation fix complete!"
echo "=========================================="


