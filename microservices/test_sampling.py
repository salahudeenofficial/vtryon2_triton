#!/usr/bin/env python3
"""
Test script for sampling service - Phase 2 information extraction
"""

import sys
import os
import json
import time
import torch
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "sampling"))

from service import sample_latent
from config import Config

def test_basic_functionality():
    """Test basic functionality and extract tensor info"""
    print("=" * 60)
    print("Test 1: Basic Functionality - Sampling")
    print("=" * 60)
    
    # These would come from previous services
    test_positive = "test_results/text_encoder/positive.pt"
    test_negative = "test_results/text_encoder/negative.pt"
    test_latent = "test_results/latent_encoder/latent.pt"
    
    results = {
        "test_name": "basic_functionality",
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
    }
    
    try:
        result = sample_latent(
            positive_encoding=test_positive,
            negative_encoding=test_negative,
            latent_image=test_latent,
            save_tensor=False
        )
        
        if result['status'] == 'success':
            sampled_tensor = result.get('sampled_latent_tensor')
            
            results['inputs'] = {
                "positive_encoding": {"type": "tensor_file", "format": "STRING"},
                "negative_encoding": {"type": "tensor_file", "format": "STRING"},
                "latent_image": {"type": "tensor_file", "format": "STRING"},
                "seed": {"type": "INT64", "optional": True}
            }
            
            results['output'] = {
                "name": "sampled_latent",
                "shape": list(sampled_tensor.shape) if sampled_tensor is not None else None,
                "data_type": str(sampled_tensor.dtype) if sampled_tensor is not None else None,
                "triton_type": "TYPE_FP32"
            }
            
            results['status'] = 'success'
            print(f"✓ Output shape: {results['output']['shape']}")
        else:
            results['status'] = 'error'
            results['error'] = result.get('error_message', 'Unknown error')
    except Exception as e:
        results['status'] = 'error'
        results['error'] = str(e)
    
    return results

def main():
    """Run tests and generate TRITON_CONFIG_DATA.json"""
    print("=" * 60)
    print("Sampling - Phase 2 Information Extraction")
    print("=" * 60)
    print()
    
    test_results = {'basic_functionality': test_basic_functionality()}
    
    config_data = {
        "service": "sampling",
        "extraction_timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "tensor_info": {
            "inputs": test_results['basic_functionality'].get('inputs', {}),
            "output": test_results['basic_functionality'].get('output', {})
        },
        "model_files": {
            "unet": "shared_models/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors",
            "lora": "shared_models/loras/Qwen-Image-Lightning-4steps-V2.0.safetensors"
        }
    }
    
    output_dir = Path("test_results/sampling")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    with open(output_dir / "test_results.json", 'w') as f:
        json.dump(test_results, f, indent=2)
    
    with open(output_dir / "TRITON_CONFIG_DATA.json", 'w') as f:
        json.dump(config_data, f, indent=2)
    
    print("\n✓ Results saved to test_results/sampling/")

if __name__ == "__main__":
    main()

