#!/usr/bin/env python3
"""
Test script for decoding service - Phase 2 information extraction
"""

import sys
import os
import json
import time
import torch
import numpy as np
from pathlib import Path
import subprocess
import psutil
import threading

sys.path.insert(0, str(Path(__file__).parent / "decoding"))

from service import decode_latent_to_image
from config import Config

def get_gpu_memory():
    """Get current GPU memory usage in MB"""
    try:
        if torch.cuda.is_available():
            return torch.cuda.memory_allocated() / (1024 * 1024)
        else:
            result = subprocess.run(['nvidia-smi', '--query-gpu=memory.used', '--format=csv,nounits,noheader'],
                                  capture_output=True, text=True)
            return int(result.stdout.strip())
    except:
        return 0

def compare_tensors(actual: torch.Tensor, expected: torch.Tensor, tolerance: float = 1e-5) -> dict:
    """Compare actual tensor with expected tensor."""
    comparison = {
        "shapes_match": actual.shape == expected.shape,
        "dtypes_match": actual.dtype == expected.dtype,
        "max_diff": None,
        "mean_diff": None,
        "within_tolerance": None
    }
    
    if comparison['shapes_match'] and comparison['dtypes_match']:
        diff = torch.abs(actual.float() - expected.float())
        comparison['max_diff'] = float(torch.max(diff).item())
        comparison['mean_diff'] = float(torch.mean(diff).item())
        comparison['within_tolerance'] = comparison['max_diff'] < tolerance
        
        abs_expected = torch.abs(expected.float())
        relative_diff = diff / (abs_expected + 1e-8)
        comparison['max_relative_error'] = float(torch.max(relative_diff).item())
        comparison['mean_relative_error'] = float(torch.mean(relative_diff).item())
    
    return comparison

def test_basic_functionality():
    """Test basic functionality and extract tensor info"""
    print("=" * 60)
    print("Test 1: Basic Functionality - Decoding")
    print("=" * 60)
    
    # Use expected tensor from workflow_script_serial_test.py
    test_latent = "test_outputs/sampling_output.pt"
    
    results = {
        "test_name": "basic_functionality",
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
    }
    
    # Load expected tensor if available
    expected_tensor_path = Path("test_outputs/decoding_output.pt")
    expected_tensor = None
    if expected_tensor_path.exists():
        try:
            expected_tensor = torch.load(expected_tensor_path)
            print(f"✓ Loaded expected tensor from: {expected_tensor_path}")
            print(f"  Expected shape: {expected_tensor.shape}, dtype: {expected_tensor.dtype}")
        except Exception as e:
            print(f"⚠️  Could not load expected tensor: {e}")
    else:
        print(f"⚠️  Expected tensor not found: {expected_tensor_path}")
        print("   Run workflow_script_serial_test.py first to generate expected outputs")
    
    try:
        result = decode_latent_to_image(
            latent=test_latent,
            save_image=False
        )
        
        if result['status'] == 'success':
            image_tensor = result.get('image_tensor')
            
            results['input'] = {
                "name": "latent",
                "type": "tensor_file",
                "format": "STRING"
            }
            
            results['output'] = {
                "name": "image",
                "shape": list(image_tensor.shape) if image_tensor is not None else None,
                "data_type": str(image_tensor.dtype) if image_tensor is not None else None,
                "triton_type": "TYPE_FP32"
            }
            
            # Compare with expected tensor if available
            if expected_tensor is not None and image_tensor is not None:
                comparison = compare_tensors(image_tensor, expected_tensor)
                results['comparison'] = comparison
                
                if comparison['within_tolerance']:
                    print(f"✓ Output matches expected tensor (max diff: {comparison['max_diff']:.2e})")
                else:
                    print(f"⚠️  Output differs from expected tensor (max diff: {comparison['max_diff']:.2e})")
                    if not comparison['shapes_match']:
                        print(f"   Shape mismatch: actual {image_tensor.shape} vs expected {expected_tensor.shape}")
            
            results['status'] = 'success'
            print(f"✓ Output shape: {results['output']['shape']}")
        else:
            results['status'] = 'error'
            results['error'] = result.get('error_message', 'Unknown error')
            print(f"✗ Error: {results['error']}")
    except Exception as e:
        results['status'] = 'error'
        results['error'] = str(e)
        print(f"✗ Exception: {e}")
        import traceback
        traceback.print_exc()
    
    return results

