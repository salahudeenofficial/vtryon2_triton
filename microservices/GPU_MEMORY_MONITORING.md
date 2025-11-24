# GPU Memory Monitoring Guide

## Overview

Multiple ways to monitor GPU memory usage in your Triton ensemble setup.

---

## 1. Using Code Logging (Already Added)

The code now logs GPU memory at key points. Check Triton server logs:

```bash
# View Triton logs
docker logs <triton-container-id> 2>&1 | grep "GPU memory"

# Or if running directly
tail -f /path/to/triton/logs | grep "GPU memory"
```

**Example output:**
```
[latent_encoder] GPU memory before: 2.50GB allocated, 3.00GB reserved
[latent_encoder] GPU memory after: 0.10GB allocated, 0.50GB reserved
[text_encoder] GPU memory before: 0.10GB allocated, 0.50GB reserved
[text_encoder] GPU memory after: 7.20GB allocated, 8.00GB reserved
[sampling] GPU memory before: 0.10GB allocated, 0.50GB reserved
[sampling] GPU memory after: 3.50GB allocated, 4.00GB reserved
```

---

## 2. Using nvidia-smi (Real-time)

### Basic Monitoring

```bash
# Watch GPU memory in real-time (updates every 1 second)
watch -n 1 nvidia-smi

# Or one-time snapshot
nvidia-smi
```

### Continuous Monitoring with Timestamps

```bash
# Monitor with timestamps, save to file
nvidia-smi --query-gpu=timestamp,name,memory.used,memory.total,utilization.gpu --format=csv -l 1 > gpu_monitor.csv

# View in real-time
nvidia-smi --query-gpu=timestamp,name,memory.used,memory.total,utilization.gpu --format=csv -l 1
```

### Filtered Output (Memory Only)

```bash
# Show only memory usage
nvidia-smi --query-gpu=index,name,memory.used,memory.total,memory.free --format=csv -l 1
```

**Output:**
```
timestamp, name, memory.used [MiB], memory.total [MiB], memory.free [MiB]
2024-01-15 10:00:00, NVIDIA A100, 2560, 40960, 38400
2024-01-15 10:00:01, NVIDIA A100, 5120, 40960, 35840
```

---

## 3. Using PyTorch Memory Monitoring

### In Python Code (Already in model.py)

The code now includes:
```python
allocated = torch.cuda.memory_allocated(0) / 1e9  # GB
reserved = torch.cuda.memory_reserved(0) / 1e9    # GB
total = torch.cuda.get_device_properties(0).total_memory / 1e9  # GB
free = total - reserved
```

### Standalone Monitoring Script

Create `monitor_gpu_memory.py`:

```python
#!/usr/bin/env python3
"""Monitor GPU memory usage in real-time."""
import torch
import time
import sys

def format_bytes(bytes_val):
    """Format bytes to human-readable format."""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes_val < 1024.0:
            return f"{bytes_val:.2f} {unit}"
        bytes_val /= 1024.0
    return f"{bytes_val:.2f} PB"

def monitor_gpu(interval=1.0):
    """Monitor GPU memory continuously."""
    if not torch.cuda.is_available():
        print("CUDA not available!")
        return
    
    device = torch.cuda.current_device()
    props = torch.cuda.get_device_properties(device)
    
    print(f"Monitoring GPU: {props.name}")
    print(f"Total Memory: {format_bytes(props.total_memory)}")
    print(f"Press Ctrl+C to stop\n")
    print(f"{'Time':<12} {'Allocated':<15} {'Reserved':<15} {'Free':<15} {'Utilization':<12}")
    print("-" * 75)
    
    try:
        while True:
            allocated = torch.cuda.memory_allocated(device)
            reserved = torch.cuda.memory_reserved(device)
            total = props.total_memory
            free = total - reserved
            
            # Get utilization (requires nvidia-ml-py)
            utilization = "N/A"
            try:
                import pynvml
                pynvml.nvmlInit()
                handle = pynvml.nvmlDeviceGetHandleByIndex(device)
                util = pynvml.nvmlDeviceGetUtilizationRates(handle)
                utilization = f"{util.gpu}%"
            except:
                pass
            
            timestamp = time.strftime("%H:%M:%S")
            print(f"{timestamp:<12} {format_bytes(allocated):<15} {format_bytes(reserved):<15} "
                  f"{format_bytes(free):<15} {utilization:<12}")
            
            time.sleep(interval)
    except KeyboardInterrupt:
        print("\nMonitoring stopped.")

if __name__ == "__main__":
    interval = float(sys.argv[1]) if len(sys.argv) > 1 else 1.0
    monitor_gpu(interval)
```

**Usage:**
```bash
python monitor_gpu_memory.py 1.0  # Update every 1 second
```

---

## 4. Using Triton Metrics API

Triton exposes metrics via Prometheus format:

```bash
# Get metrics
curl http://localhost:8002/metrics | grep gpu

# Or filter for memory
curl http://localhost:8002/metrics | grep -E "gpu|memory"
```

**Example metrics:**
```
nv_gpu_utilization_gauge{device="0",uuid="..."} 45.0
nv_gpu_memory_total_bytes{device="0",uuid="..."} 42949672960
nv_gpu_memory_used_bytes{device="0",uuid="..."} 10737418240
```

---

## 5. Monitoring Script for Ensemble Pipeline

Create `monitor_ensemble_gpu.sh`:

```bash
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
```

**Usage:**
```bash
chmod +x monitor_ensemble_gpu.sh
./monitor_ensemble_gpu.sh
```

---

## 6. Advanced: Monitor with Process Names

