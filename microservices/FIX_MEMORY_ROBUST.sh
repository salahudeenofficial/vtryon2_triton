#!/bin/bash
# Robust memory fix script - handles edge cases better

fix_service_file() {
    local file=$1
    local service_name=$(basename $(dirname $(dirname $file)))
    
    if [ ! -f "$file" ]; then
        echo "✗ File not found: $file"
        return 1
    fi
    
    # Check if already fixed
    if grep -q "unload_all_models" "$file"; then
        echo "✓ $service_name: Already has memory management"
        return 0
    fi
    
    echo "Fixing: $service_name"
    
    # Use Python with better error handling
    python3 << PYEOF
import sys
import re

file_path = sys.argv[1]

try:
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Check if already fixed
    if 'unload_all_models' in content:
        print(f"  Already fixed: {file_path}")
        sys.exit(0)
    
    # Find the last "return result" before "except Exception"
    # Use regex to find the pattern
    pattern = r'(\s+)(return result)\s*\n\s*\n\s*(except Exception)'
    match = re.search(pattern, content)
    
    if match:
        indent = match.group(1)
        memory_code = f'''{indent}# Unload models to CPU (critical for memory management)
{indent}import comfy.model_management
{indent}comfy.model_management.unload_all_models()
{indent}torch.cuda.empty_cache()
{indent}
'''
        # Insert before "return result"
        new_content = content[:match.start()] + memory_code + content[match.start():]
        
        with open(file_path, 'w') as f:
            f.write(new_content)
        print(f"  ✓ Fixed {file_path}")
        sys.exit(0)
    else:
        # Fallback: find line with "return result" and insert before it
        lines = content.split('\n')
        for i in range(len(lines) - 1, -1, -1):
            if 'return result' in lines[i] and 'unload_all_models' not in lines[i]:
                # Check if next non-empty line is except
                j = i + 1
                while j < len(lines) and lines[j].strip() == '':
                    j += 1
                if j < len(lines) and 'except' in lines[j]:
                    indent = len(lines[i]) - len(lines[i].lstrip())
                    indent_str = ' ' * indent
                    memory_lines = [
                        f'{indent_str}# Unload models to CPU (critical for memory management)',
                        f'{indent_str}import comfy.model_management',
                        f'{indent_str}comfy.model_management.unload_all_models()',
                        f'{indent_str}torch.cuda.empty_cache()',
                        ''
                    ]
                    lines[i:i] = memory_lines
                    with open(file_path, 'w') as f:
                        f.write('\n'.join(lines))
                    print(f"  ✓ Fixed {file_path} (fallback method)")
                    sys.exit(0)
        
        print(f"  ✗ Could not find insertion point in {file_path}")
        sys.exit(1)
        
except Exception as e:
    print(f"  ✗ Error fixing {file_path}: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF
    "$file"
    
    return $?
}

echo "=========================================="
echo "Applying Memory Management Fixes"
echo "=========================================="
echo ""

# Fix each service file
fix_service_file "/models/latent_encoder/1/service.py"
fix_service_file "/models/text_encoder/1/service.py"
fix_service_file "/models/sampling/1/service.py"
fix_service_file "/models/decoding/1/service.py"

echo ""

# Fix entrypoint
echo "Checking entrypoint.sh..."
if grep -q "PYTORCH_CUDA_ALLOC_CONF" /workspace/entrypoint.sh 2>/dev/null; then
    echo "✓ PYTORCH_CUDA_ALLOC_CONF is set in entrypoint.sh"
else
    echo "Adding PYTORCH_CUDA_ALLOC_CONF to entrypoint.sh..."
    sed -i '/^exec tritonserver/i\export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True' /workspace/entrypoint.sh
    echo "✓ Fixed entrypoint.sh"
fi

# Set for current session
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
echo "✓ Set PYTORCH_CUDA_ALLOC_CONF for current session"

echo ""
echo "=========================================="
echo "✅ Fixes applied!"
echo "=========================================="
echo ""
echo "⚠ IMPORTANT: Restart Triton for changes to take effect:"
echo "   pkill -f tritonserver"
echo "   sleep 3"
echo "   nohup /workspace/entrypoint.sh > /tmp/triton.log 2>&1 &"
echo "   tail -f /tmp/triton.log"


