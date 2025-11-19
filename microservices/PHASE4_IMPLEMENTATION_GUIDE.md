# Phase 4: Python Backend Implementation Guide

## Overview
Phase 4 involves creating the Triton Python backend models (`model.py`) for each service. These models wrap your existing service functions and make them accessible via Triton Inference Server.

---

## Prerequisites

✅ **Phase 3 Complete**:
- Repository cloned on VastAI
- Models downloaded to `triton_model_repository/shared_models/`
- ComfyUI setup in `triton_model_repository/shared_comfyui/`
- Service code copied to `triton_model_repository/{service}/1/`
- Config files generated: `triton_model_repository/{service}/config.pbtxt`

---

## Step-by-Step Implementation

### Step 1: Create Model Template

**Location**: `triton_model_repository/_templates/model_template.py`

This template provides the base structure for all models.

**Create the template file** with the following structure:

```python
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
        
        # Import service module (service.py is in model_dir)
        # This will be customized per service
        # from service import your_service_function
        # from config import Config
        
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
                logger.error(f"Error processing request: {e}")
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
```

**Save this as**: `triton_model_repository/_templates/model_template.py`

---

### Step 2: Implement Latent Encoder Model

**Location**: `triton_model_repository/latent_encoder/1/model.py`

**Key Points**:
- Input: `input_image` (STRING) - path to image file
- Output: `latent` (FP32 tensor) - shape `[1, 16, 1, 147, 110]`
- Service function: `encode_image_to_latent(image_path: str) -> torch.Tensor`

**Implementation**:

```python
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
                
                # Call service function
                latent_tensor = self.encode_image_to_latent(image_path)
                
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
```

---

### Step 3: Implement Text Encoder Model

**Location**: `triton_model_repository/text_encoder/1/model.py`

**Key Points**:
- Inputs: `image1` (STRING), `image2` (STRING), `prompt` (STRING)
- Outputs: `positive_encoding` (FP32), `negative_encoding` (FP32)
- Service function: `encode_text_and_images(image1_path, image2_path, prompt, negative_prompt) -> (pos_tensor, neg_tensor)`

**Implementation** (similar structure, but with multiple inputs/outputs):

```python
# Similar structure to latent_encoder, but:
# - Extract 3 input tensors (image1, image2, prompt)
# - Call encode_text_and_images()
# - Create 2 output tensors (positive_encoding, negative_encoding)
```

---

### Step 4: Implement Sampling Model

**Location**: `triton_model_repository/sampling/1/model.py`

**Key Points**:
- Inputs: `positive_encoding` (STRING path), `negative_encoding` (STRING path), `latent_image` (STRING path), `seed` (INT64), `steps` (INT32), `cfg` (FP32)
- Output: `sampled_latent` (FP32 tensor)
- Service function: `sample_latent(positive_encoding_path, negative_encoding_path, latent_image_path, seed, steps, cfg) -> torch.Tensor`

**Note**: Inputs are file paths to tensors saved by previous services.

---

### Step 5: Implement Decoding Model

**Location**: `triton_model_repository/decoding/1/model.py`

**Key Points**:
- Input: `latent` (STRING path to tensor file)
- Output: `image` (FP32 tensor) - shape `[1, 1176, 880, 3]`
- Service function: `decode_latent_to_image(latent_path: str) -> torch.Tensor`

---

### Step 6: Create Ensemble Config

**Location**: `triton_model_repository/vtryon_pipeline/config.pbtxt`

**Purpose**: Chain all 4 services together in sequence.

**Structure**:
```protobuf
name: "vtryon_pipeline"
platform: "ensemble"
max_batch_size: 1

input [
  {
    name: "image1"
    data_type: TYPE_STRING
    dims: [ 1 ]
  },
  {
    name: "image2"
    data_type: TYPE_STRING
    dims: [ 1 ]
  },
  {
    name: "prompt"
    data_type: TYPE_STRING
    dims: [ 1 ]
  }
]

output [
  {
    name: "output_image"
    data_type: TYPE_FP32
    dims: [ 1, 1176, 880, 3 ]
  }
]

ensemble_scheduling {
  step [
    {
      model_name: "latent_encoder"
      model_version: -1
      input_map {
        key: "input_image"
        value: "image1"
      }
      output_map {
        key: "latent"
        value: "latent_image"
      }
    },
    {
      model_name: "text_encoder"
      model_version: -1
      input_map {
        key: "image1"
        value: "image1"
      }
      input_map {
        key: "image2"
        value: "image2"
      }
      input_map {
        key: "prompt"
        value: "prompt"
      }
      output_map {
        key: "positive_encoding"
        value: "positive_encoding"
      }
      output_map {
        key: "negative_encoding"
        value: "negative_encoding"
      }
    },
    {
      model_name: "sampling"
      model_version: -1
      input_map {
        key: "positive_encoding"
        value: "positive_encoding"
      }
      input_map {
        key: "negative_encoding"
        value: "negative_encoding"
      }
      input_map {
        key: "latent_image"
        value: "latent_image"
      }
      output_map {
        key: "sampled_latent"
        value: "sampled_latent"
      }
    },
    {
      model_name: "decoding"
      model_version: -1
      input_map {
        key: "latent"
        value: "sampled_latent"
      }
      output_map {
        key: "image"
        value: "output_image"
      }
    }
  ]
}
```

**Note**: This is a simplified version. You'll need to handle tensor file paths between services (Triton ensemble passes tensors directly, but our services use file paths - you may need intermediate file handling).

---

## Testing Each Model

After implementing each model:

1. **Start Triton server**:
   ```bash
   cd microservices
   ./start_triton_direct.sh
   ```

2. **Check model status**:
   ```bash
   curl http://localhost:8000/v2/models/{model_name}
   ```

3. **Test with a simple request** (create test scripts)

---

## Common Issues & Solutions

### Issue: Import Errors
- **Solution**: Ensure paths are set correctly in `initialize()`
- Check that `shared_comfyui` and service files are in correct locations

### Issue: Model Not Found
- **Solution**: Verify model files exist in `shared_models/`
- Check `MODEL_DIR` environment variable

### Issue: GPU Out of Memory
- **Solution**: Ensure `torch.cuda.empty_cache()` in `finalize()`
- Check that models are unloaded properly

### Issue: Tensor Shape Mismatch
- **Solution**: Verify output tensor shapes match `config.pbtxt`
- Check service function output shapes

---

## Next Steps After Phase 4

Once all models are implemented:

1. **Phase 5**: Test with Triton server
2. **Phase 6**: Performance testing
3. **Phase 7**: Final testing and documentation

---

## Reference Files

- Service functions: `microservices/{service}/service.py`
- Config files: `microservices/{service}/config.py`
- Test results: `microservices/test_results/{service}/TRITON_CONFIG_DATA.json`
- Triton configs: `triton_model_repository/{service}/config.pbtxt`

