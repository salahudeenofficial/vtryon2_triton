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
import base64
import tempfile
from pathlib import Path

# Set PyTorch memory optimization before any model loading
os.environ.setdefault("PYTORCH_ALLOC_CONF", "expandable_segments:True")

# Setup paths - will be done in initialize() method

class TritonPythonModel:
    def initialize(self, args):
        """Initialize the model - setup ComfyUI paths."""
        self.logger = pb_utils.Logger
        self.logger.log_info("Initializing text_encoder model...")
        
        # Get model directory - try pb_utils.get_model_dir() first, fallback to args
        try:
            self.model_dir = Path(pb_utils.get_model_dir())
        except AttributeError:
            # Fallback if get_model_dir() doesn't exist
            model_repository = args.get('model_repository', '/models')
            model_name = args.get('model_name', 'text_encoder')
            self.model_dir = Path(model_repository) / model_name
        
        # Setup paths for ComfyUI and service code
        # Use COMFYUI_PATH environment variable if set, otherwise fallback to relative path
        comfyui_path = os.getenv("COMFYUI_PATH")
        if comfyui_path:
            comfyui_path = Path(comfyui_path)
        else:
            comfyui_path = self.model_dir.parent / "shared_comfyui"
        sys.path.insert(0, str(comfyui_path))
        sys.path.insert(0, str(self.model_dir))
        
        # Import service functions (after path setup)
        from service import encode_text_and_images
        from config import Config
        self.encode_text_and_images = encode_text_and_images
        
        # ComfyUI will be initialized when service is called
        self.logger.log_info("✓ Text encoder model initialized")
    
    def _extract_and_decode_image_path(self, tensor):
        """Extract string from tensor and handle base64 data URIs."""
        # Extract string from tensor
        data = tensor.as_numpy()
        if data.dtype == object:
            path = data.item().decode('utf-8') if isinstance(data.item(), bytes) else str(data.item())
        else:
            path = data.tobytes().decode('utf-8').rstrip('\x00')
        
        # Check if it's a base64 data URI
        if path.startswith('data:image'):
            try:
                # Extract base64 part (format: data:image/png;base64,<base64_data>)
                header, encoded = path.split(',', 1)
                # Decode base64
                image_data = base64.b64decode(encoded)
                # Determine file extension from header
                if 'png' in header:
                    suffix = '.png'
                elif 'jpg' in header or 'jpeg' in header:
                    suffix = '.jpg'
                elif 'webp' in header:
                    suffix = '.webp'
                else:
                    suffix = '.png'  # Default
                
                # Save to temp file
                with tempfile.NamedTemporaryFile(delete=False, suffix=suffix, dir='/tmp') as tmp:
                    tmp.write(image_data)
                    temp_path = tmp.name
                
                self.logger.log_info(f"Decoded base64 image to temp file: {temp_path}")
                return temp_path
            except Exception as e:
                self.logger.log_error(f"Error decoding base64 image: {e}")
                raise ValueError(f"Invalid base64 image data: {str(e)}")
        
        # Not base64, return as-is (file path)
        return path
    
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
                
                # Extract strings from tensors (images can be base64, prompt is always text)
                image1_path = self._extract_and_decode_image_path(image1_tensor)
                image2_path = self._extract_and_decode_image_path(image2_tensor)
                
                # Extract prompt (text only, not base64)
                prompt_tensor_data = prompt_tensor.as_numpy()
                if prompt_tensor_data.dtype == object:
                    prompt = prompt_tensor_data.item().decode('utf-8') if isinstance(prompt_tensor_data.item(), bytes) else str(prompt_tensor_data.item())
                else:
                    prompt = prompt_tensor_data.tobytes().decode('utf-8').rstrip('\x00')
                
                # Call service function
                result = self.encode_text_and_images(
                    image1_path=image1_path,
                    image2_path=image2_path,
                    prompt=prompt,
                    negative_prompt="",  # Empty negative prompt as per workflow
                    save_tensor=False  # Don't save, just return tensors
                )
                
                # CRITICAL: Extract tensors BEFORE offloading to ensure they're in scope
                # Service function already unloads, but we verify here while models are still accessible
                positive_tensor = None
                negative_tensor = None
                if result['status'] == 'error':
                    error_response = pb_utils.InferenceResponse(
                        output_tensors=[],
                        error=pb_utils.TritonError(f"Service error: {result.get('error_message', 'Unknown error')}")
                    )
                    responses.append(error_response)
                    continue
                
                # Get encoding tensors from result (while still in scope)
                positive_tensor = result['positive_encoding_tensor']
                negative_tensor = result['negative_encoding_tensor']
                
                # CRITICAL: Offload models IMMEDIATELY after getting result, while still in scope
                # This ensures models in current_loaded_models are accessible
                # Service already unloads, but we verify here as defensive programming
                try:
                    import comfy.model_management
                    import torch
                    import gc
                    
                    # Check if any models are still loaded in THIS process (while still in scope)
                    loaded = comfy.model_management.loaded_models()
                    if loaded:
                        self.logger.log_info(f"Found {len(loaded)} models still loaded, offloading to CPU...")
                        # Offload all models to CPU - models are still in scope via global current_loaded_models
                        comfy.model_management.unload_all_models()
                        torch.cuda.empty_cache()
                        torch.cuda.synchronize()
                        gc.collect()
                        self.logger.log_info("✓ Models offloaded to CPU (in scope)")
                except Exception as e:
                    self.logger.log_warn(f"Error offloading models: {e}")
                
                # Convert to numpy and ensure correct dtype
                positive_np = positive_tensor.detach().cpu().numpy().astype(np.float32)
                negative_np = negative_tensor.detach().cpu().numpy().astype(np.float32)
                
                # Remove batch dimension if present
                # Service may return [1, 437, 3584] (with batch) or [437, 3584] (without)
                # Triton expects [437, 3584] and [407, 3584] (no batch dimension)
                if len(positive_np.shape) == 3 and positive_np.shape[0] == 1:
                    # Remove batch dimension: [1, 437, 3584] -> [437, 3584]
                    positive_np = positive_np[0]
                elif len(positive_np.shape) == 2:
                    # Already correct shape [437, 3584]
                    pass
                else:
                    self.logger.log_warn(f"Unexpected positive_encoding shape: {positive_np.shape}, expected [437, 3584] or [1, 437, 3584]")
                
                if len(negative_np.shape) == 3 and negative_np.shape[0] == 1:
                    # Remove batch dimension: [1, 407, 3584] -> [407, 3584]
                    negative_np = negative_np[0]
                elif len(negative_np.shape) == 2:
                    # Already correct shape [407, 3584]
                    pass
                else:
                    self.logger.log_warn(f"Unexpected negative_encoding shape: {negative_np.shape}, expected [407, 3584] or [1, 407, 3584]")
                
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
        
        # Final GPU memory check after all requests processed
        try:
            import torch
            if torch.cuda.is_available():
                allocated = torch.cuda.memory_allocated(0) / 1e9
                reserved = torch.cuda.memory_reserved(0) / 1e9
                self.logger.log_info(f"Final GPU memory: {allocated:.2f}GB allocated, {reserved:.2f}GB reserved")
        except:
            pass
        
        return responses
    
    def finalize(self):
        """Cleanup resources - aggressively unload models and clear GPU memory."""
        self.logger.log_info("Finalizing text_encoder model...")
        try:
            # Import ComfyUI model management
            comfyui_path = os.getenv("COMFYUI_PATH")
            if comfyui_path and comfyui_path not in sys.path:
                sys.path.insert(0, comfyui_path)
            
            import comfy.model_management
            import torch
            import gc
            
            # Aggressively unload all models
            comfy.model_management.unload_all_models()
            torch.cuda.empty_cache()
            torch.cuda.synchronize()
            gc.collect()
            
            self.logger.log_info("✓ Text encoder model finalized - GPU memory cleared")
        except Exception as e:
            self.logger.log_warn(f"Error during finalize: {e}")


