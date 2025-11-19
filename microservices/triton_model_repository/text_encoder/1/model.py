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
        logger.info("Initializing text_encoder model...")
        
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
        from service import encode_text_and_images, setup_comfyui
        from config import Config
        
        # Setup ComfyUI (this loads models)
        setup_comfyui()
        
        self.encode_text_and_images = encode_text_and_images
        self.config = Config
        logger.info("Text encoder model initialized")
    
    def execute(self, requests):
        responses = []
        
        for request in requests:
            try:
                # Get inputs (all STRING type)
                image1_tensor = pb_utils.get_input_tensor_by_name(request, "image1")
                image2_tensor = pb_utils.get_input_tensor_by_name(request, "image2")
                prompt_tensor = pb_utils.get_input_tensor_by_name(request, "prompt")
                
                if image1_tensor is None or image2_tensor is None or prompt_tensor is None:
                    raise ValueError("Missing required input tensors")
                
                # Convert bytes to strings
                image1_path = image1_tensor.as_numpy()[0].decode('utf-8')
                image2_path = image2_tensor.as_numpy()[0].decode('utf-8')
                prompt = prompt_tensor.as_numpy()[0].decode('utf-8')
                
                logger.info(f"Processing: image1={image1_path}, image2={image2_path}, prompt={prompt[:50]}...")
                
                # Call service function (use empty negative prompt, save_tensor=False)
                result = self.encode_text_and_images(
                    image1_path=image1_path,
                    image2_path=image2_path,
                    prompt=prompt,
                    negative_prompt="",  # Default empty negative prompt
                    save_tensor=False
                )
                
                if result["status"] != "success":
                    raise RuntimeError(f"Service error: {result.get('error_message', 'Unknown error')}")
                
                # Get tensors from result
                positive_tensor = result["positive_encoding_tensor"]
                negative_tensor = result["negative_encoding_tensor"]
                
                # Convert to numpy
                positive_np = positive_tensor.cpu().numpy().astype(np.float32)
                negative_np = negative_tensor.cpu().numpy().astype(np.float32)
                
                # Create output tensors
                positive_output = pb_utils.Tensor("positive_encoding", positive_np)
                negative_output = pb_utils.Tensor("negative_encoding", negative_np)
                response = pb_utils.InferenceResponse([positive_output, negative_output])
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
        logger.info("Finalizing text_encoder model...")
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
