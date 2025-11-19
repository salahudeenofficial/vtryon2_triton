"""Core service logic for decoding."""
import os
import sys
import torch
import numpy as np
from pathlib import Path
from datetime import datetime
from typing import Union
from PIL import Image
import time
import importlib.util

from config import Config
from errors import (
    VAEModelNotFoundError,
    LatentFileNotFoundError,
    DecodingFailedError,
    OutputDirNotWritableError,
    ComfyUIInitializationError,
    InvalidTensorFormatError,
    InvalidImageFormatError
)
# Import from local utils module (use importlib to avoid conflicts with ComfyUI utils)

# Get the directory of this file
_service_dir = Path(__file__).parent
_utils_path = _service_dir / "utils.py"

# Load utils module from local file
_utils_spec = importlib.util.spec_from_file_location("decoding_utils", _utils_path)
_decoding_utils = importlib.util.module_from_spec(_utils_spec)
_utils_spec.loader.exec_module(_decoding_utils)

# Import functions from local utils
get_value_at_index = _decoding_utils.get_value_at_index
add_comfyui_directory_to_sys_path = _decoding_utils.add_comfyui_directory_to_sys_path
add_extra_model_paths = _decoding_utils.add_extra_model_paths
generate_request_id = _decoding_utils.generate_request_id
ensure_directory_exists = _decoding_utils.ensure_directory_exists
load_tensor_from_file = _decoding_utils.load_tensor_from_file


def import_custom_nodes_minimal() -> None:
    """
    Minimal custom node loading using asyncio.run() without server infrastructure.
    This is lighter than the full server setup but still requires async execution.
    """
    import asyncio
    from nodes import init_extra_nodes
    
    # Simply run the async function with asyncio.run() - no server needed
    # This creates a new event loop, runs the coroutine, and closes the loop
    asyncio.run(init_extra_nodes(init_custom_nodes=True, init_api_nodes=False))


def setup_comfyui() -> None:
    """Setup ComfyUI paths and initialize."""
    comfyui_path = Path(__file__).parent / "comfyui"
    microservice_dir = Path(__file__).parent
    
    if not comfyui_path.exists():
        raise ComfyUIInitializationError(f"ComfyUI directory not found: {comfyui_path}")
    
    # Add ComfyUI to sys.path
    add_comfyui_directory_to_sys_path(comfyui_path)
    
    # Add extra model paths
    add_extra_model_paths(comfyui_path)
    
    # Configure folder_paths to use microservice's models directory
    # This must be done after ComfyUI is added to sys.path
    import folder_paths
    
    # Get microservice models directory (absolute path)
    microservice_models_dir = (microservice_dir / Config.model_dir).resolve()
    
    # Add microservice models directory to folder_paths
    # This adds it as an additional search path (not replacing the default)
    if microservice_models_dir.exists():
        # Add VAE path
        vae_path = microservice_models_dir / "vae"
        if vae_path.exists():
            folder_paths.add_model_folder_path("vae", str(vae_path), is_default=True)
            print(f"Added VAE model path: {vae_path}")
        
        # Add other model paths if they exist
        for model_type in ["checkpoints", "loras", "clip", "text_encoders", "diffusion_models"]:
            model_path = microservice_models_dir / model_type
            if model_path.exists():
                folder_paths.add_model_folder_path(model_type, str(model_path), is_default=False)
    
    # Import custom nodes
    import_custom_nodes_minimal()
    
    print("ComfyUI initialized successfully")


def prepare_latent_for_decoder(latent_value: Union[str, torch.Tensor, dict]) -> dict:
    """
    Prepare latent input for decoder.
    Decoder expects format: {"samples": tensor}
    
    Args:
        latent_value: File path, tensor, or dict with "samples" key
    
    Returns:
        Dict with "samples" key containing tensor
    """
    # If already in dict format with "samples" key, return as-is
    if isinstance(latent_value, dict):
        if "samples" in latent_value:
            return latent_value
        # If dict but no "samples" key, try to extract tensor
        if len(latent_value) == 1:
            tensor = list(latent_value.values())[0]
            if isinstance(tensor, torch.Tensor):
                return {"samples": tensor}
    
    # Load tensor if needed
    if isinstance(latent_value, str):
        tensor = load_tensor_from_file(latent_value)
    elif isinstance(latent_value, torch.Tensor):
        tensor = latent_value
    else:
        raise InvalidTensorFormatError(f"Latent must be a file path (str), tensor, or dict, got {type(latent_value)}")
    
    # Wrap in dict format
    return {"samples": tensor}


