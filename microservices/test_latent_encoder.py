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
        result = subprocess.run(['nvidia-smi', '--query-gpu=memory.used', '--format=csv,nounits,noheader'],
                              capture_output=True, text=True)
        return int(result.stdout.strip())
    except:
        return 0

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
    initial_gpu_memory = get_gpu_memory()
    
    # Get initial CPU usage
    process = psutil.Process()
    initial_cpu = process.cpu_percent(interval=0.1)
    
    # Run inference
    test_image = "test_data/images/person.jpg"
    if os.path.exists(test_image):
        start_time = time.time()
        result = encode_image_to_latent(image_path=test_image, save_tensor=False)
        inference_time = time.time() - start_time
        
        # Get peak GPU memory
        peak_gpu_memory = get_gpu_memory()
        peak_cpu = process.cpu_percent(interval=0.1)
        
        results['gpu_memory'] = {
            "initial_mb": initial_gpu_memory,
            "peak_mb": peak_gpu_memory,
            "used_mb": peak_gpu_memory - initial_gpu_memory
        }
        
        results['cpu_usage'] = {
            "initial_percent": initial_cpu,
            "peak_percent": peak_cpu
        }
        
        results['inference_time_seconds'] = inference_time
        
        print(f"✓ GPU Memory: {results['gpu_memory']['used_mb']} MB")
        print(f"✓ CPU Usage: {results['cpu_usage']['peak_percent']}%")
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

