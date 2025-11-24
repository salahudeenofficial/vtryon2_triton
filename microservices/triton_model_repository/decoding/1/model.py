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

# Set PyTorch memory optimization before any model loading
os.environ.setdefault("PYTORCH_ALLOC_CONF", "expandable_segments:True")

# Setup paths - will be done in initialize() method
# Cannot set paths at module level as we need initialize() args


class TritonPythonModel:
    def initialize(self, args):
        """Initialize the model - setup ComfyUI paths."""
        self.logger = pb_utils.Logger
        self.logger.log_info("Initializing decoding model...")
        
        # Get model directory - try pb_utils.get_model_dir() first, fallback to args
        try:
            self.model_dir = Path(pb_utils.get_model_dir())
        except AttributeError:
            # Fallback if get_model_dir() doesn't exist
            model_repository = args.get('model_repository', '/models')
            model_name = args.get('model_name', 'decoding')
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
        from service import decode_latent_to_image
        from config import Config
        self.decode_latent_to_image = decode_latent_to_image
        
        # ComfyUI will be initialized when service is called
        self.logger.log_info("✓ Decoding model initialized")
    
    def execute(self, requests):
        """Execute inference requests."""
        # CRITICAL: Ensure GPU memory is free before decoding
        # IMPORTANT: Each Triton model runs in a SEPARATE Python process!
        # - Previous processes (sampling) already unloaded their models
        # - GPU memory is shared, so it should be free, but we verify
        # - This process will load VAE decoder, so we ensure memory is available
        try:
            import torch
            import gc
            
            # Monitor GPU memory before loading models
            if torch.cuda.is_available():
                allocated_before = torch.cuda.memory_allocated(0) / 1e9
                reserved_before = torch.cuda.memory_reserved(0) / 1e9
                total_memory = torch.cuda.get_device_properties(0).total_memory / 1e9
                free_memory = total_memory - reserved_before
                self.logger.log_info(f"GPU memory before decoding: {allocated_before:.2f}GB allocated, {reserved_before:.2f}GB reserved, {free_memory:.2f}GB free")
            
            # Clear any lingering GPU cache (from previous processes)
            torch.cuda.empty_cache()
            torch.cuda.ipc_collect()  # Collect inter-process memory
            torch.cuda.synchronize()
            gc.collect()
        except Exception as e:
            self.logger.log_warn(f"Error checking GPU memory before decoding: {e}")
        
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
                # Latent: [16, 1, 147, 110] -> [1, 16, 1, 147, 110]
                if len(latent_pt.shape) == 4:
                    latent_pt = latent_pt.unsqueeze(0)
                
                # Call service function
                result = self.decode_latent_to_image(
                    latent=latent_pt,
                    save_image=False  # Don't save, just return tensor
                )
                
                # CRITICAL: Extract tensor BEFORE offloading to ensure it's in scope
                # Service function already unloads, but we verify here while models are still accessible
                image_tensor = None
                if result['status'] == 'error':
                    error_response = pb_utils.InferenceResponse(
                        output_tensors=[],
                        error=pb_utils.TritonError(f"Service error: {result.get('error_message', 'Unknown error')}")
                    )
                    responses.append(error_response)
                    continue
                
                # Get image tensor from result (while still in scope)
                image_tensor = result['image_tensor']
                
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
                        torch.cuda.ipc_collect()  # Collect inter-process memory
                        torch.cuda.synchronize()
                        gc.collect()
                        self.logger.log_info("✓ Models offloaded to CPU (in scope)")
                except Exception as e:
                    self.logger.log_warn(f"Error offloading models: {e}")
                
                # Convert to numpy and ensure correct dtype
                image_np = image_tensor.detach().cpu().numpy().astype(np.float32)
                
                # Remove batch dimension if present
                # Service may return [1, 1176, 880, 3] (with batch) or [1176, 880, 3] (without)
                # Triton expects [1176, 880, 3] (no batch dimension)
                if len(image_np.shape) == 4 and image_np.shape[0] == 1:
                    # Remove batch dimension: [1, 1176, 880, 3] -> [1176, 880, 3]
                    image_np = image_np[0]
                elif len(image_np.shape) == 3:
                    # Already correct shape [1176, 880, 3]
                    pass
                else:
                    # Unexpected shape - log warning but continue
                    self.logger.log_warn(f"Unexpected image shape: {image_np.shape}, expected [1176, 880, 3] or [1, 1176, 880, 3]")
                
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
        
        # Final GPU memory check after all requests processed
        try:
            import torch
            if torch.cuda.is_available():
                allocated = torch.cuda.memory_allocated(0) / 1e9
                reserved = torch.cuda.memory_reserved(0) / 1e9
                total_memory = torch.cuda.get_device_properties(0).total_memory / 1e9
                free_memory = total_memory - reserved
                self.logger.log_info(f"Final GPU memory: {allocated:.2f}GB allocated, {reserved:.2f}GB reserved, {free_memory:.2f}GB free")
        except:
            pass
        
        return responses
    
    def finalize(self):
        """Cleanup resources - aggressively unload models and clear GPU memory."""
        self.logger.log_info("Finalizing decoding model...")
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
            
            self.logger.log_info("✓ Decoding model finalized - GPU memory cleared")
        except Exception as e:
            self.logger.log_warn(f"Error during finalize: {e}")