def save_image_tensor(
    image_tensor: torch.Tensor,
    output_path: Path,
    output_format: str = "jpg"
) -> tuple:
    """
    Save image tensor to file.
    
    Args:
        image_tensor: Image tensor in format [batch, height, width, channels] or [height, width, channels]
        output_path: Path to save image
        output_format: Image format (jpg, png, webp)
    
    Returns:
        tuple: (file_path, file_size_bytes, image_shape)
    """
    # Handle batch dimension
    if len(image_tensor.shape) == 4:
        # [batch, height, width, channels] - take first image
        image_tensor = image_tensor[0]
    elif len(image_tensor.shape) != 3:
        raise InvalidImageFormatError(f"Expected image tensor with 3 or 4 dimensions, got {len(image_tensor.shape)}")
    
    # Ensure shape is [height, width, channels]
    if len(image_tensor.shape) != 3 or image_tensor.shape[2] not in [1, 3, 4]:
        raise InvalidImageFormatError(f"Expected image tensor shape [H, W, C], got {image_tensor.shape}")
    
    # Convert to numpy and normalize to [0, 255]
    # Detach from computation graph if tensor requires grad
    image_tensor_detached = image_tensor.detach() if image_tensor.requires_grad else image_tensor
    image_np = image_tensor_detached.cpu().numpy()
    
    # Normalize based on value range
    if image_np.min() < 0:
        # Values are in [-1, 1] range, normalize to [0, 1]
        image_np = (image_np + 1.0) / 2.0
    elif image_np.max() <= 1.0:
        # Values are already in [0, 1] range
        pass
    else:
        # Values might be in [0, 255] range, normalize to [0, 1]
        image_np = image_np / 255.0
    
    # Clip to [0, 1] and convert to [0, 255] uint8
    image_np = np.clip(image_np, 0, 1)
    image_np = (image_np * 255).astype(np.uint8)
    
    # Handle grayscale (single channel)
    if image_np.shape[2] == 1:
        image_np = image_np.squeeze(2)
        img = Image.fromarray(image_np, mode='L')
    # Handle RGB (3 channels)
    elif image_np.shape[2] == 3:
        img = Image.fromarray(image_np, mode='RGB')
    # Handle RGBA (4 channels)
    elif image_np.shape[2] == 4:
        img = Image.fromarray(image_np, mode='RGBA')
    else:
        raise InvalidImageFormatError(f"Unsupported number of channels: {image_np.shape[2]}")
    
    # Save image
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Convert format string to PIL format
    format_map = {
        "jpg": "JPEG",
        "jpeg": "JPEG",
        "png": "PNG",
        "webp": "WEBP"
    }
    pil_format = format_map.get(output_format.lower(), "JPEG")
    
    # Save with appropriate format
    if pil_format == "JPEG" and image_np.shape[2] == 4:
        # JPEG doesn't support alpha, convert to RGB
        img = img.convert('RGB')
    
    img.save(output_path, format=pil_format, quality=95)
    
    # Get file size
    file_size = output_path.stat().st_size
    
    # Get image shape (height, width, channels)
    image_shape = list(image_tensor.shape)
    if len(image_shape) == 2:
        image_shape = [image_shape[0], image_shape[1], 1]
    
    return str(output_path), file_size, tuple(image_shape)


