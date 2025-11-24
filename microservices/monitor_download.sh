#!/bin/bash

# Quick Model Download Monitor Script
# Run this inside the container to monitor download progress

MODELS_DIR="${MODEL_DIR:-/workspace/shared_models}"

echo "=========================================="
echo "MODEL DOWNLOAD MONITOR"
echo "=========================================="
echo ""

# Check if download is running
echo "📥 Active Downloads:"
if ps aux | grep -E "(wget|curl)" | grep -v grep > /dev/null; then
    echo "   ✓ Download in progress"
    ps aux | grep -E "(wget|curl)" | grep -v grep | awk '{print "   PID:", $2, "→", $11, $12, $13}'
else
    echo "   ✗ No active downloads"
fi
echo ""

# Check each model file
echo "📦 Model Files:"
declare -A EXPECTED_SIZES=(
    ["vae/qwen_image_vae.safetensors"]=500
    ["clip/qwen_2.5_vl_7b_fp8_scaled.safetensors"]=7000
    ["diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors"]=3000
    ["loras/Qwen-Image-Lightning-4steps-V2.0.safetensors"]=100
)

TOTAL_EXPECTED=10600
TOTAL_DOWNLOADED=0
COMPLETE_COUNT=0

for model_path in "${!EXPECTED_SIZES[@]}"; do
    full_path="${MODELS_DIR}/${model_path}"
    expected_mb="${EXPECTED_SIZES[$model_path]}"
    
    if [ -f "$full_path" ]; then
        size=$(stat -c%s "$full_path" 2>/dev/null || stat -f%z "$full_path" 2>/dev/null || echo "0")
        size_mb=$((size / 1024 / 1024))
        percent=$((size_mb * 100 / expected_mb))
        TOTAL_DOWNLOADED=$((TOTAL_DOWNLOADED + size_mb))
        
        if [ "$size_mb" -ge "$expected_mb" ]; then
            echo "   ✓ $(basename "$full_path"): ${size_mb} MB (100%)"
            COMPLETE_COUNT=$((COMPLETE_COUNT + 1))
        else
            # Show progress bar
            bar_length=20
            filled=$((percent * bar_length / 100))
            bar=$(printf "%*s" $filled | tr ' ' '█')
            empty=$(printf "%*s" $((bar_length - filled)) | tr ' ' '░')
            echo "   ⏳ $(basename "$full_path"): ${size_mb}/${expected_mb} MB [${bar}${empty}] ${percent}%"
        fi
    else
        echo "   ✗ $(basename "$full_path"): Not started"
    fi
done
echo ""

# Overall progress
OVERALL_PERCENT=$((TOTAL_DOWNLOADED * 100 / TOTAL_EXPECTED))
echo "📊 Overall Progress: ${TOTAL_DOWNLOADED}/${TOTAL_EXPECTED} MB (${OVERALL_PERCENT}%)"
echo "   Completed: ${COMPLETE_COUNT}/4 models"
echo ""

# Disk space
echo "💾 Disk Space:"
df -h /workspace | tail -1 | awk '{print "   Available:", $4, "| Used:", $3, "| Total:", $2}'
echo ""

# Status summary
if [ "$COMPLETE_COUNT" -eq 4 ]; then
    echo "✅ All models downloaded successfully!"
elif [ "$COMPLETE_COUNT" -gt 0 ]; then
    echo "⏳ Download in progress... (${COMPLETE_COUNT}/4 complete)"
else
    echo "⏸️  No downloads started yet"
fi
echo ""


