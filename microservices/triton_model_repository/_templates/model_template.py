import triton_python_backend_utils as pb_utils
import sys
import os
import logging
from pathlib import Path
import torch
import numpy as np

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class TritonPythonModel:
    """
    Base template for Triton Python backend models.
    Each service will implement this class with service-specific logic.
    """
    
    def initialize(self, args):
        """
        Initialize the model - called once when model is loaded.
        
        Args:
            args: Dictionary with model configuration
        """
        logger.info("Initializing model...")
        
        # Get model directory (e.g., /models/{service}/1)
        self.model_dir = pb_utils.get_model_dir()
        logger.info(f"Model directory: {self.model_dir}")
        
        # Setup paths
        # Shared ComfyUI is at: ../../shared_comfyui (from {service}/1/)
        # Shared models are at: ../../shared_models (from {service}/1/)
        repo_root = Path(self.model_dir).parent.parent
        self.comfyui_path = repo_root / "shared_comfyui"
        self.models_path = repo_root / "shared_models"
        
        # Set environment variables for service code
        os.environ["COMFYUI_PATH"] = str(self.comfyui_path)
        os.environ["MODEL_DIR"] = str(self.models_path)
        
        # Add ComfyUI to Python path
        if self.comfyui_path.exists():
            sys.path.insert(0, str(self.comfyui_path))
            logger.info(f"Added ComfyUI path: {self.comfyui_path}")
        else:
            raise FileNotFoundError(f"ComfyUI not found at: {self.comfyui_path}")
        
        # Add model directory to path (for service imports)
        sys.path.insert(0, str(self.model_dir))
        
        logger.info("Model initialized successfully")
    
    def execute(self, requests):
        """
        Process inference requests.
        
        Args:
            requests: List of InferenceRequest objects
        
        Returns:
            List of InferenceResponse objects
        """
        responses = []
        
        for request in requests:
            try:
                # Extract inputs from request
                # This will be customized per service
                # input_tensor = pb_utils.get_input_tensor_by_name(request, "input_name")
                
                # Call service function
                # result = your_service_function(...)
                
                # Create output tensors
                # output_tensor = pb_utils.Tensor("output_name", result)
                # response = pb_utils.InferenceResponse([output_tensor])
                # responses.append(response)
                
                pass  # Placeholder
                
            except Exception as e:
                logger.error(f"Error processing request: {e}", exc_info=True)
                error_response = pb_utils.InferenceResponse(
                    output_tensors=[],
                    error=pb_utils.TritonError(f"Error: {str(e)}")
                )
                responses.append(error_response)
        
        return responses
    
    def finalize(self):
        """
        Cleanup resources - called when model is unloaded.
        """
        logger.info("Finalizing model...")
        # Cleanup code here (e.g., unload models, clear GPU memory)
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
        logger.info("Model finalized")