def decode_latent_to_image(
    latent: Union[str, torch.Tensor, dict],
    vae_model_name: str = None,
    output_filename: str = "output",
    output_dir: str = None,
    output_format: str = "jpg",
    request_id: str = None,
    save_image: bool = True
) -> dict:
    """
    Decode latent tensor to image file.
    
    Args:
        latent: Path to latent .pt file, tensor object, or dict format
        vae_model_name: Name of VAE model file (default: from config)
        output_filename: Base name for output image file (default: "output")
        output_dir: Directory to save output (default: from config)
        output_format: Output image format - "jpg", "png", "webp" (default: "jpg")
        request_id: Request identifier (auto-generated if not provided)
        save_image: Whether to save image to file (default: True)
    
    Returns:
        dict: {
            "status": "success" | "error",
            "request_id": str,
            "image_file_path": str | None,
            "image_shape": tuple | None,
            "image_tensor": torch.Tensor | None,
            "file_size": int | None,
            "error_message": str | None,
            "metadata": dict
        }
    """
    start_time = time.time()
    
    if request_id is None:
        request_id = generate_request_id()
    
    if vae_model_name is None:
        vae_model_name = Config.vae_model_name
    
    if output_dir is None:
        output_dir = Config.output_dir
    
    # Validate output format
    output_format = output_format.lower()
    if output_format not in ["jpg", "jpeg", "png", "webp"]:
        raise InvalidImageFormatError(f"Invalid output format: {output_format}. Must be jpg, png, or webp")
    
    try:
        # Setup ComfyUI
        setup_comfyui()
        
        # Import ComfyUI nodes
        from nodes import VAELoader, VAEDecode
        
        # Load VAE model
        vae_model_path = Config.get_vae_model_path()
        if not vae_model_path.exists():
            raise VAEModelNotFoundError(f"VAE model not found: {vae_model_path}")
        
        vaeloader = VAELoader()
        vae_output = vaeloader.load_vae(vae_name=vae_model_name)
        vae = get_value_at_index(vae_output, 0)
        
        # Prepare latent for decoder
        latent_dict = prepare_latent_for_decoder(latent)
        
        # Decode latent to image
        vaedecode = VAEDecode()
        decode_output = vaedecode.decode(
            samples=latent_dict,
            vae=vae
        )
        image_tensor_raw = get_value_at_index(decode_output, 0)
        
        # Extract image tensor
        image_tensor = image_tensor_raw
        if isinstance(image_tensor, dict):
            if "image" in image_tensor:
                image_tensor = image_tensor["image"]
            elif "pixels" in image_tensor:
                image_tensor = image_tensor["pixels"]
            elif len(image_tensor) == 1:
                image_tensor = list(image_tensor.values())[0]
        
        if isinstance(image_tensor, (list, tuple)):
            # Take first image if batch
            image_tensor = image_tensor[0] if len(image_tensor) > 0 else image_tensor
        
        # Ensure it's a tensor
        if not isinstance(image_tensor, torch.Tensor):
            raise DecodingFailedError(f"Expected tensor, got {type(image_tensor)}: {image_tensor}")
        
        # Get image shape
        image_shape = list(image_tensor.shape)
        # Normalize shape to [height, width, channels] for reporting
        if len(image_shape) == 4:
            # [batch, height, width, channels]
            image_shape = image_shape[1:]
        elif len(image_shape) == 3:
            # [height, width, channels]
            pass
        else:
            raise DecodingFailedError(f"Unexpected image tensor shape: {image_tensor.shape}")
        
        # Save image if requested
        image_file_path = None
        file_size = None
        if save_image:
            output_dir_obj = ensure_directory_exists(Path(output_dir))
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            image_filename = f"{output_filename}_{timestamp}.{output_format}"
            image_path = output_dir_obj / image_filename
            
            image_file_path, file_size, _ = save_image_tensor(
                image_tensor,
                image_path,
                output_format
            )
        
        processing_time_ms = int((time.time() - start_time) * 1000)
        
        metadata = {
            "image_shape": image_shape,
            "vae_model_name": vae_model_name,
            "output_format": output_format,
            "processing_time_ms": processing_time_ms,
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
        
        result = {
            "status": "success",
            "request_id": request_id,
            "image_file_path": image_file_path,
            "image_shape": tuple(image_shape),
            "file_size": file_size,
            "metadata": metadata
        }
        
        # Always include tensor in result (for testing/comparison)
        # Detach from computation graph to avoid gradient issues
        result["image_tensor"] = image_tensor.detach() if image_tensor.requires_grad else image_tensor
        
        return result
        
    except Exception as e:
        processing_time_ms = int((time.time() - start_time) * 1000)
        
        error_code = type(e).__name__
        error_message = str(e)
        
        return {
            "status": "error",
            "request_id": request_id,
            "error_code": error_code,
            "error_message": error_message,
            "metadata": {
                "processing_time_ms": processing_time_ms,
                "timestamp": datetime.utcnow().isoformat() + "Z"
            }
        }

