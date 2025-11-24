#!/bin/bash
# Quick check and fix for memory management
# Run inside container

echo "=========================================="
echo "Memory Management Status Check"
echo "=========================================="

# Check if fixes are applied
echo "1. Checking service files:"
for file in /models/latent_encoder/1/service.py /models/text_encoder/1/service.py /models/sampling/1/service.py /models/decoding/1/service.py; do
    if [ -f "$file" ]; then
        if grep -q "unload_all_models" "$file"; then
            echo "  ✓ $(basename $(dirname $(dirname $file))): Memory management OK"
        else
            echo "  ✗ $(basename $(dirname $(dirname $file))): Memory management MISSING"
        fi
    else
        echo "  ✗ File not found: $file"
    fi
done

echo ""
echo "2. Checking entrypoint:"
if grep -q "PYTORCH_CUDA_ALLOC_CONF" /workspace/entrypoint.sh 2>/dev/null; then
    echo "  ✓ PYTORCH_CUDA_ALLOC_CONF is set"
else
    echo "  ✗ PYTORCH_CUDA_ALLOC_CONF is NOT set"
fi

echo ""
echo "3. Current GPU memory:"
nvidia-smi --query-gpu=memory.used,memory.total --format=csv 2>/dev/null || echo "  (nvidia-smi not available)"

echo ""
echo "=========================================="
echo "If fixes are missing, they need to be applied"
echo "See: CONTAINER_FIX_COMMANDS.md"
echo "=========================================="


