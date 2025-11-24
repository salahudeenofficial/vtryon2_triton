#!/bin/bash
# Apply memory management fixes inside container
# Run this ENTIRE script inside the container

echo "=========================================="
echo "Applying Memory Management Fixes"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Function to add memory management before return
fix_service_file() {
    local file=$1
    local service_name=$2
    
    if [ ! -f "$file" ]; then
        echo -e "  ${RED}✗ File not found: $file${NC}"
        return 1
    fi
    
    # Check if already fixed
    if grep -q "unload_all_models" "$file"; then
        echo -e "  ${GREEN}✓ $service_name: Already has memory management${NC}"
        return 0
    fi
    
    echo -e "  ${YELLOW}→ Fixing $service_name...${NC}"
    
    # Use Python to safely insert the memory management code
    python3 << PYEOF
import sys
import re

file_path = sys.argv[1]

try:
    with open(file_path, 'r') as f:
        lines = f.readlines()
    
    # Find the return result statement before except Exception
    fixed = False
    for i in range(len(lines) - 1, -1, -1):
        if 'return result' in lines[i] and 'unload_all_models' not in lines[i]:
            # Check if next non-empty line is except Exception
            j = i + 1
            while j < len(lines) and lines[j].strip() == '':
                j += 1
            if j < len(lines) and 'except Exception' in lines[j]:
                # Found the right place - insert memory management before return
                indent = len(lines[i]) - len(lines[i].lstrip())
                memory_code = f'''        # Unload models to CPU (critical for memory management)
        # unload_all_models() moves models from GPU to CPU (offload_device) via detach()
        # Models stay in CPU memory, ready for next request
        import comfy.model_management
        comfy.model_management.unload_all_models()  # Moves to CPU, removes from GPU tracking
        torch.cuda.empty_cache()  # Clear GPU cache
'''
                # Insert with proper indentation
                indent_str = ' ' * indent
                memory_lines = [indent_str + line if line.strip() else line for line in memory_code.split('\n')]
                lines[i:i] = memory_lines
                fixed = True
                break
    
    if fixed:
        with open(file_path, 'w') as f:
            f.writelines(lines)
        print(f"  ✓ Fixed {file_path}")
        sys.exit(0)
    else:
        print(f"  ✗ Could not find insertion point in {file_path}")
        sys.exit(1)
        
except Exception as e:
    print(f"  ✗ Error fixing {file_path}: {e}")
    sys.exit(1)
PYEOF
    "$file"
    
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓ $service_name: Fixed${NC}"
    else
        echo -e "  ${RED}✗ $service_name: Failed to fix${NC}"
    fi
}

# Function to wrap service logic in torch.inference_mode()
add_inference_mode() {
    local file=$1
    local service_name=$2
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    # Check if already has inference_mode
    if grep -q "with torch.inference_mode():" "$file"; then
        echo -e "  ${GREEN}✓ $service_name: Already has inference_mode${NC}"
        return 0
    fi
    
    echo -e "  ${YELLOW}→ Adding inference_mode to $service_name...${NC}"
    
    # This is more complex - we'll skip it for now and focus on memory management
    # The inference_mode is less critical than unload_all_models
    echo -e "  ${YELLOW}  (Skipping inference_mode - less critical)${NC}"
}

# Step 1: Fix service files
echo "Step 1: Fixing service files..."
echo ""

fix_service_file "/models/latent_encoder/1/service.py" "latent_encoder"
fix_service_file "/models/text_encoder/1/service.py" "text_encoder"
fix_service_file "/models/sampling/1/service.py" "sampling"
fix_service_file "/models/decoding/1/service.py" "decoding"

echo ""

# Step 2: Check entrypoint
echo "Step 2: Checking entrypoint.sh..."
if grep -q "PYTORCH_CUDA_ALLOC_CONF" /workspace/entrypoint.sh 2>/dev/null; then
    echo -e "  ${GREEN}✓ PYTORCH_CUDA_ALLOC_CONF is set in entrypoint.sh${NC}"
else
    echo -e "  ${YELLOW}→ Adding PYTORCH_CUDA_ALLOC_CONF to entrypoint.sh...${NC}"
    if [ -f /workspace/entrypoint.sh ]; then
        # Add before exec tritonserver
        sed -i '/^exec tritonserver/i\export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True' /workspace/entrypoint.sh
        echo -e "  ${GREEN}✓ Added PYTORCH_CUDA_ALLOC_CONF${NC}"
    else
        echo -e "  ${RED}✗ entrypoint.sh not found${NC}"
    fi
fi

echo ""

# Step 3: Set for current session
echo "Step 3: Setting environment variable for current session..."
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
echo -e "  ${GREEN}✓ PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True${NC}"

echo ""
echo "=========================================="
echo "Fixes Applied!"
echo "=========================================="
echo ""
echo -e "${YELLOW}⚠ IMPORTANT: You must RESTART Triton for changes to take effect${NC}"
echo ""
echo "To restart Triton:"
echo "  1. Stop: pkill -f tritonserver"
echo "  2. Wait: sleep 3"
echo "  3. Start: nohup /workspace/entrypoint.sh > /tmp/triton.log 2>&1 &"
echo "  4. Monitor: tail -f /tmp/triton.log"
echo ""


