# Monitor Model Download Progress

This guide provides commands to monitor model download progress inside the container.

## Quick Status Check

### 1. Check if Download is Running

```bash
# Check for active wget/curl processes
ps aux | grep -E "(wget|curl)" | grep -v grep

# More detailed view
ps aux | grep -E "(wget|curl)" | grep -v grep | awk '{print $2, $11, $12, $13}'
```

### 2. Check Current File Sizes

```bash
# Check all model files and their sizes
ls -lh /workspace/shared_models/vae/
ls -lh /workspace/shared_models/clip/
ls -lh /workspace/shared_models/diffusion_models/
ls -lh /workspace/shared_models/loras/

# Or in one command
du -sh /workspace/shared_models/*/*.safetensors 2>/dev/null
```

### 3. Check Expected vs Actual Sizes

```bash
# Expected sizes:
# VAE: ~500 MB
# CLIP: ~7 GB (7000 MB)
# UNET: ~3 GB (3000 MB)
# LoRA: ~100 MB

# Check actual sizes in MB
for file in /workspace/shared_models/vae/*.safetensors \
            /workspace/shared_models/clip/*.safetensors \
            /workspace/shared_models/diffusion_models/*.safetensors \
            /workspace/shared_models/loras/*.safetensors; do
    if [ -f "$file" ]; then
        size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
        size_mb=$((size / 1024 / 1024))
        echo "$(basename "$file"): ${size_mb} MB"
    fi
done
```

## Real-Time Monitoring

### 4. Watch File Sizes Grow (Live Updates)

```bash
# Watch file sizes update every 2 seconds
watch -n 2 'du -sh /workspace/shared_models/*/*.safetensors 2>/dev/null | sort -h'

# Or with more details
watch -n 2 'for dir in /workspace/shared_models/*/; do echo "$dir:"; ls -lh "$dir"/*.safetensors 2>/dev/null | awk "{print \$5, \$9}"; echo ""; done'
```

### 5. Monitor Download Progress with Progress Bar

If `wget` is being used, you can check its progress:

```bash
# Find wget process and check its output
ps aux | grep wget | grep -v grep

# If running in background, check logs
tail -f /tmp/download.log 2>/dev/null

# Or check if download script is running
ps aux | grep download_triton_models.sh | grep -v grep
```

### 6. Monitor Network Activity

```bash
# Check network I/O (if iftop/nethogs available)
# Or use iostat for disk I/O
iostat -x 1 5

# Check disk write activity
iotop -o -d 1
```

## Comprehensive Status Check

### 7. Complete Status Script

Run this inside the container for a complete status:

```bash
cat << 'EOF' > /tmp/check_download_status.sh
#!/bin/bash

echo "=========================================="
echo "MODEL DOWNLOAD STATUS CHECK"
echo "=========================================="
echo ""

# Check if download is running
echo "1. Active Downloads:"
if ps aux | grep -E "(wget|curl)" | grep -v grep > /dev/null; then
    echo "   ✓ Download in progress"
    ps aux | grep -E "(wget|curl)" | grep -v grep | awk '{print "   PID:", $2, "CMD:", $11, $12, $13}'
else
    echo "   ✗ No active downloads"
fi
echo ""

# Check model files
echo "2. Model Files Status:"
MODELS_DIR="${MODEL_DIR:-/workspace/shared_models}"

declare -A EXPECTED_SIZES=(
    ["vae/qwen_image_vae.safetensors"]=500
    ["clip/qwen_2.5_vl_7b_fp8_scaled.safetensors"]=7000
    ["diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors"]=3000
    ["loras/Qwen-Image-Lightning-4steps-V2.0.safetensors"]=100
)

for model_path in "${!EXPECTED_SIZES[@]}"; do
    full_path="${MODELS_DIR}/${model_path}"
    expected_mb="${EXPECTED_SIZES[$model_path]}"
    
    if [ -f "$full_path" ]; then
        size=$(stat -c%s "$full_path" 2>/dev/null || stat -f%z "$full_path" 2>/dev/null || echo "0")
        size_mb=$((size / 1024 / 1024))
        percent=$((size_mb * 100 / expected_mb))
        
        if [ "$size_mb" -ge "$expected_mb" ]; then
            echo "   ✓ $(basename "$full_path"): ${size_mb} MB (100%)"
        else
            echo "   ⏳ $(basename "$full_path"): ${size_mb} MB (${percent}%)"
        fi
    else
        echo "   ✗ $(basename "$full_path"): Not found"
    fi
done
echo ""

# Check disk space
echo "3. Disk Space:"
df -h /workspace | tail -1 | awk '{print "   Available:", $4, "Used:", $3, "Total:", $2}'
echo ""

# Check total downloaded size
echo "4. Total Downloaded:"
total_size=$(du -sb "$MODELS_DIR" 2>/dev/null | awk '{print $1}')
total_mb=$((total_size / 1024 / 1024))
echo "   ${total_mb} MB"
echo ""

echo "=========================================="
EOF

chmod +x /tmp/check_download_status.sh
/tmp/check_download_status.sh
```

