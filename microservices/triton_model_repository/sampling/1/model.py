"""
Triton Python Backend Model for Sampling

This model performs diffusion sampling using text encodings and latent image.
Inputs: positive_encoding (FP32), negative_encoding (FP32), latent_image (FP32), seed (INT64)
Output: sampled_latent (FP32 tensor)
"""

import triton_python_backend_utils as pb_utils
import sys
import os
import numpy as np
import torch
from pathlib import Path

# Setup paths for ComfyUI and service code
model_dir = Path(pb_utils.get_model_dir())
comfyui_path = model_dir.parent.parent / "shared_comfyui"
sys.path.insert(0, str(comfyui_path))
sys.path.insert(0, str(model_dir))

# Import service functions
from service import sample_latent
from config import Config


class TritonPythonModel:
    def initialize(self, args):
        """Initialize the model - setup ComfyUI paths."""
        self.logger = pb_utils.Logger
        self.logger.log_info("Initializing sampling model...")
        
        # Store model directory for path resolution
        self.model_dir = model_dir
        
        # ComfyUI will be initialized when service is called
        self.logger.log_info("✓ Sampling model initialized")
    
    def execute(self, requests):
        """Execute inference requests."""
        responses = []
        
        for request in requests:
            try:
                # Get input tensors
                positive_tensor = pb_utils.get_input_tensor_by_name(request, "positive_encoding")
                negative_tensor = pb_utils.get_input_tensor_by_name(request, "negative_encoding")
                latent_tensor = pb_utils.get_input_tensor_by_name(request, "latent_image")
                seed_tensor = pb_utils.get_input_tensor_by_name(request, "seed")
                
                if positive_tensor is None or negative_tensor is None or latent_tensor is None:
                    error_response = pb_utils.InferenceResponse(
                        output_tensors=[],
                        error=pb_utils.TritonError("Missing required inputs")
                    )
                    responses.append(error_response)
                    continue
                
                # Extract tensors from Triton format
                positive_np = positive_tensor.as_numpy().astype(np.float32)
                negative_np = negative_tensor.as_numpy().astype(np.float32)
                latent_np = latent_tensor.as_numpy().astype(np.float32)
                
                # Convert to PyTorch tensors
                positive_pt = torch.from_numpy(positive_np)
                negative_pt = torch.from_numpy(negative_np)
                latent_pt = torch.from_numpy(latent_np)
                
                # Add batch dimension if not present
                if len(positive_pt.shape) == 2:
                    positive_pt = positive_pt.unsqueeze(0)
                if len(negative_pt.shape) == 2:
                    negative_pt = negative_pt.unsqueeze(0)
                if len(latent_pt.shape) == 4:
                    latent_pt = latent_pt.unsqueeze(0) if latent_pt.shape[0] != 1 else latent_pt
                
                # Extract seed
                seed = None
                if seed_tensor is not None:
                    seed = int(seed_tensor.as_numpy().item())
                
                # Call service function
                result = sample_latent(
                    positive_encoding=positive_pt,
                    negative_encoding=negative_pt,
                    latent_image=latent_pt,
                    seed=seed,
                    steps=4,
                    cfg=1.0,
                    save_tensor=False  # Don't save, just return tensor
                )
                
                if result['status'] == 'error':
                    error_response = pb_utils.InferenceResponse(
                        output_tensors=[],
                        error=pb_utils.TritonError(f"Service error: {result.get('error_message', 'Unknown error')}")
                    )
                    responses.append(error_response)
                    continue
                
                # Get sampled latent tensor from result
                sampled_tensor = result['sampled_latent_tensor']
                
                # Convert to numpy and ensure correct dtype
                sampled_np = sampled_tensor.detach().cpu().numpy().astype(np.float32)
                
                # Remove batch dimension if present
                if len(sampled_np.shape) > 4 and sampled_np.shape[0] == 1:
                    sampled_np = sampled_np[0]
                
                # Create output tensor
                output_tensor = pb_utils.Tensor("sampled_latent", sampled_np)
                
                # Create response
                inference_response = pb_utils.InferenceResponse([output_tensor])
                responses.append(inference_response)
                
            except Exception as e:
                self.logger.log_error(f"Error processing request: {e}")
                import traceback
                self.logger.log_error(traceback.format_exc())
                error_response = pb_utils.InferenceResponse(
                    output_tensors=[],
                    error=pb_utils.TritonError(f"Execution error: {str(e)}")
                )
                responses.append(error_response)
        
        return responses
    
    def finalize(self):
        """Cleanup resources."""
        self.logger.log_info("Finalizing sampling model...")
        # Cleanup if needed (models are loaded per-request in service)
