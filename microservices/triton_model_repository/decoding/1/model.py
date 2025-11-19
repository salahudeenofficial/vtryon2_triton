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
        logger.info("Initializing decoding model...")
        
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
        from service import decode_latent_to_image, setup_comfyui
        from config import Config
        
        # Setup ComfyUI (this loads models)
        setup_comfyui()
        
        self.decode_latent_to_image = decode_latent_to_image
        self.config = Config
        logger.info("Decoding model initialized")
    
    def execute(self, requests):
        responses = []
        
        for request in requests:
            try:
                # Get input (latent path as string)
                input_tensor = pb_utils.get_input_tensor_by_name(request, "latent")
                if input_tensor is None:
                    raise ValueError("latent tensor not found")
                
                # Convert to string (Triton STRING type is bytes)
                latent_path_bytes = input_tensor.as_numpy()[0]
                latent_path = latent_path_bytes.decode('utf-8')
                
                logger.info(f"Processing latent: {latent_path}")
                
                # Call service function (save_image=False to get tensor directly)
                result = self.decode_latent_to_image(
                    latent=latent_path,
                    save_image=False
                )
                
                if result["status"] != "success":
                    raise RuntimeError(f"Service error: {result.get('error_message', 'Unknown error')}")
                
                # Get image tensor from result
                image_tensor = result["image_tensor"]
                
                # Ensure shape is [batch, height, width, channels]
                if len(image_tensor.shape) == 3:
                    # Add batch dimension: [height, width, channels] -> [1, height, width, channels]
                    image_tensor = image_tensor.unsqueeze(0)
                elif len(image_tensor.shape) == 4:
                    # Already has batch dimension
                    pass
                else:
                    raise ValueError(f"Unexpected image tensor shape: {image_tensor.shape}")
                
                # Convert to numpy
                image_np = image_tensor.cpu().numpy().astype(np.float32)
                
                # Create output tensor
                output_tensor = pb_utils.Tensor("image", image_np)
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
        logger.info("Finalizing decoding model...")
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
