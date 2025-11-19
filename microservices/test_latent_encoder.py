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

def get_gpu_utilization():
    """Get GPU utilization percentage"""
    try:
        result = subprocess.run(['nvidia-smi', '--query-gpu=utilization.gpu', '--format=csv,nounits,noheader'],
                              capture_output=True, text=True, timeout=5)
        return float(result.stdout.strip())
    except:
        return 0.0

def get_gpu_memory_utilization():
    """Get GPU memory utilization percentage"""
    try:
        result = subprocess.run(['nvidia-smi', '--query-gpu=utilization.memory', '--format=csv,nounits,noheader'],
                              capture_output=True, text=True, timeout=5)
        return float(result.stdout.strip())
    except:
        return 0.0

def get_cpu_info():
    """Get detailed CPU information"""
    try:
        cpu_count = psutil.cpu_count(logical=True)
        cpu_freq = psutil.cpu_freq()
        return {
            "logical_cores": cpu_count,
            "physical_cores": psutil.cpu_count(logical=False),
            "max_frequency_mhz": cpu_freq.max if cpu_freq else None,
            "current_frequency_mhz": cpu_freq.current if cpu_freq else None
        }
    except:
        return {"logical_cores": 1, "physical_cores": 1}

def get_per_core_cpu_usage():
    """Get CPU usage per core"""
    try:
        return psutil.cpu_percent(interval=0.1, percpu=True)
    except:
        return []

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
    
    # Load expected tensor if available (check both current dir and parent dir)
    expected_tensor_paths = [
        Path("test_outputs/latent_encoder_output.pt"),
        Path("../test_outputs/latent_encoder_output.pt"),
        Path(__file__).parent.parent / "test_outputs" / "latent_encoder_output.pt"
    ]
    expected_tensor = None
    expected_tensor_path = None
    
    for path in expected_tensor_paths:
        if path.exists():
            expected_tensor_path = path
            try:
                expected_tensor = torch.load(path)
                print(f"✓ Loaded expected tensor from: {path}")
                print(f"  Expected shape: {expected_tensor.shape}, dtype: {expected_tensor.dtype}")
                break
            except Exception as e:
                print(f"⚠️  Could not load expected tensor from {path}: {e}")
    
    if expected_tensor is None:
        print(f"⚠️  Expected tensor not found in any of: {[str(p) for p in expected_tensor_paths]}")
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
    """Test 3: Resource profiling with comprehensive metrics for concurrency analysis"""
    print("\n" + "=" * 60)
    print("Test 3: Resource Profiling")
    print("=" * 60)
    
    results = {
        "test_name": "resource_profiling"
    }
    
    # Get system information
    cpu_info = get_cpu_info()
    results['system_info'] = cpu_info
    
    # Get initial GPU metrics
    if torch.cuda.is_available():
        torch.cuda.empty_cache()
        torch.cuda.reset_peak_memory_stats()
        initial_gpu_memory = get_gpu_memory()
        initial_gpu_util = get_gpu_utilization()
        initial_gpu_mem_util = get_gpu_memory_utilization()
    else:
        initial_gpu_memory = get_gpu_memory()
        initial_gpu_util = 0.0
        initial_gpu_mem_util = 0.0
    
    # Get initial CPU metrics
    process = psutil.Process()
    initial_cpu = process.cpu_percent(interval=0.1)
    initial_per_core_cpu = get_per_core_cpu_usage()
    
    # Get initial system-wide CPU
    initial_system_cpu = psutil.cpu_percent(interval=0.1)
    
    # Run inference
    test_image = "test_data/images/person.jpg"
    if os.path.exists(test_image):
        # Monitor resources during inference
        cpu_samples = []
        per_core_samples = []
        gpu_util_samples = []
        gpu_mem_util_samples = []
        
        def monitor_resources():
            while True:
                cpu_samples.append(process.cpu_percent(interval=0.1))
                per_core_samples.append(get_per_core_cpu_usage())
                gpu_util_samples.append(get_gpu_utilization())
                gpu_mem_util_samples.append(get_gpu_memory_utilization())
                time.sleep(0.1)
        
        import threading
        monitor_thread = threading.Thread(target=monitor_resources, daemon=True)
        monitor_thread.start()
        
        start_time = time.time()
        result = encode_image_to_latent(image_path=test_image, save_tensor=False)
        inference_time = time.time() - start_time
        
        # Stop monitoring
        time.sleep(0.2)
        
        # Get peak GPU metrics
        if torch.cuda.is_available():
            peak_gpu_memory_mb = torch.cuda.max_memory_allocated() / (1024 * 1024)
            current_gpu_memory = get_gpu_memory()
            # Get total GPU memory
            total_gpu_memory = torch.cuda.get_device_properties(0).total_memory / (1024 * 1024)
        else:
            peak_gpu_memory_mb = get_gpu_memory()
            current_gpu_memory = peak_gpu_memory_mb
            total_gpu_memory = None
        
        # Calculate statistics
        # Note: psutil.cpu_percent() can return >100% on multi-core systems
        # We need to normalize it or use system-wide CPU instead
        if cpu_samples:
            # Normalize CPU usage (process.cpu_percent can be >100% on multi-core)
            # Divide by number of cores to get per-core average, then multiply by 100 for percentage
            avg_cpu = sum(cpu_samples) / len(cpu_samples) / cpu_info['logical_cores'] * 100
            max_cpu = max(cpu_samples) / cpu_info['logical_cores'] * 100
            # Cap at 100% for display
            avg_cpu = min(avg_cpu, 100.0)
            max_cpu = min(max_cpu, 100.0)
        else:
            cpu_pct = process.cpu_percent(interval=0.1)
            avg_cpu = min(cpu_pct / cpu_info['logical_cores'] * 100, 100.0)
            max_cpu = avg_cpu
        
        # Per-core CPU analysis
        if per_core_samples:
            # Get max usage per core across all samples
            max_per_core = [max([sample[i] if i < len(sample) else 0 for sample in per_core_samples]) 
                          for i in range(cpu_info['logical_cores'])]
            avg_per_core = [sum([sample[i] if i < len(sample) else 0 for sample in per_core_samples]) / len(per_core_samples)
                          for i in range(cpu_info['logical_cores'])]
        else:
            max_per_core = []
            avg_per_core = []
        
        # GPU utilization statistics
        if gpu_util_samples:
            avg_gpu_util = sum(gpu_util_samples) / len(gpu_util_samples)
            max_gpu_util = max(gpu_util_samples)
        else:
            avg_gpu_util = get_gpu_utilization()
            max_gpu_util = avg_gpu_util
        
        if gpu_mem_util_samples:
            avg_gpu_mem_util = sum(gpu_mem_util_samples) / len(gpu_mem_util_samples)
            max_gpu_mem_util = max(gpu_mem_util_samples)
        else:
            avg_gpu_mem_util = get_gpu_memory_utilization()
            max_gpu_mem_util = avg_gpu_mem_util
        
        # System-wide CPU
        final_system_cpu = psutil.cpu_percent(interval=0.1)
        
        # Compile results
        results['gpu_memory'] = {
            "initial_mb": initial_gpu_memory,
            "peak_mb": peak_gpu_memory_mb,
            "current_mb": current_gpu_memory,
            "used_mb": peak_gpu_memory_mb - initial_gpu_memory,
            "total_mb": total_gpu_memory,
            "utilization_percent": {
                "initial": initial_gpu_mem_util,
                "average": avg_gpu_mem_util,
                "peak": max_gpu_mem_util
            }
        }
        
        results['gpu_compute'] = {
            "utilization_percent": {
                "initial": initial_gpu_util,
                "average": avg_gpu_util,
                "peak": max_gpu_util
            }
        }
        
        results['cpu_usage'] = {
            "process_percent": {
                "initial": initial_cpu,
                "average": avg_cpu,
                "peak": max_cpu
            },
            "system_percent": {
                "initial": initial_system_cpu,
                "final": final_system_cpu
            },
            "per_core": {
                "max": max_per_core,
                "average": avg_per_core,
                "cores_utilized": len([x for x in max_per_core if x > 10])  # Cores with >10% usage
            }
        }
        
        results['inference_time_seconds'] = inference_time
        
        # Calculate concurrency recommendations
        results['concurrency_analysis'] = calculate_concurrency_recommendations(
            gpu_memory_used=results['gpu_memory']['used_mb'],
            gpu_memory_total=total_gpu_memory,
            gpu_util_avg=avg_gpu_util,
            cpu_cores_utilized=results['cpu_usage']['per_core']['cores_utilized'],
            cpu_cores_total=cpu_info['logical_cores'],
            inference_time=inference_time
        )
        
        print(f"✓ GPU Memory - Initial: {initial_gpu_memory:.1f} MB")
        print(f"✓ GPU Memory - Peak: {peak_gpu_memory_mb:.1f} MB")
        print(f"✓ GPU Memory - Used: {results['gpu_memory']['used_mb']:.1f} MB")
        if total_gpu_memory:
            print(f"✓ GPU Memory - Total: {total_gpu_memory:.1f} MB ({results['gpu_memory']['utilization_percent']['peak']:.1f}% peak utilization)")
        print(f"✓ GPU Compute - Average: {avg_gpu_util:.1f}%, Peak: {max_gpu_util:.1f}%")
        print(f"✓ CPU Usage - Process Average: {avg_cpu:.1f}%, Peak: {max_cpu:.1f}%")
        print(f"✓ CPU Usage - System: {initial_system_cpu:.1f}% → {final_system_cpu:.1f}%")
        print(f"✓ CPU Cores - Utilized: {results['cpu_usage']['per_core']['cores_utilized']}/{cpu_info['logical_cores']}")
        print(f"✓ Inference Time: {inference_time:.3f}s")
        print(f"\n📊 Concurrency Analysis:")
        print(f"   Recommended instances: {results['concurrency_analysis']['recommended_instances']}")
        print(f"   Bottleneck: {results['concurrency_analysis']['bottleneck']}")
    else:
        results['note'] = "Test image not found - using placeholder values"
        results['gpu_memory'] = {"used_mb": "TBD"}
        results['cpu_usage'] = {"peak_percent": "TBD"}
    
    return results

