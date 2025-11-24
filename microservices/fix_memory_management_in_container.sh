#!/bin/bash
# Script to fix memory management in running Triton container
# Run this INSIDE the container

set -e

echo "=========================================="
echo "Fixing Memory Management in Container"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Define the model unloading code
UNLOAD_CODE='        # Unload models to CPU (critical for memory management)
        # unload_all_models() moves models from GPU to CPU (offload_device) via detach()
        # Models stay in CPU memory, ready for next request
        import comfy.model_management
        comfy.model_management.unload_all_models()  # Moves to CPU, removes from GPU tracking
        torch.cuda.empty_cache()  # Clear GPU cache
'

# Function to add unloading code before return statement
add_unload_code() {
    local file=$1
    local service_name=$2
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗ File not found: $file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Updating $service_name...${NC}"
    
    # Check if already updated
    if grep -q "unload_all_models()" "$file"; then
        echo -e "${YELLOW}⚠ Already has unload_all_models(), skipping...${NC}"
        return 0
    fi
    
    # Find the return statement before the except block
    # We need to add the code before the final return in the try block
    if python3 << 'PYEOF'
import sys
file_path = sys.argv[1]
with open(file_path, 'r') as f:
    lines = f.readlines()
    
# Find the last return statement in the try block (before except)
try_start = None
except_start = None
for i, line in enumerate(lines):
    if 'try:' in line or 'try ' in line:
        try_start = i
    if 'except' in line and try_start is not None:
        except_start = i
        break

if try_start is None or except_start is None:
    print("ERROR: Could not find try/except block")
    sys.exit(1)

# Find return statement before except
return_idx = None
for i in range(except_start - 1, try_start, -1):
    if 'return result' in lines[i] or 'return {' in lines[i]:
        return_idx = i
        break

if return_idx is None:
    print("ERROR: Could not find return statement")
    sys.exit(1)

print(return_idx)
PYEOF
"$file" > /tmp/return_idx.txt 2>&1; then
        RETURN_IDX=$(cat /tmp/return_idx.txt)
        if [ -z "$RETURN_IDX" ] || [ "$RETURN_IDX" = "ERROR"* ]; then
            echo -e "${YELLOW}⚠ Could not auto-find return statement, using manual method...${NC}"
            # Manual method: add before last return in try block
            python3 << PYEOF
import sys
file_path = sys.argv[1]
unload_code = sys.argv[2]

with open(file_path, 'r') as f:
    content = f.read()

# Find the pattern: return result (before except)
# Add unload code before the return
if 'return result' in content:
    # Find the last 'return result' before 'except'
    lines = content.split('\n')
    for i in range(len(lines) - 1, -1, -1):
        if 'except' in lines[i]:
            # Look backwards for return result
            for j in range(i - 1, -1, -1):
                if 'return result' in lines[j] and 'Unload models' not in lines[j-5:j] if j >= 5 else True:
                    # Insert unload code before this line
                    indent = len(lines[j]) - len(lines[j].lstrip())
                    unload_lines = unload_code.split('\n')
                    indent_str = ' ' * indent
                    unload_indented = '\n'.join([indent_str + line if line.strip() else '' for line in unload_lines])
                    lines.insert(j, unload_indented)
                    break
            break
    
    with open(file_path, 'w') as f:
        f.write('\n'.join(lines))
    print("OK")
else:
    print("ERROR: Could not find return result")
    sys.exit(1)
PYEOF
"$file" "$UNLOAD_CODE" || {
                echo -e "${RED}✗ Failed to update $file${NC}"
                return 1
            }
        else
            # Use the found index
            python3 << PYEOF
import sys
file_path = sys.argv[1]
return_idx = int(sys.argv[2])
unload_code = sys.argv[3]

with open(file_path, 'r') as f:
    lines = f.readlines()

# Get indentation from return line
return_line = lines[return_idx]
indent = len(return_line) - len(return_line.lstrip())

# Prepare unload code with proper indentation
unload_lines = unload_code.split('\n')
unload_indented = []
for line in unload_lines:
    if line.strip():
        unload_indented.append(' ' * indent + line)
    else:
        unload_indented.append('')

# Insert before return
lines[return_idx:return_idx] = [line + '\n' for line in unload_indented]

with open(file_path, 'w') as f:
    f.writelines(lines)
print("OK")
PYEOF
"$file" "$RETURN_IDX" "$UNLOAD_CODE" || {
                echo -e "${RED}✗ Failed to update $file${NC}"
                return 1
            }
        fi
    else
        echo -e "${YELLOW}⚠ Using simple append method...${NC}"
        # Simple method: find "return result" and add before it
        python3 << PYEOF
import sys
import re

file_path = sys.argv[1]
unload_code = sys.argv[2]

with open(file_path, 'r') as f:
    content = f.read()

# Find the last 'return result' before 'except'
pattern = r'(        result\[.*?\].*?\n)(        \n        return result)'
replacement = r'\1' + unload_code + r'\n\2'

new_content = re.sub(pattern, replacement, content, count=1)

if new_content != content:
    with open(file_path, 'w') as f:
        f.write(new_content)
    print("OK")
else:
    # Try alternative pattern
    pattern2 = r'(\n        result\[.*?\].*?\n)(        return result)'
    new_content = re.sub(pattern2, r'\1' + unload_code + r'\n\2', content, count=1)
    if new_content != content:
        with open(file_path, 'w') as f:
            f.write(new_content)
        print("OK")
    else:
        print("ERROR: Could not find insertion point")
        sys.exit(1)
PYEOF
"$file" "$UNLOAD_CODE" || {
            echo -e "${RED}✗ Failed to update $file${NC}"
            return 1
        }
    fi
    
    echo -e "${GREEN}✓ Updated $service_name${NC}"
    return 0
}

