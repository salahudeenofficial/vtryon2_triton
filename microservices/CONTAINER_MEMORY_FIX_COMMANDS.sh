#!/bin/bash
# Commands to fix memory management INSIDE the container
# Copy and paste these commands into the container terminal

echo "=========================================="
echo "MEMORY MANAGEMENT FIX - CONTAINER COMMANDS"
echo "=========================================="
echo ""
echo "Run these commands INSIDE the container:"
echo ""

cat << 'COMMANDS'

# ==========================================
# OPTION 1: Quick Fix (Recommended)
# ==========================================

# Fix all service files at once
for file in /models/latent_encoder/1/service.py /models/text_encoder/1/service.py /models/sampling/1/service.py /models/decoding/1/service.py; do
    if [ -f "$file" ] && ! grep -q "unload_all_models()" "$file"; then
        python3 << PYEOF
import sys
file_path = sys.argv[1]
with open(file_path, 'r') as f:
    lines = f.readlines()

# Find last 'return result' before 'except'
insert_idx = None
for i in range(len(lines)-1, -1, -1):
    if 'except Exception' in lines[i] or 'except Exception as' in lines[i]:
        for j in range(i-1, max(0, i-30), -1):
            if 'return result' in lines[j] and 'unload_all_models' not in lines[j]:
                insert_idx = j
                break
        break

if insert_idx:
    indent = len(lines[insert_idx]) - len(lines[insert_idx].lstrip())
    unload = f'''        # Unload models to CPU (critical for memory management)
        import comfy.model_management
        comfy.model_management.unload_all_models()  # Moves to CPU
        torch.cuda.empty_cache()  # Clear GPU cache
'''
    unload_lines = [' ' * indent + l + '\n' if l.strip() else '\n' for l in unload.split('\n')]
    lines[insert_idx:insert_idx] = unload_lines
    with open(file_path, 'w') as f:
        f.writelines(lines)
    print(f"Fixed: {file_path}")
else:
    print(f"Could not find insertion point in {file_path}")
PYEOF
"$file"
    fi
done

# Add to entrypoint.sh
if [ -f /workspace/entrypoint.sh ] && ! grep -q "PYTORCH_CUDA_ALLOC_CONF" /workspace/entrypoint.sh; then
    sed -i '/^exec tritonserver/i\# Set PyTorch memory optimization\nexport PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True\necho "✓ Set PYTORCH_CUDA_ALLOC_CONF for memory optimization"\necho ""' /workspace/entrypoint.sh
    echo "✓ Updated entrypoint.sh"
fi

# Set for current session
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
echo "✓ Set PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True"

# ==========================================
# OPTION 2: Manual Fix (One by One)
# ==========================================

# Fix latent_encoder
python3 << 'PYEOF'
file_path = "/models/latent_encoder/1/service.py"
with open(file_path, 'r') as f:
    content = f.read()
if "unload_all_models()" not in content:
    lines = content.split('\n')
    for i in range(len(lines)-1, -1, -1):
        if 'except Exception' in lines[i]:
            for j in range(i-1, max(0, i-30), -1):
                if 'return result' in lines[j]:
                    indent = len(lines[j]) - len(lines[j].lstrip())
                    unload = f'''        # Unload models to CPU
        import comfy.model_management
        comfy.model_management.unload_all_models()
        torch.cuda.empty_cache()
'''
                    lines.insert(j, '\n'.join([' ' * indent + l for l in unload.split('\n')]))
                    with open(file_path, 'w') as f:
                        f.write('\n'.join(lines))
                    print("✓ Fixed latent_encoder")
                    break
            break
else:
    print("⚠ latent_encoder already fixed")
PYEOF

# Fix text_encoder
python3 << 'PYEOF'
file_path = "/models/text_encoder/1/service.py"
with open(file_path, 'r') as f:
    content = f.read()
if "unload_all_models()" not in content:
    lines = content.split('\n')
    for i in range(len(lines)-1, -1, -1):
        if 'except Exception' in lines[i]:
            for j in range(i-1, max(0, i-30), -1):
                if 'return result' in lines[j]:
                    indent = len(lines[j]) - len(lines[j].lstrip())
                    unload = f'''        # Unload models to CPU
        import comfy.model_management
        comfy.model_management.unload_all_models()
        torch.cuda.empty_cache()
'''
                    lines.insert(j, '\n'.join([' ' * indent + l for l in unload.split('\n')]))
                    with open(file_path, 'w') as f:
                        f.write('\n'.join(lines))
                    print("✓ Fixed text_encoder")
                    break
            break
else:
    print("⚠ text_encoder already fixed")
PYEOF

# Fix sampling
python3 << 'PYEOF'
file_path = "/models/sampling/1/service.py"
with open(file_path, 'r') as f:
    content = f.read()
if "unload_all_models()" not in content:
    lines = content.split('\n')
    for i in range(len(lines)-1, -1, -1):
        if 'except Exception' in lines[i]:
            for j in range(i-1, max(0, i-30), -1):
                if 'return result' in lines[j]:
                    indent = len(lines[j]) - len(lines[j].lstrip())
                    unload = f'''        # Unload models to CPU
        import comfy.model_management
        comfy.model_management.unload_all_models()
        torch.cuda.empty_cache()
'''
                    lines.insert(j, '\n'.join([' ' * indent + l for l in unload.split('\n')]))
                    with open(file_path, 'w') as f:
                        f.write('\n'.join(lines))
                    print("✓ Fixed sampling")
                    break
            break
else:
    print("⚠ sampling already fixed")
PYEOF

# Fix decoding
python3 << 'PYEOF'
file_path = "/models/decoding/1/service.py"
with open(file_path, 'r') as f:
    content = f.read()
if "unload_all_models()" not in content:
    lines = content.split('\n')
    for i in range(len(lines)-1, -1, -1):
        if 'except Exception' in lines[i]:
            for j in range(i-1, max(0, i-30), -1):
                if 'return result' in lines[j]:
                    indent = len(lines[j]) - len(lines[j].lstrip())
                    unload = f'''        # Unload models to CPU
        import comfy.model_management
        comfy.model_management.unload_all_models()
        torch.cuda.empty_cache()
'''
                    lines.insert(j, '\n'.join([' ' * indent + l for l in unload.split('\n')]))
                    with open(file_path, 'w') as f:
                        f.write('\n'.join(lines))
                    print("✓ Fixed decoding")
                    break
            break
else:
    print("⚠ decoding already fixed")
PYEOF

# ==========================================
# OPTION 3: Verify Fixes
# ==========================================

echo ""
echo "Verifying fixes:"
echo "=================="
for file in /models/latent_encoder/1/service.py /models/text_encoder/1/service.py /models/sampling/1/service.py /models/decoding/1/service.py; do
    if grep -q "unload_all_models()" "$file" 2>/dev/null; then
        echo "✓ $(basename $(dirname $(dirname $file)))"
    else
        echo "✗ $(basename $(dirname $(dirname $file)))"
    fi
done

echo ""
echo "Environment variable:"
if [ -n "$PYTORCH_CUDA_ALLOC_CONF" ]; then
    echo "✓ PYTORCH_CUDA_ALLOC_CONF=$PYTORCH_CUDA_ALLOC_CONF"
else
    echo "✗ Not set (run: export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True)"
fi

COMMANDS

echo ""
echo "=========================================="
echo "After running these commands:"
echo "=========================================="
echo "1. Restart the container for changes to take effect"
echo "2. Or restart Triton server if possible"
echo "3. Test inference - should use much less memory"
echo ""


