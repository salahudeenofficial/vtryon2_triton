#!/bin/bash
# Monitor GPU memory during ensemble pipeline execution

echo "Monitoring GPU memory during ensemble pipeline..."
echo "Press Ctrl+C to stop"
echo ""

# Function to get GPU memory info
get_gpu_memory() {
    nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits | \
    awk -F', ' '{printf "GPU Memory: %d/%d MB (%.1f%%) | Utilization: %d%%\n", $1, $2, ($1/$2)*100, $3}'
}

# Monitor continuously
while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    memory_info=$(get_gpu_memory)
    echo "[$timestamp] $memory_info"
    sleep 1
done

