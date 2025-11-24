#!/bin/bash
# Quick fix script - copy this entire block and paste into container

# Fix all services at once
for file in /models/latent_encoder/1/service.py /models/text_encoder/1/service.py /models/sampling/1/service.py /models/decoding/1/service.py; do
    [ -f "$file" ] && ! grep -q "unload_all_models()" "$file" && python3 << PYEOF
import sys
f = sys.argv[1]
with open(f, 'r') as file:
    lines = file.readlines()
for i in range(len(lines)-1, -1, -1):
    if 'except Exception' in lines[i]:
        for j in range(i-1, max(0, i-30), -1):
            if 'return result' in lines[j] and 'unload_all_models' not in lines[j]:
                indent = len(lines[j]) - len(lines[j].lstrip())
                code = f'''        # Unload models to CPU
        import comfy.model_management
        comfy.model_management.unload_all_models()
        torch.cuda.empty_cache()
'''
                lines.insert(j, '\n'.join([' ' * indent + l for l in code.split('\n')]))
                with open(f, 'w') as file:
                    file.writelines(lines)
                print(f"✓ Fixed {f}")
                sys.exit(0)
        break
PYEOF
"$file"
done

# Add to entrypoint
[ -f /workspace/entrypoint.sh ] && ! grep -q "PYTORCH_CUDA_ALLOC_CONF" /workspace/entrypoint.sh && \
    sed -i '/^exec tritonserver/i\export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True' /workspace/entrypoint.sh && \
    echo "✓ Updated entrypoint.sh"

# Set for session
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
echo "✓ Done! Restart container to apply changes."
