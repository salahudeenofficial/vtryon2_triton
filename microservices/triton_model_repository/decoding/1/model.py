"""
Triton Python Backend Model for Decoding

This model decodes latent tensors to images using VAE decoder.
Input: latent (FP32 tensor)
Output: image (FP32 tensor)
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
from service import decode_latent_to_image
from config import Config


class TritonPythonModel:
    def initialize(self, args):
        """Initialize the model - setup ComfyUI paths."""
        self.logger = pb_utils.Logger
        self.logger.log_info("Initializing decoding model...")
        
        # Store model directory for path resolution
        self.model_dir = model_dir
        
        # ComfyUI will be initialized when service is called
        self.logger.log_info("✓ Decoding model initialized")
    
    def execute(self, requests):
        """Execute inference requests."""
        responses = []
        
        for request in requests:
            try:
                # Get input tensor (latent)
                latent_tensor = pb_utils.get_input_tensor_by_name(request, "latent")
                
                if latent_tensor is None:
                    error_response = pb_utils.InferenceResponse(
                        output_tensors=[],
                        error=pb_utils.TritonError("Missing input: latent")
                    )
                    responses.append(error_response)
                    continue
                
                # Extract tensor from Triton format
                latent_np = latent_tensor.as_numpy().astype(np.float32)
                
                # Convert to PyTorch tensor
                latent_pt = torch.from_numpy(latent_np)
                
                # Add batch dimension if not present
                if len(latent_pt.shape) == 4:
                    latent_pt = latent_pt.unsqueeze(0) if latent_pt.shape[0] != 1 else latent_pt
                
                # Call service function
                result = decode_latent_to_image(
                    latent=latent_pt,
                    save_image=False  # Don't save, just return tensor
                )
                
                if result['status'] == 'error':
                    error_response = pb_utils.InferenceResponse(
                        output_tensors=[],
                        error=pb_utils.TritonError(f"Service error: {result.get('error_message', 'Unknown error')}")
                    )
                    responses.append(error_response)
                    continue
                
                # Get image tensor from result
                image_tensor = result['image_tensor']
                
                # Convert to numpy and ensure correct dtype
                image_np = image_tensor.detach().cpu().numpy().astype(np.float32)
                
                # Remove batch dimension if present
                if len(image_np.shape) > 3 and image_np.shape[0] == 1:
                    image_np = image_np[0]
                
                # Create output tensor
                output_tensor = pb_utils.Tensor("image", image_np)
                
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
        self.logger.log_info("Finalizing decoding model...")
        # Cleanup if needed (models are loaded per-request in service)
