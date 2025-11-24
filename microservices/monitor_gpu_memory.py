#!/usr/bin/env python3
"""Monitor GPU memory usage in real-time."""
import torch
import time
import sys
from datetime import datetime

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
            
            # Get utilization (requires nvidia-ml-py, optional)
            utilization = "N/A"
            try:
                import pynvml
                pynvml.nvmlInit()
                handle = pynvml.nvmlDeviceGetHandleByIndex(device)
                util = pynvml.nvmlDeviceGetUtilizationRates(handle)
                utilization = f"{util.gpu}%"
            except ImportError:
                pass
            except:
                pass
            
            timestamp = datetime.now().strftime("%H:%M:%S")
            print(f"{timestamp:<12} {format_bytes(allocated):<15} {format_bytes(reserved):<15} "
                  f"{format_bytes(free):<15} {utilization:<12}")
            
            time.sleep(interval)
    except KeyboardInterrupt:
        print("\nMonitoring stopped.")

if __name__ == "__main__":
    interval = float(sys.argv[1]) if len(sys.argv) > 1 else 1.0
    monitor_gpu(interval)

