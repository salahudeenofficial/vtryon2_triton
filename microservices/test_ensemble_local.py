#!/usr/bin/env python3
"""
Test the complete ensemble pipeline locally (without Triton).

This script tests the full pipeline by calling each service directly
to ensure everything works before building Docker image.
"""

import sys
import os
from pathlib import Path
import torch
import time

# Add paths
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

# Import service functions
sys.path.insert(0, str(Path(__file__).parent / "triton_model_repository" / "latent_encoder" / "1"))
sys.path.insert(0, str(Path(__file__).parent / "triton_model_repository" / "text_encoder" / "1"))
sys.path.insert(0, str(Path(__file__).parent / "triton_model_repository" / "sampling" / "1"))
sys.path.insert(0, str(Path(__file__).parent / "triton_model_repository" / "decoding" / "1"))

from latent_encoder.service import encode_image_to_latent
from text_encoder.service import encode_text_and_images
from sampling.service import sample_latent
from decoding.service import decode_latent_to_image


def test_ensemble_pipeline(image1_path: str, image2_path: str, prompt: str):
    """Test complete ensemble pipeline."""
    print("=" * 60)
    print("Testing Complete Ensemble Pipeline")
    print("=" * 60)
    print()
    
    results = {}
    
    # Step 1: Latent Encoder
    print("Step 1: Encoding image1 to latent...")
    start_time = time.time()
    try:
        latent_result = encode_image_to_latent(
            image_path=image1_path,
            save_tensor=False
        )
        if latent_result['status'] != 'success':
            raise Exception(f"Latent encoding failed: {latent_result.get('error_message')}")
        latent_tensor = latent_result['latent_tensor']
        results['latent'] = latent_tensor
        print(f"✓ Latent encoded: shape {latent_tensor.shape}")
        print(f"  Time: {time.time() - start_time:.2f}s")
    except Exception as e:
        print(f"✗ Latent encoding failed: {e}")
        import traceback
        traceback.print_exc()
        return None
    print()
    
    # Step 2: Text Encoder
    print("Step 2: Encoding text and images...")
    start_time = time.time()
    try:
        text_result = encode_text_and_images(
            image1_path=image1_path,
            image2_path=image2_path,
            prompt=prompt,
            negative_prompt="",
            save_tensor=False
        )
        if text_result['status'] != 'success':
            raise Exception(f"Text encoding failed: {text_result.get('error_message')}")
        positive_encoding = text_result['positive_encoding_tensor']
        negative_encoding = text_result['negative_encoding_tensor']
        results['positive_encoding'] = positive_encoding
        results['negative_encoding'] = negative_encoding
        print(f"✓ Text encoded: positive {positive_encoding.shape}, negative {negative_encoding.shape}")
        print(f"  Time: {time.time() - start_time:.2f}s")
    except Exception as e:
        print(f"✗ Text encoding failed: {e}")
        import traceback
        traceback.print_exc()
        return None
    print()
    
    # Step 3: Sampling
    print("Step 3: Sampling latent...")
    start_time = time.time()
    try:
        sampling_result = sample_latent(
            positive_encoding=positive_encoding,
            negative_encoding=negative_encoding,
            latent_image=latent_tensor,
            seed=724723345395306,
            steps=4,
            cfg=1.0,
            save_tensor=False
        )
        if sampling_result['status'] != 'success':
            raise Exception(f"Sampling failed: {sampling_result.get('error_message')}")
        sampled_latent = sampling_result['sampled_latent_tensor']
        results['sampled_latent'] = sampled_latent
        print(f"✓ Sampling complete: shape {sampled_latent.shape}")
        print(f"  Time: {time.time() - start_time:.2f}s")
    except Exception as e:
        print(f"✗ Sampling failed: {e}")
        import traceback
        traceback.print_exc()
        return None
    print()
    
    # Step 4: Decoding
    print("Step 4: Decoding latent to image...")
    start_time = time.time()
    try:
        decode_result = decode_latent_to_image(
            latent=sampled_latent,
            save_image=False
        )
        if decode_result['status'] != 'success':
            raise Exception(f"Decoding failed: {decode_result.get('error_message')}")
        image_tensor = decode_result['image_tensor']
        results['image'] = image_tensor
        print(f"✓ Decoding complete: shape {image_tensor.shape}")
        print(f"  Time: {time.time() - start_time:.2f}s")
    except Exception as e:
        print(f"✗ Decoding failed: {e}")
        import traceback
        traceback.print_exc()
        return None
    print()
    
    print("=" * 60)
    print("✓ Ensemble Pipeline Test Complete!")
    print("=" * 60)
    print()
    print("All services working correctly!")
    
    return results


if __name__ == "__main__":
    # Test image paths (adjust as needed)
    image1_path = "input/person.jpg"  # Person image
    image2_path = "input/cloth.jpg"  # Clothing image
    prompt = "a photo of a person"
    
    # Check if images exist
    if not Path(image1_path).exists():
        print(f"Error: Image not found: {image1_path}")
        print("Please provide valid image paths")
        sys.exit(1)
    
    if not Path(image2_path).exists():
        print(f"Error: Image not found: {image2_path}")
        print("Please provide valid image paths")
        sys.exit(1)
    
    # Run test
    results = test_ensemble_pipeline(image1_path, image2_path, prompt)
    
    if results:
        print("\n✓ All tests passed! Ready for Docker build.")
        sys.exit(0)
    else:
        print("\n✗ Tests failed. Fix issues before building Docker image.")
        sys.exit(1)

