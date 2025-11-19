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
        logger.info("Initializing latent_encoder model...")
        
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
        from service import encode_image_to_latent, setup_comfyui
        from config import Config
        
        # Setup ComfyUI (this loads models)
        setup_comfyui()
        
        self.encode_image_to_latent = encode_image_to_latent
        self.config = Config
        logger.info("Latent encoder model initialized")
    
    def execute(self, requests):
        responses = []
        
        for request in requests:
            try:
                # Get input (image path as string)
                input_tensor = pb_utils.get_input_tensor_by_name(request, "input_image")
                if input_tensor is None:
                    raise ValueError("input_image tensor not found")
                
                # Convert to string (Triton STRING type is bytes)
                image_path_bytes = input_tensor.as_numpy()[0]
                image_path = image_path_bytes.decode('utf-8')
                
                logger.info(f"Processing image: {image_path}")
                
                # Call service function (save_tensor=False to get tensor directly)
                result = self.encode_image_to_latent(
                    image_path=image_path,
                    save_tensor=False
                )
                
                if result["status"] != "success":
                    raise RuntimeError(f"Service error: {result.get('error_message', 'Unknown error')}")
                
                # Get latent tensor from result
                latent_tensor = result["latent_tensor"]
                
                # Convert to numpy
                latent_np = latent_tensor.cpu().numpy().astype(np.float32)
                
                # Create output tensor
                output_tensor = pb_utils.Tensor("latent", latent_np)
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
        logger.info("Finalizing latent_encoder model...")
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
