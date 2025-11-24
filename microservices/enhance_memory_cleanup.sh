#!/bin/bash
# Enhanced memory cleanup - force PyTorch to release memory
# Run this INSIDE the container

echo "=========================================="
echo "Enhancing Memory Cleanup in All Services"
echo "=========================================="
echo ""

for service in latent_encoder text_encoder sampling decoding; do
    service_file="/models/$service/1/service.py"
    echo "Enhancing cleanup in: $service"
    
    python3 << PYEOF
import sys
file_path = "$service_file"
service_name = "$service"

with open(file_path, 'r') as f:
    content = f.read()

# Find the cleanup section and enhance it
old_cleanup = '''        comfy.model_management.unload_all_models()  # Moves to CPU, removes from GPU tracking (calls soft_empty_cache which includes ipc_collect)
        # Use soft_empty_cache instead of empty_cache - it includes ipc_collect() for multi-process GPU sharing
        comfy.model_management.soft_empty_cache(force=True)  # Force release memory back to CUDA driver
        torch.cuda.synchronize()  # Ensure all CUDA operations complete before cleanup
        gc.collect()  # Force garbage collection to free Python references'''

new_cleanup = '''        # Aggressively unload models and force memory release
        comfy.model_management.unload_all_models()  # Moves to CPU, removes from GPU tracking (calls soft_empty_cache which includes ipc_collect)
        
        # Force PyTorch to release memory back to CUDA driver (critical for multi-process GPU sharing)
        comfy.model_management.soft_empty_cache(force=True)  # Includes ipc_collect() for multi-process scenarios
        torch.cuda.synchronize()  # Ensure all CUDA operations complete
        
        # Multiple empty_cache calls to force allocator to release memory
        for _ in range(3):
            torch.cuda.empty_cache()
            torch.cuda.ipc_collect()
            torch.cuda.synchronize()
        
        # Force garbage collection multiple times to clear Python references
        import gc
        for _ in range(3):
            gc.collect()
        
        # Final memory release
        comfy.model_management.soft_empty_cache(force=True)
        torch.cuda.synchronize()'''

if old_cleanup in content:
    content = content.replace(old_cleanup, new_cleanup)
    with open(file_path, 'w') as f:
        f.write(content)
    print(f"  ✓ Enhanced cleanup in {service_name}")
else:
    if 'soft_empty_cache' in content:
        print(f"  ⚠ {service_name} has cleanup but pattern doesn't match - manual check needed")
    else:
        print(f"  ❌ {service_name} missing cleanup code")

PYEOF
done

echo ""
echo "=== Verifying enhanced cleanup ==="
for service in latent_encoder text_encoder sampling decoding; do
    if grep -q "for _ in range(3)" /models/$service/1/service.py; then
        echo "✓ $service has enhanced cleanup"
    else
        echo "❌ $service missing enhanced cleanup"
    fi
done

echo ""
echo "=========================================="
echo "Enhanced cleanup applied!"
echo "=========================================="
echo ""
echo "⚠️  IMPORTANT: This is a workaround for PyTorch's CUDA allocator behavior."
echo "   PyTorch keeps memory reserved even after ipc_collect() to avoid"
echo "   allocation overhead. Multiple cleanup calls may help, but there's"
echo "   no guarantee it will fully release memory."
echo ""
echo "Next steps:"
echo "1. Restart Triton: pkill -f tritonserver && sleep 3 && /workspace/entrypoint.sh > /tmp/triton.log 2>&1 &"
echo "2. Test inference request"
echo "3. Monitor GPU memory: watch -n 1 nvidia-smi"