### 8. Continuous Monitoring (Refresh Every 5 Seconds)

```bash
# Run status check in a loop
while true; do
    clear
    /tmp/check_download_status.sh
    sleep 5
done
```

## Check Download Logs

### 9. View Download Script Output

```bash
# If download script was run in background
tail -f /tmp/download.log

# Or check recent output
journalctl -u download 2>/dev/null

# Check container logs (if download was part of entrypoint)
docker logs <container_name> | grep -i download
```

## Verify Completion

### 10. Verify All Models Downloaded

```bash
# Quick verification
MODELS_DIR="${MODEL_DIR:-/workspace/shared_models}"

REQUIRED_FILES=(
    "${MODELS_DIR}/vae/qwen_image_vae.safetensors"
    "${MODELS_DIR}/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors"
    "${MODELS_DIR}/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors"
    "${MODELS_DIR}/loras/Qwen-Image-Lightning-4steps-V2.0.safetensors"
)

ALL_PRESENT=true
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
        if [ "$size" -gt 1000000 ]; then  # At least 1MB
            echo "✓ $(basename "$file")"
        else
            echo "✗ $(basename "$file") - Too small (incomplete)"
            ALL_PRESENT=false
        fi
    else
        echo "✗ $(basename "$file") - Missing"
        ALL_PRESENT=false
    fi
done

if [ "$ALL_PRESENT" = true ]; then
    echo ""
    echo "✅ All models downloaded successfully!"
else
    echo ""
    echo "❌ Some models are missing or incomplete"
fi
```

## One-Liner Commands

### Quick Status Checks

```bash
# Is download running?
ps aux | grep -E "(wget|curl)" | grep -v grep && echo "Downloading..." || echo "Not downloading"

# Current sizes in MB
du -sm /workspace/shared_models/*/*.safetensors 2>/dev/null

# Count completed downloads
ls -1 /workspace/shared_models/*/*.safetensors 2>/dev/null | wc -l

# Total size downloaded
du -sh /workspace/shared_models
```

## For Vast AI Container

If you're monitoring inside a Vast AI container:

```bash
# SSH into container or use Vast AI web terminal
# Then run any of the commands above

# Most useful for Vast AI:
watch -n 5 'du -sh /workspace/shared_models/*/*.safetensors 2>/dev/null && echo "" && ps aux | grep -E "(wget|curl)" | grep -v grep'
```

## Troubleshooting

### Download Stuck or Slow

```bash
# Check network connectivity
ping -c 3 huggingface.co

# Check if process is actually downloading
lsof -p $(pgrep -f "wget.*safetensors") 2>/dev/null | grep -i tcp

# Check download speed (if wget shows progress)
# Look for the progress bar in wget output
```

### Incomplete Downloads

```bash
# Check file integrity (size should match expected)
# Re-run download script - it will skip complete files and re-download incomplete ones
/workspace/download_triton_models.sh
```


