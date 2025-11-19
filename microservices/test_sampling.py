#!/usr/bin/env python3
"""
Test script for sampling service - Phase 2 information extraction
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

sys.path.insert(0, str(Path(__file__).parent / "sampling"))

from service import sample_latent
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
    print("Test 1: Basic Functionality - Sampling")
    print("=" * 60)
    
    # Use expected tensors from workflow_script_serial_test.py
    test_positive = "test_outputs/text_encoder_positive_output.pt"
    test_negative = "test_outputs/text_encoder_negative_output.pt"
    test_latent = "test_outputs/latent_encoder_output.pt"
    
    results = {
        "test_name": "basic_functionality",
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
    }
    
    # Load expected tensor if available
    expected_tensor_path = Path("test_outputs/sampling_output.pt")
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
        # Use fixed seed to match workflow_script_serial_test.py
        test_seed = 724723345395306
        
        result = sample_latent(
            positive_encoding=test_positive,
            negative_encoding=test_negative,
            latent_image=test_latent,
            seed=test_seed,
            steps=4,
            cfg=1.0,
            save_tensor=False
        )
        
        if result['status'] == 'success':
            sampled_tensor = result.get('sampled_latent_tensor')
            
            results['inputs'] = {
                "positive_encoding": {"type": "tensor_file", "format": "STRING"},
                "negative_encoding": {"type": "tensor_file", "format": "STRING"},
                "latent_image": {"type": "tensor_file", "format": "STRING"},
                "seed": {"type": "INT64", "default": test_seed},
                "steps": {"type": "INT32", "default": 4},
                "cfg": {"type": "FP32", "default": 1.0}
            }
            
            results['output'] = {
                "name": "sampled_latent",
                "shape": list(sampled_tensor.shape) if sampled_tensor is not None else None,
                "data_type": str(sampled_tensor.dtype) if sampled_tensor is not None else None,
                "triton_type": "TYPE_FP32"
            }
            
            # Compare with expected tensor if available
            if expected_tensor is not None and sampled_tensor is not None:
                comparison = compare_tensors(sampled_tensor, expected_tensor, tolerance=1e-4)  # Sampling may have more variance
                results['comparison'] = comparison
                
                if comparison['within_tolerance']:
                    print(f"✓ Output matches expected tensor (max diff: {comparison['max_diff']:.2e})")
                else:
                    print(f"⚠️  Output differs from expected tensor (max diff: {comparison['max_diff']:.2e})")
                    if not comparison['shapes_match']:
                        print(f"   Shape mismatch: actual {sampled_tensor.shape} vs expected {expected_tensor.shape}")
            
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
    test_positive = "test_outputs/text_encoder_positive_output.pt"
    test_negative = "test_outputs/text_encoder_negative_output.pt"
    test_latent = "test_outputs/latent_encoder_output.pt"
    test_seed = 724723345395306
    
    if all(os.path.exists(p) for p in [test_positive, test_negative, test_latent]):
        # Monitor CPU during inference
        cpu_samples = []
        def monitor_cpu():
            while True:
                cpu_samples.append(process.cpu_percent(interval=0.1))
                time.sleep(0.1)
        
        monitor_thread = threading.Thread(target=monitor_cpu, daemon=True)
        monitor_thread.start()
        
        start_time = time.time()
        result = sample_latent(
            positive_encoding=test_positive,
            negative_encoding=test_negative,
            latent_image=test_latent,
            seed=test_seed,
            steps=4,
            cfg=1.0,
            save_tensor=False
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
        results['note'] = "Test input tensors not found"
        results['gpu_memory'] = {"used_mb": "TBD"}
        results['cpu_usage'] = {"peak_percent": "TBD"}
    
    return results

def main():
    """Run tests and generate TRITON_CONFIG_DATA.json"""
    print("=" * 60)
    print("Sampling - Phase 2 Information Extraction")
    print("=" * 60)
    print()
    
    test_results = {}
    test_results['basic_functionality'] = test_basic_functionality()
    test_results['resource_profiling'] = test_resource_usage()
    
    config_data = {
        "service": "sampling",
        "extraction_timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "tensor_info": {
            "inputs": test_results['basic_functionality'].get('inputs', {}),
            "output": test_results['basic_functionality'].get('output', {})
        },
        "resource_requirements": test_results['resource_profiling'].get('gpu_memory', {}),
        "performance": {
            "inference_time_ms": test_results['resource_profiling'].get('inference_time_seconds', 0) * 1000
        },
        "output_verification": {
            "expected_tensor_path": "test_outputs/sampling_output.pt",
            "comparison": test_results['basic_functionality'].get('comparison', {})
        },
        "model_files": {
            "unet": "shared_models/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors",
            "lora": "shared_models/loras/Qwen-Image-Lightning-4steps-V2.0.safetensors"
        },
        "triton_config": {
            "recommended_instance_count": 1,
            "recommended_max_batch_size": 1,
            "dynamic_batching": False,
            "model_sharing": "shared"
        }
    }
    
    output_dir = Path("test_results/sampling")
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