Create `monitor_gpu_with_processes.sh`:

```bash
#!/bin/bash
# Monitor GPU memory with process information

watch -n 1 'echo "=== GPU Memory ===" && \
nvidia-smi --query-gpu=memory.used,memory.total --format=csv && \
echo "" && \
echo "=== GPU Processes ===" && \
nvidia-smi pmon -c 1'
```

---

## 7. Python Script for Detailed Monitoring

Create `detailed_gpu_monitor.py`:

```python
#!/usr/bin/env python3
"""Detailed GPU memory monitoring with process tracking."""
import torch
import subprocess
import json
import time
from datetime import datetime

def get_nvidia_smi_info():
    """Get GPU info from nvidia-smi."""
    try:
        result = subprocess.run(
            ['nvidia-smi', '--query-gpu=memory.used,memory.total,utilization.gpu', 
             '--format=csv,noheader,nounits'],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            used, total, util = map(int, result.stdout.strip().split(', '))
            return {
                'used_mb': used,
                'total_mb': total,
                'utilization': util,
                'used_percent': (used / total) * 100,
                'free_mb': total - used
            }
    except:
        pass
    return None

def get_pytorch_memory():
    """Get PyTorch GPU memory info."""
    if not torch.cuda.is_available():
        return None
    
    device = torch.cuda.current_device()
    allocated = torch.cuda.memory_allocated(device) / 1e6  # MB
    reserved = torch.cuda.memory_reserved(device) / 1e6    # MB
    max_allocated = torch.cuda.max_memory_allocated(device) / 1e6  # MB
    
    return {
        'allocated_mb': allocated,
        'reserved_mb': reserved,
        'max_allocated_mb': max_allocated
    }

def monitor():
    """Monitor GPU memory continuously."""
    print(f"{'Time':<20} {'nvidia-smi':<30} {'PyTorch':<30}")
    print("-" * 80)
    
    try:
        while True:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            # nvidia-smi info
            smi_info = get_nvidia_smi_info()
            smi_str = "N/A"
            if smi_info:
                smi_str = f"{smi_info['used_mb']}/{smi_info['total_mb']} MB ({smi_info['used_percent']:.1f}%)"
            
            # PyTorch info
            torch_info = get_pytorch_memory()
            torch_str = "N/A"
            if torch_info:
                torch_str = f"Alloc: {torch_info['allocated_mb']:.0f} MB, Reserved: {torch_info['reserved_mb']:.0f} MB"
            
            print(f"{timestamp:<20} {smi_str:<30} {torch_str:<30}")
            time.sleep(1.0)
    except KeyboardInterrupt:
        print("\nMonitoring stopped.")

if __name__ == "__main__":
    monitor()
```

**Usage:**
```bash
python detailed_gpu_monitor.py
```

---

## 8. Monitor During Triton Inference

### While Running Inference

```bash
# Terminal 1: Start monitoring
watch -n 0.5 'nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv'

# Terminal 2: Run inference
curl -X POST http://localhost:8000/v2/models/vtryon_pipeline/infer \
  -H "Content-Type: application/json" \
  -d @test_request.json
```

### Save to File for Analysis

```bash
# Monitor and save to file
nvidia-smi --query-gpu=timestamp,memory.used,memory.total,utilization.gpu \
  --format=csv -l 0.5 > gpu_usage.csv

# Analyze later
cat gpu_usage.csv | awk -F',' '{print $2, $3, $4}'
```

---

## 9. Quick One-Liners

```bash
# Current GPU memory
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader

# Memory usage percentage
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader | \
  awk -F', ' '{printf "%.1f%%\n", ($1/$2)*100}'

# Free memory in GB
nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits | \
  awk '{printf "%.2f GB\n", $1/1024}'
```

---

## 10. Integration with Logging

Add to your deployment script or monitoring setup:

```bash
# In deploy_vastai.sh or similar
# Start background monitoring
nohup nvidia-smi --query-gpu=timestamp,memory.used,memory.total \
  --format=csv -l 5 > /tmp/gpu_monitor.log 2>&1 &

# View logs
tail -f /tmp/gpu_monitor.log
```

---

## Recommended Approach

For your use case, I recommend:

1. **During Development**: Use `nvidia-smi` in a separate terminal
   ```bash
   watch -n 1 nvidia-smi
   ```

2. **In Production**: 
   - Enable Triton metrics endpoint (port 8002)
   - Use the logging we added in model.py
   - Set up Prometheus/Grafana if needed

3. **For Debugging**: Use the Python monitoring script to see both nvidia-smi and PyTorch memory

---

## Example: Monitoring Ensemble Execution

```bash
# Terminal 1: Monitor GPU
watch -n 0.5 'nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv'

# Terminal 2: Monitor Triton logs
docker logs -f <container> | grep "GPU memory"

# Terminal 3: Run inference
curl -X POST http://localhost:8000/v2/models/vtryon_pipeline/infer ...
```

This gives you:
- Real-time GPU memory from nvidia-smi
- Memory tracking from code logs
- Actual inference requests

---

## Troubleshooting

### If memory doesn't free:

1. **Check for zombie processes:**
   ```bash
   nvidia-smi pmon
   ```

2. **Force cleanup:**
   ```python
   import torch
   torch.cuda.empty_cache()
   torch.cuda.ipc_collect()
   ```

3. **Check Triton logs:**
   ```bash
   docker logs <container> | grep -i "memory\|oom\|error"
   ```

---

## Next Steps

1. Run inference and watch GPU memory
2. Verify memory is freed after each step
3. Check logs for memory tracking messages
4. Adjust if memory isn't being freed properly

