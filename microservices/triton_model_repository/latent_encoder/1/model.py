"""
Triton Python Backend Model for Latent Encoder

This model encodes images to latent space using VAE encoder.
Input: image_path (STRING)
Output: latent (FP32 tensor)
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
from service import encode_image_to_latent
from config import Config


class TritonPythonModel:
    def initialize(self, args):
        """Initialize the model - setup ComfyUI paths."""
        self.logger = pb_utils.Logger
        self.logger.log_info("Initializing latent_encoder model...")
        
        # Store model directory for path resolution
        self.model_dir = model_dir
        
        # ComfyUI will be initialized when service is called
        self.logger.log_info("✓ Latent encoder model initialized")
    
    def execute(self, requests):
        """Execute inference requests."""
        responses = []
        
        for request in requests:
            try:
                # Get input tensor (image_path as string)
                input_tensor = pb_utils.get_input_tensor_by_name(request, "image_path")
                if input_tensor is None:
                    error_response = pb_utils.InferenceResponse(
                        output_tensors=[],
                        error=pb_utils.TritonError("Missing input: image_path")
                    )
                    responses.append(error_response)
                    continue
                
                # Extract image path from tensor
                image_path_bytes = input_tensor.as_numpy()
                # Handle string tensor - decode bytes to string
                if image_path_bytes.dtype == object:
                    image_path = image_path_bytes.item().decode('utf-8') if isinstance(image_path_bytes.item(), bytes) else str(image_path_bytes.item())
                else:
                    # If it's a byte array, decode it
                    image_path = image_path_bytes.tobytes().decode('utf-8').rstrip('\x00')
                
                # Call service function
                result = encode_image_to_latent(
                    image_path=image_path,
                    save_tensor=False  # Don't save, just return tensor
                )
                
                if result['status'] == 'error':
                    error_response = pb_utils.InferenceResponse(
                        output_tensors=[],
                        error=pb_utils.TritonError(f"Service error: {result.get('error_message', 'Unknown error')}")
                    )
                    responses.append(error_response)
                    continue
                
                # Get latent tensor from result
                latent_tensor = result['latent_tensor']
                
                # Convert to numpy and ensure correct dtype
                latent_np = latent_tensor.detach().cpu().numpy().astype(np.float32)
                
                # Remove batch dimension if present (Triton handles batching)
                if len(latent_np.shape) > 4 and latent_np.shape[0] == 1:
                    latent_np = latent_np[0]
                
                # Create output tensor
                output_tensor = pb_utils.Tensor("latent", latent_np)
                
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
        self.logger.log_info("Finalizing latent_encoder model...")
        # Cleanup if needed (models are loaded per-request in service)