def test_resource_usage():
    """Test 2: Resource profiling"""
    print("\n" + "=" * 60)
    print("Test 2: Resource Profiling")
    print("=" * 60)
    
    results = {
        "test_name": "resource_profiling"
    }
    
    # Get initial GPU memory
    if torch.cuda.is_available():
        torch.cuda.empty_cache()
        torch.cuda.reset_peak_memory_stats()
        initial_gpu_memory = get_gpu_memory()
    else:
        initial_gpu_memory = get_gpu_memory()
    
    # Get initial CPU usage
    process = psutil.Process()
    initial_cpu = process.cpu_percent(interval=0.1)
    
    # Run inference
    test_latent = "test_outputs/sampling_output.pt"
    
    if os.path.exists(test_latent):
        # Monitor CPU during inference
        cpu_samples = []
        def monitor_cpu():
            while True:
                cpu_samples.append(process.cpu_percent(interval=0.1))
                time.sleep(0.1)
        
        monitor_thread = threading.Thread(target=monitor_cpu, daemon=True)
        monitor_thread.start()
        
        start_time = time.time()
        result = decode_latent_to_image(
            latent=test_latent,
            save_image=False
        )
        inference_time = time.time() - start_time
        
        time.sleep(0.2)
        
        # Get peak GPU memory
        if torch.cuda.is_available():
            peak_gpu_memory_mb = torch.cuda.max_memory_allocated() / (1024 * 1024)
            current_gpu_memory = get_gpu_memory()
        else:
            peak_gpu_memory_mb = get_gpu_memory()
            current_gpu_memory = peak_gpu_memory_mb
        
        # Calculate average CPU usage
        if cpu_samples:
            avg_cpu = sum(cpu_samples) / len(cpu_samples)
            max_cpu = max(cpu_samples)
        else:
            avg_cpu = process.cpu_percent(interval=0.1)
            max_cpu = avg_cpu
        
        results['gpu_memory'] = {
            "initial_mb": initial_gpu_memory,
            "peak_mb": peak_gpu_memory_mb,
            "current_mb": current_gpu_memory,
            "used_mb": peak_gpu_memory_mb - initial_gpu_memory
        }
        
        results['cpu_usage'] = {
            "initial_percent": initial_cpu,
            "average_percent": avg_cpu,
            "peak_percent": max_cpu
        }
        
        results['inference_time_seconds'] = inference_time
        
        print(f"✓ GPU Memory - Initial: {initial_gpu_memory:.1f} MB")
        print(f"✓ GPU Memory - Peak: {peak_gpu_memory_mb:.1f} MB")
        print(f"✓ GPU Memory - Used: {results['gpu_memory']['used_mb']:.1f} MB")
        print(f"✓ CPU Usage - Average: {avg_cpu:.1f}%")
        print(f"✓ CPU Usage - Peak: {max_cpu:.1f}%")
        print(f"✓ Inference Time: {inference_time:.3f}s")
    else:
        results['note'] = "Test input tensor not found"
        results['gpu_memory'] = {"used_mb": "TBD"}
        results['cpu_usage'] = {"peak_percent": "TBD"}
    
    return results

def main():
    """Run tests and generate TRITON_CONFIG_DATA.json"""
    print("=" * 60)
    print("Decoding - Phase 2 Information Extraction")
    print("=" * 60)
    print()
    
    test_results = {}
    test_results['basic_functionality'] = test_basic_functionality()
    test_results['resource_profiling'] = test_resource_usage()
    
    config_data = {
        "service": "decoding",
        "extraction_timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "tensor_info": {
            "input": test_results['basic_functionality'].get('input', {}),
            "output": test_results['basic_functionality'].get('output', {})
        },
        "resource_requirements": test_results['resource_profiling'].get('gpu_memory', {}),
        "performance": {
            "inference_time_ms": test_results['resource_profiling'].get('inference_time_seconds', 0) * 1000
        },
        "output_verification": {
            "expected_tensor_path": "test_outputs/decoding_output.pt",
            "comparison": test_results['basic_functionality'].get('comparison', {})
        },
        "model_files": {
            "vae_decoder": "shared_models/vae/qwen_image_vae.safetensors"
        },
        "triton_config": {
            "recommended_instance_count": 1,
            "recommended_max_batch_size": 1,
            "dynamic_batching": False,
            "model_sharing": "shared"
        }
    }
    
    output_dir = Path("test_results/decoding")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    with open(output_dir / "test_results.json", 'w') as f:
        json.dump(test_results, f, indent=2)
    
    with open(output_dir / "TRITON_CONFIG_DATA.json", 'w') as f:
        json.dump(config_data, f, indent=2)
    
    print("\n" + "=" * 60)
    print("Results saved:")
    print(f"  - {output_dir / 'test_results.json'}")
    print(f"  - {output_dir / 'TRITON_CONFIG_DATA.json'}")
    print("=" * 60)

if __name__ == "__main__":
    main()