def calculate_concurrency_recommendations(
    gpu_memory_used: float,
    gpu_memory_total: float,
    gpu_util_avg: float,
    cpu_cores_utilized: int,
    cpu_cores_total: int,
    inference_time: float
) -> dict:
    """Calculate recommended concurrency based on resource usage"""
    
    recommendations = {
        "recommended_instances": 1,
        "bottleneck": "unknown",
        "reasoning": []
    }
    
    # GPU Memory-based concurrency
    if gpu_memory_total and gpu_memory_used:
        memory_based_instances = int(gpu_memory_total / gpu_memory_used * 0.8)  # 80% safety margin
        recommendations['memory_based_instances'] = max(1, memory_based_instances)
        recommendations['reasoning'].append(f"GPU memory allows ~{memory_based_instances} instances (80% safety)")
    else:
        memory_based_instances = 1
    
    # GPU Compute-based concurrency
    if gpu_util_avg < 50:
        compute_based_instances = int(100 / max(gpu_util_avg, 1))  # Can handle more if underutilized
        recommendations['compute_based_instances'] = max(1, min(compute_based_instances, 4))  # Cap at 4
        recommendations['reasoning'].append(f"GPU compute underutilized ({gpu_util_avg:.1f}%), can handle more instances")
    elif gpu_util_avg < 80:
        compute_based_instances = 2
        recommendations['compute_based_instances'] = 2
        recommendations['reasoning'].append(f"GPU compute moderately utilized ({gpu_util_avg:.1f}%), 2 instances recommended")
    else:
        compute_based_instances = 1
        recommendations['compute_based_instances'] = 1
        recommendations['reasoning'].append(f"GPU compute highly utilized ({gpu_util_avg:.1f}%), single instance recommended")
    
    # CPU-based concurrency
    if cpu_cores_utilized < cpu_cores_total * 0.5:
        cpu_based_instances = int(cpu_cores_total / max(cpu_cores_utilized, 1))
        recommendations['cpu_based_instances'] = max(1, min(cpu_based_instances, 8))  # Cap at 8
        recommendations['reasoning'].append(f"CPU underutilized ({cpu_cores_utilized}/{cpu_cores_total} cores), can handle more")
    else:
        cpu_based_instances = 1
        recommendations['cpu_based_instances'] = 1
        recommendations['reasoning'].append(f"CPU well utilized ({cpu_cores_utilized}/{cpu_cores_total} cores)")
    
    # Determine bottleneck and recommended instances
    recommended_instances = min(memory_based_instances, compute_based_instances, cpu_based_instances)
    
    if recommended_instances == memory_based_instances:
        recommendations['bottleneck'] = "gpu_memory"
    elif recommended_instances == compute_based_instances:
        recommendations['bottleneck'] = "gpu_compute"
    else:
        recommendations['bottleneck'] = "cpu"
    
    recommendations['recommended_instances'] = recommended_instances
    
    return recommendations

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
            "recommended_instance_count": test_results['resource_profiling'].get('concurrency_analysis', {}).get('recommended_instances', 1),
            "recommended_max_batch_size": 1,  # Will be updated after batch testing
            "dynamic_batching": False,  # Will be updated
            "model_sharing": "shared",
            "concurrency_analysis": test_results['resource_profiling'].get('concurrency_analysis', {})
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

