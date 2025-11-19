#!/usr/bin/env python3
"""
Test script for decoding service - Phase 2 information extraction
"""

import sys
import os
import json
import time
import torch
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "decoding"))

from service import decode_latent_to_image
from config import Config

def test_basic_functionality():
    """Test basic functionality and extract tensor info"""
    print("=" * 60)
    print("Test 1: Basic Functionality - Decoding")
    print("=" * 60)
    
    test_latent = "test_results/sampling/sampled_latent.pt"
    
    results = {
        "test_name": "basic_functionality",
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
    }
    
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
    print("Decoding - Phase 2 Information Extraction")
    print("=" * 60)
    print()
    
    test_results = {'basic_functionality': test_basic_functionality()}
    
    config_data = {
        "service": "decoding",
        "extraction_timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "tensor_info": {
            "input": test_results['basic_functionality'].get('input', {}),
            "output": test_results['basic_functionality'].get('output', {})
        },
        "model_files": {
            "vae_decoder": "shared_models/vae/qwen_image_vae.safetensors"
        }
    }
    
    output_dir = Path("test_results/decoding")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    with open(output_dir / "test_results.json", 'w') as f:
        json.dump(test_results, f, indent=2)
    
    with open(output_dir / "TRITON_CONFIG_DATA.json", 'w') as f:
        json.dump(config_data, f, indent=2)
    
    print("\n✓ Results saved to test_results/decoding/")

if __name__ == "__main__":
    main()

