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

sys.path.insert(0, str(Path(__file__).parent / "text_encoder"))

from service import encode_text_and_images
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
    print("Test 1: Basic Functionality - Text Encoder")
    print("=" * 60)
    
    test_image1 = "test_data/images/person.jpg"
    test_image2 = "test_data/images/cloth.jpg"
    test_prompt = "将图片 1 中的绿色遮罩区域仅用于判断服装属于上半身或下半身，不要将服装限制在遮罩范围内。\n\n将图片 2 中的服装自然地穿戴到图片 1 中的人物身上，保持图片 2 中服装的完整形状、袖长和轮廓。无论图片 2 是单独的服装图还是人物穿着该服装的图，都应准确地转移服装，同时保留其原始面料质感、材质细节和颜色准确性。\n\n确保图片 1 中人物的面部、头发和皮肤完全保持不变。光照与阴影应自然匹配图片 1 的环境，但服装的材质外观必须忠实于图片 2。\n\n保持边缘平滑融合、阴影逼真，整体效果自然且不改变人物的身份特征。"
    
    results = {
        "test_name": "basic_functionality",
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
    }
    
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
            
            results['metadata'] = result.get('metadata', {})
            results['status'] = 'success'
            
            print(f"✓ Positive encoding shape: {results['outputs']['positive_encoding']['shape']}")
            print(f"✓ Negative encoding shape: {results['outputs']['negative_encoding']['shape']}")
        else:
            results['status'] = 'error'
            results['error'] = result.get('error_message', 'Unknown error')
            
    except Exception as e:
        results['status'] = 'error'
        results['error'] = str(e)
    
    return results

def main():
    """Run all tests and generate TRITON_CONFIG_DATA.json"""
    print("=" * 60)
    print("Text Encoder - Phase 2 Information Extraction")
    print("=" * 60)
    print()
    
    test_results = {}
    test_results['basic_functionality'] = test_basic_functionality()
    
    # Compile config data
    config_data = {
        "service": "text_encoder",
        "extraction_timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "tensor_info": {
            "inputs": test_results['basic_functionality'].get('inputs', {}),
            "outputs": test_results['basic_functionality'].get('outputs', {})
        },
        "model_files": {
            "clip": "shared_models/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors",
            "vae": "shared_models/vae/qwen_image_vae.safetensors"
        }
    }
    
    # Save results
    output_dir = Path("test_results/text_encoder")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    with open(output_dir / "test_results.json", 'w') as f:
        json.dump(test_results, f, indent=2)
    
    with open(output_dir / "TRITON_CONFIG_DATA.json", 'w') as f:
        json.dump(config_data, f, indent=2)
    
    print("\n✓ Results saved to test_results/text_encoder/")

if __name__ == "__main__":
    main()