# Update all service files
echo "=========================================="
echo "Step 1: Updating Service Files"
echo "=========================================="
echo ""

SERVICES=(
    "/models/latent_encoder/1/service.py:latent_encoder"
    "/models/text_encoder/1/service.py:text_encoder"
    "/models/sampling/1/service.py:sampling"
    "/models/decoding/1/service.py:decoding"
)

UPDATED=0
FAILED=0

for service_info in "${SERVICES[@]}"; do
    IFS=':' read -r file service_name <<< "$service_info"
    if add_unload_code "$file" "$service_name"; then
        UPDATED=$((UPDATED + 1))
    else
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "Updated: $UPDATED, Failed: $FAILED"
echo ""

# Step 2: Add PyTorch memory optimization to entrypoint
echo "=========================================="
echo "Step 2: Adding PyTorch Memory Optimization"
echo "=========================================="
echo ""

ENTRYPOINT="/workspace/entrypoint.sh"
if [ -f "$ENTRYPOINT" ]; then
    if ! grep -q "PYTORCH_CUDA_ALLOC_CONF" "$ENTRYPOINT"; then
        # Add before exec tritonserver
        sed -i '/exec tritonserver/i\# Set PyTorch memory optimization to reduce fragmentation\nexport PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True\necho "✓ Set PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True for memory optimization"\necho ""' "$ENTRYPOINT"
        echo -e "${GREEN}✓ Updated entrypoint.sh${NC}"
    else
        echo -e "${YELLOW}⚠ entrypoint.sh already has PYTORCH_CUDA_ALLOC_CONF${NC}"
    fi
else
    echo -e "${YELLOW}⚠ entrypoint.sh not found at $ENTRYPOINT${NC}"
fi

echo ""

# Step 3: Set environment variable for current session
echo "=========================================="
echo "Step 3: Setting Environment Variable (Current Session)"
echo "=========================================="
echo ""

export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
echo -e "${GREEN}✓ Set PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True${NC}"
echo ""

# Step 4: Verify changes
echo "=========================================="
echo "Step 4: Verifying Changes"
echo "=========================================="
echo ""

echo "Checking service files for unload_all_models():"
for service_info in "${SERVICES[@]}"; do
    IFS=':' read -r file service_name <<< "$service_info"
    if grep -q "unload_all_models()" "$file" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $service_name"
    else
        echo -e "  ${RED}✗${NC} $service_name"
    fi
done

echo ""
echo "Checking environment variable:"
if [ -n "$PYTORCH_CUDA_ALLOC_CONF" ]; then
    echo -e "  ${GREEN}✓${NC} PYTORCH_CUDA_ALLOC_CONF=$PYTORCH_CUDA_ALLOC_CONF"
else
    echo -e "  ${RED}✗${NC} PYTORCH_CUDA_ALLOC_CONF not set"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Memory Management Fixes Applied!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Restart the container for changes to take effect"
echo "2. Or restart Triton server if possible"
echo "3. Test inference - should use much less memory"
echo ""


