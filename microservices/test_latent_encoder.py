#!/usr/bin/env python3
"""
Test script for latent_encoder service - Phase 2 information extraction
Extracts all tensor shapes, performance data, and resource requirements
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

# Add service to path
sys.path.insert(0, str(Path(__file__).parent / "latent_encoder"))

from service import encode_image_to_latent
from config import Config

def get_gpu_memory():
    """Get current GPU memory usage in MB"""
    try:
        if torch.cuda.is_available():
            # Use PyTorch to get GPU memory
            return torch.cuda.memory_allocated() / (1024 * 1024)  # Convert to MB
        else:
            # Fallback to nvidia-smi
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
        # Calculate differences
        diff = torch.abs(actual.float() - expected.float())
        comparison['max_diff'] = float(torch.max(diff).item())
        comparison['mean_diff'] = float(torch.mean(diff).item())
        comparison['within_tolerance'] = comparison['max_diff'] < tolerance
        
        # Calculate relative error
        abs_expected = torch.abs(expected.float())
        relative_diff = diff / (abs_expected + 1e-8)  # Avoid division by zero
        comparison['max_relative_error'] = float(torch.max(relative_diff).item())
        comparison['mean_relative_error'] = float(torch.mean(relative_diff).item())
    
    return comparison

def test_basic_functionality():
    """Test 1: Basic functionality and extract tensor info"""
    print("=" * 60)
    print("Test 1: Basic Functionality")
    print("=" * 60)
    
    # Use a test image (create dummy if needed)
    test_image = "test_data/images/person.jpg"
    if not os.path.exists(test_image):
        print(f"⚠️  Test image not found: {test_image}")
        print("   Creating placeholder - you'll need to add a real image")
        os.makedirs(os.path.dirname(test_image), exist_ok=True)
        # For now, we'll document what we expect
    
    results = {
        "test_name": "basic_functionality",
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
    }
    
    # Load expected tensor if available
    expected_tensor_path = Path("test_outputs/latent_encoder_output.pt")
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
        # Run service
        result = encode_image_to_latent(
            image_path=test_image,
            save_tensor=False  # Don't save, just return tensor
        )
        
        if result['status'] == 'success':
            latent_tensor = result['latent_tensor']
            
            # Extract tensor information
            results['input'] = {
                "type": "image",
                "format": "file_path",
                "expected_shape": "[batch, 3, height, width]",
                "note": "Image loaded and preprocessed"
            }
            
            results['output'] = {
                "name": "latent",
                "shape": list(latent_tensor.shape),
                "data_type": str(latent_tensor.dtype),
                "numpy_type": "float32" if latent_tensor.dtype == torch.float32 else str(latent_tensor.dtype),
                "triton_type": "TYPE_FP32" if latent_tensor.dtype == torch.float32 else "TYPE_FP16"
            }
            
            # Compare with expected tensor if available
            if expected_tensor is not None:
                comparison = compare_tensors(latent_tensor, expected_tensor)
                results['comparison'] = comparison
                
                if comparison['within_tolerance']:
                    print(f"✓ Output matches expected tensor (max diff: {comparison['max_diff']:.2e})")
                else:
                    print(f"⚠️  Output differs from expected tensor (max diff: {comparison['max_diff']:.2e})")
                    if not comparison['shapes_match']:
                        print(f"   Shape mismatch: actual {latent_tensor.shape} vs expected {expected_tensor.shape}")
                    if not comparison['dtypes_match']:
                        print(f"   Dtype mismatch: actual {latent_tensor.dtype} vs expected {expected_tensor.dtype}")
            
            results['metadata'] = result.get('metadata', {})
            results['status'] = 'success'
            
            print(f"✓ Input: Image file")
            print(f"✓ Output shape: {results['output']['shape']}")
            print(f"✓ Output dtype: {results['output']['data_type']}")
            print(f"✓ Processing time: {result.get('metadata', {}).get('processing_time_ms', 0)}ms")
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

def test_batch_processing():
    """Test 2: Batch processing capabilities"""
    print("\n" + "=" * 60)
    print("Test 2: Batch Processing")
    print("=" * 60)
    
    results = {
        "test_name": "batch_processing",
        "batch_sizes_tested": [],
        "batch_results": {}
    }
    
    # Test different batch sizes
    # Note: Service may need modification to support batching
    # For now, document current capability
    
    results['supports_batching'] = False  # Will be determined by testing
    results['max_batch_size'] = 1  # Default, will be updated
    results['note'] = "Service currently processes single images. Batch support needs implementation."
    
    print("⚠️  Batch processing test - service may need modification")
    print("   Current: Single image processing only")
    
    return results

def test_resource_usage():
    """Test 3: Resource profiling"""
    print("\n" + "=" * 60)
    print("Test 3: Resource Profiling")
    print("=" * 60)
    
    results = {
        "test_name": "resource_profiling"
    }
    
    # Get initial GPU memory
    if torch.cuda.is_available():
        torch.cuda.empty_cache()  # Clear cache before measurement
        torch.cuda.reset_peak_memory_stats()  # Reset peak stats
        initial_gpu_memory = get_gpu_memory()
    else:
        initial_gpu_memory = get_gpu_memory()
    
    # Get initial CPU usage
    process = psutil.Process()
    initial_cpu = process.cpu_percent(interval=0.1)
    
    # Run inference
    test_image = "test_data/images/person.jpg"
    if os.path.exists(test_image):
        # Monitor CPU during inference
        cpu_samples = []
        def monitor_cpu():
            while True:
                cpu_samples.append(process.cpu_percent(interval=0.1))
                time.sleep(0.1)
        
        import threading
        monitor_thread = threading.Thread(target=monitor_cpu, daemon=True)
        monitor_thread.start()
        
        start_time = time.time()
        result = encode_image_to_latent(image_path=test_image, save_tensor=False)
        inference_time = time.time() - start_time
        
        # Stop monitoring
        time.sleep(0.2)  # Let last sample complete
        
        # Get peak GPU memory
        if torch.cuda.is_available():
            peak_gpu_memory_mb = torch.cuda.max_memory_allocated() / (1024 * 1024)  # Convert to MB
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
        results['note'] = "Test image not found - using placeholder values"
        results['gpu_memory'] = {"used_mb": "TBD"}
        results['cpu_usage'] = {"peak_percent": "TBD"}
    
    return results

def main():
    """Run all tests and generate TRITON_CONFIG_DATA.json"""
    print("=" * 60)
    print("Latent Encoder - Phase 2 Information Extraction")
    print("=" * 60)
    print()
    
    test_results = {}
    
    # Run tests
    test_results['basic_functionality'] = test_basic_functionality()
    test_results['batch_processing'] = test_batch_processing()
    test_results['resource_profiling'] = test_resource_usage()
    
    # Compile final config data
    config_data = {
        "service": "latent_encoder",
        "extraction_timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "tensor_info": {
            "input": {
                "name": "input_image",
                "type": "image_file_path",
                "format": "STRING",
                "note": "Path to image file, loaded and preprocessed internally"
            },
            "output": test_results['basic_functionality'].get('output', {})
        },
        "batch_config": {
            "supports_batching": test_results['batch_processing'].get('supports_batching', False),
            "max_batch_size": test_results['batch_processing'].get('max_batch_size', 1),
            "note": "Batch support may need implementation"
        },
        "resource_requirements": test_results['resource_profiling'].get('gpu_memory', {}),
        "output_verification": {
            "expected_tensor_path": "test_outputs/latent_encoder_output.pt",
            "comparison": test_results['basic_functionality'].get('comparison', {})
        },
        "performance": {
            "inference_time_ms": test_results['resource_profiling'].get('inference_time_seconds', 0) * 1000
        },
        "model_files": {
            "vae_encoder": "shared_models/vae/qwen_image_vae.safetensors"
        },
        "triton_config": {
            "recommended_instance_count": 1,  # Will be updated after concurrency testing
            "recommended_max_batch_size": 1,  # Will be updated after batch testing
            "dynamic_batching": False,  # Will be updated
            "model_sharing": "shared"
        }
    }
    
    # Save results
    output_dir = Path("test_results/latent_encoder")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Save detailed test results
    with open(output_dir / "test_results.json", 'w') as f:
        json.dump(test_results, f, indent=2)
    
    # Save Triton config data
    with open(output_dir / "TRITON_CONFIG_DATA.json", 'w') as f:
        json.dump(config_data, f, indent=2)
    
    print("\n" + "=" * 60)
    print("Results saved:")
    print(f"  - {output_dir / 'test_results.json'}")
    print(f"  - {output_dir / 'TRITON_CONFIG_DATA.json'}")
    print("=" * 60)

if __name__ == "__main__":
    main()

