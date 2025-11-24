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

# Set PyTorch memory optimization before any model loading
os.environ.setdefault("PYTORCH_ALLOC_CONF", "expandable_segments:True")

# Setup paths - will be done in initialize() method

class TritonPythonModel:
    def initialize(self, args):
        """Initialize the model - setup ComfyUI paths."""
        self.logger = pb_utils.Logger
        self.logger.log_info("Initializing sampling model...")
        
        # Get model directory - try pb_utils.get_model_dir() first, fallback to args
        try:
            self.model_dir = Path(pb_utils.get_model_dir())
        except AttributeError:
            # Fallback if get_model_dir() doesn't exist
            model_repository = args.get('model_repository', '/models')
            model_name = args.get('model_name', 'sampling')
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
        from service import sample_latent
        from config import Config
        self.sample_latent = sample_latent
        
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
                
                # Log shapes for debugging
                self.logger.log_info(f"Input shapes BEFORE processing - positive: {positive_np.shape}, negative: {negative_np.shape}, latent: {latent_np.shape}")
                
                # Convert to PyTorch tensors
                positive_pt = torch.from_numpy(positive_np)
                negative_pt = torch.from_numpy(negative_np)
                latent_pt = torch.from_numpy(latent_np)
                
                # CRITICAL: When called from ensemble with max_batch_size=1, Triton automatically prepends batch dimension
                # All inputs should arrive with batch dimension [1, ...] from the ensemble
                # We need to ensure all have exactly batch size 1 before processing
                
                # Normalize positive encoding to [1, seq_len, hidden_dim]
                if len(positive_pt.shape) == 2:
                    # [437, 3584] -> [1, 437, 3584] (no batch, add it)
                    positive_pt = positive_pt.unsqueeze(0)
                elif len(positive_pt.shape) == 3:
                    # [1, 437, 3584] or [batch, 437, 3584] - ensure batch=1
                    if positive_pt.shape[0] != 1:
                        self.logger.log_warn(f"Positive encoding has batch size {positive_pt.shape[0]}, taking first element")
                        positive_pt = positive_pt[0:1]
                else:
                    self.logger.log_warn(f"Unexpected positive encoding shape: {positive_pt.shape}")
                
                # Normalize negative encoding to [1, seq_len, hidden_dim]
                if len(negative_pt.shape) == 2:
                    # [407, 3584] -> [1, 407, 3584] (no batch, add it)
                    negative_pt = negative_pt.unsqueeze(0)
                elif len(negative_pt.shape) == 3:
                    # [1, 407, 3584] or [batch, 407, 3584] - ensure batch=1
                    if negative_pt.shape[0] != 1:
                        self.logger.log_warn(f"Negative encoding has batch size {negative_pt.shape[0]}, taking first element")
                        negative_pt = negative_pt[0:1]
                else:
                    self.logger.log_warn(f"Unexpected negative encoding shape: {negative_pt.shape}")
                
                # Normalize latent image to [1, channels, depth, height, width]
                if len(latent_pt.shape) == 4:
                    # [16, 1, 147, 110] -> [1, 16, 1, 147, 110] (no batch, add it)
                    latent_pt = latent_pt.unsqueeze(0)
                elif len(latent_pt.shape) == 5:
                    # [1, 16, 1, 147, 110] or [batch, 16, 1, 147, 110] - ensure batch=1
                    if latent_pt.shape[0] != 1:
                        self.logger.log_warn(f"Latent image has batch size {latent_pt.shape[0]}, taking first element")
                        latent_pt = latent_pt[0:1]
                else:
                    self.logger.log_warn(f"Unexpected latent image shape: {latent_pt.shape}")
                
                # Final verification - all must have batch size 1
                positive_batch = positive_pt.shape[0] if len(positive_pt.shape) >= 2 else 0
                negative_batch = negative_pt.shape[0] if len(negative_pt.shape) >= 2 else 0
                latent_batch = latent_pt.shape[0] if len(latent_pt.shape) >= 4 else 0
                
                self.logger.log_info(f"Input shapes AFTER processing - positive: {positive_pt.shape} (batch={positive_batch}), negative: {negative_pt.shape} (batch={negative_batch}), latent: {latent_pt.shape} (batch={latent_batch})")
                
                if positive_batch != negative_batch or positive_batch != latent_batch or negative_batch != latent_batch:
                    error_msg = f"Batch size mismatch after normalization: positive={positive_batch}, negative={negative_batch}, latent={latent_batch}"
                    self.logger.log_error(error_msg)
                    raise ValueError(error_msg)
                
                # Extract seed
                seed = None
                if seed_tensor is not None:
                    seed = int(seed_tensor.as_numpy().item())
                
                # Call service function
                result = self.sample_latent(
                    positive_encoding=positive_pt,
                    negative_encoding=negative_pt,
                    latent_image=latent_pt,
                    seed=seed,
                    steps=4,
                    cfg=1.0,
                    save_tensor=False  # Don't save, just return tensor
                )
                
                # CRITICAL: Extract tensor BEFORE offloading to ensure it's in scope
                # Service function already unloads, but we verify here while models are still accessible
                sampled_tensor = None
                if result['status'] == 'error':
                    error_response = pb_utils.InferenceResponse(
                        output_tensors=[],
                        error=pb_utils.TritonError(f"Service error: {result.get('error_message', 'Unknown error')}")
                    )
                    responses.append(error_response)
                    continue
                
                # Get sampled latent tensor from result (while still in scope)
                sampled_tensor = result['sampled_latent_tensor']
                
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
                sampled_np = sampled_tensor.detach().cpu().numpy().astype(np.float32)
                
                # Remove batch dimension if present
                # Service may return [1, 16, 1, 147, 110] (with batch) or [16, 1, 147, 110] (without)
                # Triton expects [16, 1, 147, 110] (no batch dimension)
                if len(sampled_np.shape) == 5 and sampled_np.shape[0] == 1:
                    # Remove batch dimension: [1, 16, 1, 147, 110] -> [16, 1, 147, 110]
                    sampled_np = sampled_np[0]
                elif len(sampled_np.shape) == 4:
                    # Already correct shape [16, 1, 147, 110]
                    pass
                else:
                    # Unexpected shape - log warning but continue
                    self.logger.log_warn(f"Unexpected sampled_latent shape: {sampled_np.shape}, expected [16, 1, 147, 110] or [1, 16, 1, 147, 110]")
                
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
        self.logger.log_info("Finalizing sampling model...")
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
            
            self.logger.log_info("✓ Sampling model finalized - GPU memory cleared")
        except Exception as e:
            self.logger.log_warn(f"Error during finalize: {e}")


