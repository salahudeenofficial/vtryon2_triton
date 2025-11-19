#!/usr/bin/env python3
"""
Test script for text_encoder service - Phase 2 information extraction
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

sys.path.insert(0, str(Path(__file__).parent / "text_encoder"))

from service import encode_text_and_images
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
        memory_based_instances = int(gpu_memory_total / gpu_memory_used * 0.8)
        recommendations['memory_based_instances'] = max(1, memory_based_instances)
        recommendations['reasoning'].append(f"GPU memory allows ~{memory_based_instances} instances (80% safety)")
    else:
        memory_based_instances = 1
    
    # GPU Compute-based concurrency
    if gpu_util_avg < 50:
        compute_based_instances = int(100 / max(gpu_util_avg, 1))
        recommendations['compute_based_instances'] = max(1, min(compute_based_instances, 4))
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
        recommendations['cpu_based_instances'] = max(1, min(cpu_based_instances, 8))
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
    print("Test 1: Basic Functionality - Text Encoder")
    print("=" * 60)
    
    test_image1 = "test_data/images/person.jpg"
    test_image2 = "test_data/images/cloth.jpg"
    test_prompt = "将图片 1 中的绿色遮罩区域仅用于判断服装属于上半身或下半身，不要将服装限制在遮罩范围内。\n\n将图片 2 中的服装自然地穿戴到图片 1 中的人物身上，保持图片 2 中服装的完整形状、袖长和轮廓。无论图片 2 是单独的服装图还是人物穿着该服装的图，都应准确地转移服装，同时保留其原始面料质感、材质细节和颜色准确性。\n\n确保图片 1 中人物的面部、头发和皮肤完全保持不变。光照与阴影应自然匹配图片 1 的环境，但服装的材质外观必须忠实于图片 2。\n\n保持边缘平滑融合、阴影逼真，整体效果自然且不改变人物的身份特征。"
    
    results = {
        "test_name": "basic_functionality",
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
    }
    
    # Load expected tensors if available (check both current dir and parent dir)
    expected_paths = [
        Path("test_outputs"),
        Path("../test_outputs"),
        Path(__file__).parent.parent / "test_outputs"
    ]
    expected_positive = None
    expected_negative = None
    expected_positive_path = None
    expected_negative_path = None
    
    for base_path in expected_paths:
        pos_path = base_path / "text_encoder_positive_output.pt"
        neg_path = base_path / "text_encoder_negative_output.pt"
        
        if pos_path.exists() and expected_positive is None:
            try:
                expected_positive = torch.load(pos_path)
                expected_positive_path = pos_path
                print(f"✓ Loaded expected positive tensor from: {pos_path}")
                print(f"  Expected shape: {expected_positive.shape}, dtype: {expected_positive.dtype}")
            except Exception as e:
                print(f"⚠️  Could not load expected positive tensor from {pos_path}: {e}")
        
        if neg_path.exists() and expected_negative is None:
            try:
                expected_negative = torch.load(neg_path)
                expected_negative_path = neg_path
                print(f"✓ Loaded expected negative tensor from: {neg_path}")
                print(f"  Expected shape: {expected_negative.shape}, dtype: {expected_negative.dtype}")
            except Exception as e:
                print(f"⚠️  Could not load expected negative tensor from {neg_path}: {e}")
    
    if expected_positive is None or expected_negative is None:
        print("   Run workflow_script_serial_test.py first to generate expected outputs")
    
    try:
        result = encode_text_and_images(
            image1_path=test_image1,
            image2_path=test_image2,
            prompt=test_prompt,
            save_tensor=False
        )
        
        if result['status'] == 'success':
            # Extract tensor information
            results['inputs'] = {
                "image1": {
                    "type": "image_file_path",
                    "format": "STRING"
                },
                "image2": {
                    "type": "image_file_path",
                    "format": "STRING"
                },
                "prompt": {
                    "type": "text",
                    "format": "STRING"
                }
            }
            
            pos_tensor = result.get('positive_encoding_tensor')
            neg_tensor = result.get('negative_encoding_tensor')
            
            results['outputs'] = {
                "positive_encoding": {
                    "name": "positive_encoding",
                    "shape": list(pos_tensor.shape) if pos_tensor is not None else None,
                    "data_type": str(pos_tensor.dtype) if pos_tensor is not None else None,
                    "triton_type": "TYPE_FP32" if pos_tensor is not None and pos_tensor.dtype == torch.float32 else None
                },
                "negative_encoding": {
                    "name": "negative_encoding",
                    "shape": list(neg_tensor.shape) if neg_tensor is not None else None,
                    "data_type": str(neg_tensor.dtype) if neg_tensor is not None else None,
                    "triton_type": "TYPE_FP32" if neg_tensor is not None and neg_tensor.dtype == torch.float32 else None
                }
            }
            
            # Compare with expected tensors if available
            if expected_positive is not None and pos_tensor is not None:
                comparison_pos = compare_tensors(pos_tensor, expected_positive)
                results['comparison_positive'] = comparison_pos
                
                if comparison_pos['shapes_match'] and comparison_pos['dtypes_match']:
                    if comparison_pos['within_tolerance']:
                        print(f"✓ Positive encoding matches expected (max diff: {comparison_pos['max_diff']:.2e})")
                    else:
                        print(f"⚠️  Positive encoding differs (max diff: {comparison_pos['max_diff']:.2e})")
                else:
                    print(f"⚠️  Positive encoding cannot be compared:")
                    if not comparison_pos['shapes_match']:
                        print(f"   Shape mismatch: actual {pos_tensor.shape} vs expected {expected_positive.shape}")
                    if not comparison_pos['dtypes_match']:
                        print(f"   Dtype mismatch: actual {pos_tensor.dtype} vs expected {expected_positive.dtype}")
            
            if expected_negative is not None and neg_tensor is not None:
                comparison_neg = compare_tensors(neg_tensor, expected_negative)
                results['comparison_negative'] = comparison_neg
                
                if comparison_neg['shapes_match'] and comparison_neg['dtypes_match']:
                    if comparison_neg['within_tolerance']:
                        print(f"✓ Negative encoding matches expected (max diff: {comparison_neg['max_diff']:.2e})")
                    else:
                        print(f"⚠️  Negative encoding differs (max diff: {comparison_neg['max_diff']:.2e})")
                else:
                    print(f"⚠️  Negative encoding cannot be compared:")
                    if not comparison_neg['shapes_match']:
                        print(f"   Shape mismatch: actual {neg_tensor.shape} vs expected {expected_negative.shape}")
                    if not comparison_neg['dtypes_match']:
                        print(f"   Dtype mismatch: actual {neg_tensor.dtype} vs expected {expected_negative.dtype}")
            
            results['metadata'] = result.get('metadata', {})
            results['status'] = 'success'
            
            print(f"✓ Positive encoding shape: {results['outputs']['positive_encoding']['shape']}")
            print(f"✓ Negative encoding shape: {results['outputs']['negative_encoding']['shape']}")
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
    """Test 2: Resource profiling with comprehensive metrics for concurrency analysis"""
    print("\n" + "=" * 60)
    print("Test 2: Resource Profiling")
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
    initial_system_cpu = psutil.cpu_percent(interval=0.1)
    
    # Run inference
    test_image1 = "test_data/images/person.jpg"
    test_image2 = "test_data/images/cloth.jpg"
    # Use the same prompt as workflow_script_serial_test.py to match expected outputs
    test_prompt = "by using the green masked area from Picture 3 as a reference for position place the garment from Picture 2 on the person from Picture 1."
    
    if os.path.exists(test_image1) and os.path.exists(test_image2):
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
        
        monitor_thread = threading.Thread(target=monitor_resources, daemon=True)
        monitor_thread.start()
        
        start_time = time.time()
        result = encode_text_and_images(
            image1_path=test_image1,
            image2_path=test_image2,
            prompt=test_prompt,
            save_tensor=False
        )
        inference_time = time.time() - start_time
        
        time.sleep(0.2)
        
        # Get peak GPU metrics
        if torch.cuda.is_available():
            peak_gpu_memory_mb = torch.cuda.max_memory_allocated() / (1024 * 1024)
            current_gpu_memory = get_gpu_memory()
            total_gpu_memory = torch.cuda.get_device_properties(0).total_memory / (1024 * 1024)
        else:
            peak_gpu_memory_mb = get_gpu_memory()
            current_gpu_memory = peak_gpu_memory_mb
            total_gpu_memory = None
        
        # Calculate statistics
        # Normalize CPU usage (process.cpu_percent can be >100% on multi-core)
        if cpu_samples:
            avg_cpu = sum(cpu_samples) / len(cpu_samples) / cpu_info['logical_cores'] * 100
            max_cpu = max(cpu_samples) / cpu_info['logical_cores'] * 100
            avg_cpu = min(avg_cpu, 100.0)
            max_cpu = min(max_cpu, 100.0)
        else:
            cpu_pct = process.cpu_percent(interval=0.1)
            avg_cpu = min(cpu_pct / cpu_info['logical_cores'] * 100, 100.0)
            max_cpu = avg_cpu
        
        # Per-core CPU analysis
        if per_core_samples:
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
                "cores_utilized": len([x for x in max_per_core if x > 10])
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
        results['note'] = "Test images not found"
        results['gpu_memory'] = {"used_mb": "TBD"}
        results['cpu_usage'] = {"peak_percent": "TBD"}
    
    return results

def main():
    """Run all tests and generate TRITON_CONFIG_DATA.json"""
    print("=" * 60)
    print("Text Encoder - Phase 2 Information Extraction")
    print("=" * 60)
    print()
    
    test_results = {}
    test_results['basic_functionality'] = test_basic_functionality()
    test_results['resource_profiling'] = test_resource_usage()
    
    # Compile config data
    config_data = {
        "service": "text_encoder",
        "extraction_timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "tensor_info": {
            "inputs": test_results['basic_functionality'].get('inputs', {}),
            "outputs": test_results['basic_functionality'].get('outputs', {})
        },
        "resource_requirements": test_results['resource_profiling'].get('gpu_memory', {}),
        "performance": {
            "inference_time_ms": test_results['resource_profiling'].get('inference_time_seconds', 0) * 1000
        },
        "output_verification": {
            "expected_positive_path": "test_outputs/text_encoder_positive_output.pt",
            "expected_negative_path": "test_outputs/text_encoder_negative_output.pt",
            "comparison_positive": test_results['basic_functionality'].get('comparison_positive', {}),
            "comparison_negative": test_results['basic_functionality'].get('comparison_negative', {})
        },
        "model_files": {
            "clip": "shared_models/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors",
            "vae": "shared_models/vae/qwen_image_vae.safetensors"
        },
        "triton_config": {
            "recommended_instance_count": test_results['resource_profiling'].get('concurrency_analysis', {}).get('recommended_instances', 1),
            "recommended_max_batch_size": 1,
            "dynamic_batching": False,
            "model_sharing": "shared",
            "concurrency_analysis": test_results['resource_profiling'].get('concurrency_analysis', {})
        }
    }
    
    # Save results
    output_dir = Path("test_results/text_encoder")
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
