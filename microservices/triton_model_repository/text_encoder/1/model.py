"""
Triton Python Backend Model for Text Encoder

This model encodes text prompts and images into conditioning tensors.
Inputs: image1_path (STRING), image2_path (STRING), prompt (STRING)
Outputs: positive_encoding (FP32 tensor), negative_encoding (FP32 tensor)
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
from service import encode_text_and_images
from config import Config


class TritonPythonModel:
    def initialize(self, args):
        """Initialize the model - setup ComfyUI paths."""
        self.logger = pb_utils.Logger
        self.logger.log_info("Initializing text_encoder model...")
        
        # Store model directory for path resolution
        self.model_dir = model_dir
        
        # ComfyUI will be initialized when service is called
        self.logger.log_info("✓ Text encoder model initialized")
    
    def execute(self, requests):
        """Execute inference requests."""
        responses = []
        
        for request in requests:
            try:
                # Get input tensors (all strings)
                image1_tensor = pb_utils.get_input_tensor_by_name(request, "image1_path")
                image2_tensor = pb_utils.get_input_tensor_by_name(request, "image2_path")
                prompt_tensor = pb_utils.get_input_tensor_by_name(request, "prompt")
                
                if image1_tensor is None or image2_tensor is None or prompt_tensor is None:
                    error_response = pb_utils.InferenceResponse(
                        output_tensors=[],
                        error=pb_utils.TritonError("Missing required inputs")
                    )
                    responses.append(error_response)
                    continue
                
                # Extract strings from tensors
                def extract_string(tensor):
                    data = tensor.as_numpy()
                    if data.dtype == object:
                        s = data.item()
                        return s.decode('utf-8') if isinstance(s, bytes) else str(s)
                    else:
                        return data.tobytes().decode('utf-8').rstrip('\x00')
                
                image1_path = extract_string(image1_tensor)
                image2_path = extract_string(image2_tensor)
                prompt = extract_string(prompt_tensor)
                
                # Call service function
                result = encode_text_and_images(
                    image1_path=image1_path,
                    image2_path=image2_path,
                    prompt=prompt,
                    negative_prompt="",  # Empty negative prompt as per workflow
                    save_tensor=False  # Don't save, just return tensors
                )
                
                if result['status'] == 'error':
                    error_response = pb_utils.InferenceResponse(
                        output_tensors=[],
                        error=pb_utils.TritonError(f"Service error: {result.get('error_message', 'Unknown error')}")
                    )
                    responses.append(error_response)
                    continue
                
                # Get encoding tensors from result
                positive_tensor = result['positive_encoding_tensor']
                negative_tensor = result['negative_encoding_tensor']
                
                # Convert to numpy and ensure correct dtype
                positive_np = positive_tensor.detach().cpu().numpy().astype(np.float32)
                negative_np = negative_tensor.detach().cpu().numpy().astype(np.float32)
                
                # Remove batch dimension if present
                if len(positive_np.shape) > 2 and positive_np.shape[0] == 1:
                    positive_np = positive_np[0]
                if len(negative_np.shape) > 2 and negative_np.shape[0] == 1:
                    negative_np = negative_np[0]
                
                # Create output tensors
                output_positive = pb_utils.Tensor("positive_encoding", positive_np)
                output_negative = pb_utils.Tensor("negative_encoding", negative_np)
                
                # Create response
                inference_response = pb_utils.InferenceResponse([output_positive, output_negative])
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
        self.logger.log_info("Finalizing text_encoder model...")
        # Cleanup if needed (models are loaded per-request in service)
