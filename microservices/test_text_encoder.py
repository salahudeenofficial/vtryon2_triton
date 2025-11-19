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
    print("Test 1: Basic Functionality - Text Encoder")
    print("=" * 60)
    
    test_image1 = "test_data/images/person.jpg"
    test_image2 = "test_data/images/cloth.jpg"
    test_prompt = "将图片 1 中的绿色遮罩区域仅用于判断服装属于上半身或下半身，不要将服装限制在遮罩范围内。\n\n将图片 2 中的服装自然地穿戴到图片 1 中的人物身上，保持图片 2 中服装的完整形状、袖长和轮廓。无论图片 2 是单独的服装图还是人物穿着该服装的图，都应准确地转移服装，同时保留其原始面料质感、材质细节和颜色准确性。\n\n确保图片 1 中人物的面部、头发和皮肤完全保持不变。光照与阴影应自然匹配图片 1 的环境，但服装的材质外观必须忠实于图片 2。\n\n保持边缘平滑融合、阴影逼真，整体效果自然且不改变人物的身份特征。"
    
    results = {
        "test_name": "basic_functionality",
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
    }
    
    # Load expected tensors if available
    expected_positive_path = Path("test_outputs/text_encoder_positive_output.pt")
    expected_negative_path = Path("test_outputs/text_encoder_negative_output.pt")
    expected_positive = None
    expected_negative = None
    
    if expected_positive_path.exists():
        try:
            expected_positive = torch.load(expected_positive_path)
            print(f"✓ Loaded expected positive tensor from: {expected_positive_path}")
            print(f"  Expected shape: {expected_positive.shape}, dtype: {expected_positive.dtype}")
        except Exception as e:
            print(f"⚠️  Could not load expected positive tensor: {e}")
    else:
        print(f"⚠️  Expected positive tensor not found: {expected_positive_path}")
    
    if expected_negative_path.exists():
        try:
            expected_negative = torch.load(expected_negative_path)
            print(f"✓ Loaded expected negative tensor from: {expected_negative_path}")
            print(f"  Expected shape: {expected_negative.shape}, dtype: {expected_negative.dtype}")
        except Exception as e:
            print(f"⚠️  Could not load expected negative tensor: {e}")
    else:
        print(f"⚠️  Expected negative tensor not found: {expected_negative_path}")
    
    if not expected_positive_path.exists() or not expected_negative_path.exists():
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
                
                if comparison_pos['within_tolerance']:
                    print(f"✓ Positive encoding matches expected (max diff: {comparison_pos['max_diff']:.2e})")
                else:
                    print(f"⚠️  Positive encoding differs (max diff: {comparison_pos['max_diff']:.2e})")
            
            if expected_negative is not None and neg_tensor is not None:
                comparison_neg = compare_tensors(neg_tensor, expected_negative)
                results['comparison_negative'] = comparison_neg
                
                if comparison_neg['within_tolerance']:
                    print(f"✓ Negative encoding matches expected (max diff: {comparison_neg['max_diff']:.2e})")
                else:
                    print(f"⚠️  Negative encoding differs (max diff: {comparison_neg['max_diff']:.2e})")
            
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
    test_image1 = "test_data/images/person.jpg"
    test_image2 = "test_data/images/cloth.jpg"
    test_prompt = "将图片 1 中的绿色遮罩区域仅用于判断服装属于上半身或下半身，不要将服装限制在遮罩范围内。\n\n将图片 2 中的服装自然地穿戴到图片 1 中的人物身上，保持图片 2 中服装的完整形状、袖长和轮廓。无论图片 2 是单独的服装图还是人物穿着该服装的图，都应准确地转移服装，同时保留其原始面料质感、材质细节和颜色准确性。\n\n确保图片 1 中人物的面部、头发和皮肤完全保持不变。光照与阴影应自然匹配图片 1 的环境，但服装的材质外观必须忠实于图片 2。\n\n保持边缘平滑融合、阴影逼真，整体效果自然且不改变人物的身份特征。"
    
    if os.path.exists(test_image1) and os.path.exists(test_image2):
        # Monitor CPU during inference
        cpu_samples = []
        def monitor_cpu():
            while True:
                cpu_samples.append(process.cpu_percent(interval=0.1))
                time.sleep(0.1)
        
        monitor_thread = threading.Thread(target=monitor_cpu, daemon=True)
        monitor_thread.start()
        
        start_time = time.time()
        result = encode_text_and_images(
            image1_path=test_image1,
            image2_path=test_image2,
            prompt=test_prompt,
            save_tensor=False
        )
        inference_time = time.time() - start_time
        
        # Stop monitoring
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
            "recommended_instance_count": 1,
            "recommended_max_batch_size": 1,
            "dynamic_batching": False,
            "model_sharing": "shared"
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
