#!/bin/bash
# Simple script to fix memory management in running Triton container
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

# Function to add unload code to a service file
fix_service_file() {
    local file=$1
    local service_name=$2
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗ File not found: $file${NC}"
        return 1
    fi
    
    # Check if already fixed
    if grep -q "unload_all_models()" "$file"; then
        echo -e "${YELLOW}⚠ $service_name already has unload_all_models()${NC}"
        return 0
    fi
    
    echo -e "${BLUE}Fixing $service_name...${NC}"
    
    # Create a Python script to do the insertion
    python3 << PYEOF
import sys
import re

file_path = sys.argv[1]

with open(file_path, 'r') as f:
    lines = f.readlines()

# Find the last 'return result' before 'except Exception'
insert_idx = None
for i in range(len(lines) - 1, -1, -1):
    if 'except Exception' in lines[i] or 'except Exception as' in lines[i]:
        # Look backwards for 'return result'
        for j in range(i - 1, max(0, i - 50), -1):
            if 'return result' in lines[j] and 'Unload models' not in ''.join(lines[max(0, j-10):j]):
                insert_idx = j
                break
        break

if insert_idx is None:
    # Try finding just 'return result' near the end
    for i in range(len(lines) - 1, max(0, len(lines) - 30), -1):
        if 'return result' in lines[i] and 'Unload models' not in ''.join(lines[max(0, i-10):i]):
            insert_idx = i
            break

if insert_idx is None:
    print(f"ERROR: Could not find insertion point in {file_path}")
    sys.exit(1)

# Get indentation from return line
indent = len(lines[insert_idx]) - len(lines[insert_idx].lstrip())

# Unload code with proper indentation
unload_code = f'''        # Unload models to CPU (critical for memory management)
        # unload_all_models() moves models from GPU to CPU (offload_device) via detach()
        # Models stay in CPU memory, ready for next request
        import comfy.model_management
        comfy.model_management.unload_all_models()  # Moves to CPU, removes from GPU tracking
        torch.cuda.empty_cache()  # Clear GPU cache
'''

# Indent each line
unload_lines = []
for line in unload_code.split('\n'):
    if line.strip():
        unload_lines.append(' ' * indent + line + '\n')
    else:
        unload_lines.append('\n')

# Insert before return
lines[insert_idx:insert_idx] = unload_lines

with open(file_path, 'w') as f:
    f.writelines(lines)

print("OK")
PYEOF
"$file"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Fixed $service_name${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to fix $service_name${NC}"
        return 1
    fi
}

# Step 1: Fix service files
echo "=========================================="
echo "Step 1: Adding Model Unloading to Services"
echo "=========================================="
echo ""

fix_service_file "/models/latent_encoder/1/service.py" "latent_encoder"
fix_service_file "/models/text_encoder/1/service.py" "text_encoder"
fix_service_file "/models/sampling/1/service.py" "sampling"
fix_service_file "/models/decoding/1/service.py" "decoding"

echo ""

# Step 2: Add to entrypoint.sh
echo "=========================================="
echo "Step 2: Adding PyTorch Memory Optimization"
echo "=========================================="
echo ""

ENTRYPOINT="/workspace/entrypoint.sh"
if [ -f "$ENTRYPOINT" ]; then
    if ! grep -q "PYTORCH_CUDA_ALLOC_CONF" "$ENTRYPOINT"; then
        # Find the line with "exec tritonserver" and add before it
        sed -i '/^exec tritonserver/i\# Set PyTorch memory optimization to reduce fragmentation\nexport PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True\necho "✓ Set PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True for memory optimization"\necho ""' "$ENTRYPOINT"
        echo -e "${GREEN}✓ Updated entrypoint.sh${NC}"
    else
        echo -e "${YELLOW}⚠ entrypoint.sh already has PYTORCH_CUDA_ALLOC_CONF${NC}"
    fi
else
    echo -e "${YELLOW}⚠ entrypoint.sh not found${NC}"
fi

echo ""

# Step 3: Set for current session
echo "=========================================="
echo "Step 3: Setting Environment Variable"
echo "=========================================="
echo ""

export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
echo -e "${GREEN}✓ Set PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True (current session)${NC}"
echo ""

# Step 4: Verify
echo "=========================================="
echo "Step 4: Verification"
echo "=========================================="
echo ""

echo "Service files with unload_all_models():"
grep -l "unload_all_models()" /models/*/1/service.py 2>/dev/null | while read f; do
    echo -e "  ${GREEN}✓${NC} $(basename $(dirname $(dirname $f)))"
done || echo -e "  ${RED}✗ No files found${NC}"

echo ""
echo "Environment variable:"
if [ -n "$PYTORCH_CUDA_ALLOC_CONF" ]; then
    echo -e "  ${GREEN}✓${NC} $PYTORCH_CUDA_ALLOC_CONF"
else
    echo -e "  ${RED}✗ Not set${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✅ All Fixes Applied!${NC}"
echo "=========================================="
echo ""
echo "IMPORTANT: Restart the container for changes to take effect"
echo ""


