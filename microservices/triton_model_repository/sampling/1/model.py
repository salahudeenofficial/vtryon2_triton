import triton_python_backend_utils as pb_utils
import sys
import os
import logging
from pathlib import Path
import torch
import numpy as np

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class TritonPythonModel:
    def initialize(self, args):
        logger.info("Initializing sampling model...")
        
        # Get model directory
        self.model_dir = pb_utils.get_model_dir()
        repo_root = Path(self.model_dir).parent.parent
        self.comfyui_path = repo_root / "shared_comfyui"
        self.models_path = repo_root / "shared_models"
        
        # Set environment variables
        os.environ["COMFYUI_PATH"] = str(self.comfyui_path)
        os.environ["MODEL_DIR"] = str(self.models_path)
        
        # Add paths
        sys.path.insert(0, str(self.comfyui_path))
        sys.path.insert(0, str(self.model_dir))
        
        # Import service
        from service import sample_latent, setup_comfyui
        from config import Config
        
        # Setup ComfyUI (this loads models)
        setup_comfyui()
        
        self.sample_latent = sample_latent
        self.config = Config
        logger.info("Sampling model initialized")
    
    def execute(self, requests):
        responses = []
        
        for request in requests:
            try:
                # Get inputs
                positive_encoding_tensor = pb_utils.get_input_tensor_by_name(request, "positive_encoding")
                negative_encoding_tensor = pb_utils.get_input_tensor_by_name(request, "negative_encoding")
                latent_image_tensor = pb_utils.get_input_tensor_by_name(request, "latent_image")
                seed_tensor = pb_utils.get_input_tensor_by_name(request, "seed")
                steps_tensor = pb_utils.get_input_tensor_by_name(request, "steps")
                cfg_tensor = pb_utils.get_input_tensor_by_name(request, "cfg")
                
                if positive_encoding_tensor is None or negative_encoding_tensor is None or latent_image_tensor is None:
                    raise ValueError("Missing required input tensors")
                
                # Convert STRING inputs to file paths
                positive_encoding_path = positive_encoding_tensor.as_numpy()[0].decode('utf-8')
                negative_encoding_path = negative_encoding_tensor.as_numpy()[0].decode('utf-8')
                latent_image_path = latent_image_tensor.as_numpy()[0].decode('utf-8')
                
                # Convert numeric inputs (FP32 -> int/float)
                seed = int(seed_tensor.as_numpy()[0]) if seed_tensor is not None else None
                steps = int(steps_tensor.as_numpy()[0]) if steps_tensor is not None else 4
                cfg = float(cfg_tensor.as_numpy()[0]) if cfg_tensor is not None else 1.0
                
                logger.info(f"Processing: seed={seed}, steps={steps}, cfg={cfg}")
                
                # Call service function
                result = self.sample_latent(
                    positive_encoding=positive_encoding_path,
                    negative_encoding=negative_encoding_path,
                    latent_image=latent_image_path,
                    seed=seed,
                    steps=steps,
                    cfg=cfg,
                    save_tensor=False
                )
                
                if result["status"] != "success":
                    raise RuntimeError(f"Service error: {result.get('error_message', 'Unknown error')}")
                
                # Get sampled latent tensor from result
                sampled_latent_tensor = result["sampled_latent_tensor"]
                
                # Convert to numpy
                sampled_latent_np = sampled_latent_tensor.cpu().numpy().astype(np.float32)
                
                # Create output tensor
                output_tensor = pb_utils.Tensor("sampled_latent", sampled_latent_np)
                response = pb_utils.InferenceResponse([output_tensor])
                responses.append(response)
                
            except Exception as e:
                logger.error(f"Error: {e}", exc_info=True)
                error_response = pb_utils.InferenceResponse(
                    output_tensors=[],
                    error=pb_utils.TritonError(f"Error: {str(e)}")
                )
                responses.append(error_response)
        
        return responses
    
    def finalize(self):
        logger.info("Finalizing sampling model...")
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
