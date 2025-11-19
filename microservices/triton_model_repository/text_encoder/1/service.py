"""Core service logic for text encoder."""
import os
import sys
import torch
from pathlib import Path
from datetime import datetime
import time
import importlib.util

from config import Config
from errors import (
    ImageNotFoundError,
    CLIPModelNotFoundError,
    VAEModelNotFoundError,
    EncodingFailedError,
    OutputDirNotWritableError,
    ScalingFailedError,
    ComfyUIInitializationError
)
# Import from local utils module (use importlib to avoid conflicts with ComfyUI utils)

# Get the directory of this file
_service_dir = Path(__file__).parent
_utils_path = _service_dir / "utils.py"

# Load utils module from local file
_utils_spec = importlib.util.spec_from_file_location("text_encoder_utils", _utils_path)
_text_encoder_utils = importlib.util.module_from_spec(_utils_spec)
_utils_spec.loader.exec_module(_text_encoder_utils)

# Import functions from local utils
get_value_at_index = _text_encoder_utils.get_value_at_index
add_comfyui_directory_to_sys_path = _text_encoder_utils.add_comfyui_directory_to_sys_path
add_extra_model_paths = _text_encoder_utils.add_extra_model_paths
generate_request_id = _text_encoder_utils.generate_request_id
ensure_directory_exists = _text_encoder_utils.ensure_directory_exists


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
        # Add CLIP path
        clip_path = microservice_models_dir / "clip"
        if clip_path.exists():
            folder_paths.add_model_folder_path("clip", str(clip_path), is_default=True)
            print(f"Added CLIP model path: {clip_path}")
        
        # Add VAE path
        vae_path = microservice_models_dir / "vae"
        if vae_path.exists():
            folder_paths.add_model_folder_path("vae", str(vae_path), is_default=True)
            print(f"Added VAE model path: {vae_path}")
        
        # Add other model paths if they exist
        for model_type in ["checkpoints", "loras", "text_encoders", "diffusion_models"]:
            model_path = microservice_models_dir / model_type
            if model_path.exists():
                folder_paths.add_model_folder_path(model_type, str(model_path), is_default=False)
    
    # Import custom nodes
    import_custom_nodes_minimal()
    
    print("ComfyUI initialized successfully")


def resolve_image_path(image_path: str) -> Path:
    """Resolve image path to absolute path, trying multiple locations."""
    image_path_obj = Path(image_path)
    
    # If relative path, try to resolve it relative to current working directory first
    if not image_path_obj.is_absolute():
        # Try current directory
        if not image_path_obj.exists():
            # Try relative to microservice directory
            microservice_dir = Path(__file__).parent
            alt_path = microservice_dir / image_path
            if alt_path.exists():
                image_path_obj = alt_path
            # Try relative to parent ComfyUI directory
            elif (microservice_dir.parent.parent / image_path).exists():
                image_path_obj = microservice_dir.parent.parent / image_path
            # Try input directory
            elif (microservice_dir.parent.parent / "input" / image_path_obj.name).exists():
                image_path_obj = microservice_dir.parent.parent / "input" / image_path_obj.name
    
    # Resolve to absolute path
    image_path_obj = image_path_obj.resolve()
    
    if not image_path_obj.exists():
        raise ImageNotFoundError(f"Image file not found: {image_path} (resolved to: {image_path_obj})")
    
    if not image_path_obj.is_file():
        raise ImageNotFoundError(f"Path is not a file: {image_path_obj}")
    
    return image_path_obj


def extract_conditioning_tensor(conditioning_output) -> torch.Tensor:
    """Extract tensor from conditioning output format [tensor, metadata_dict]."""
    # Conditioning format is typically: [tensor, metadata_dict] or just [tensor]
    if isinstance(conditioning_output, (list, tuple)):
        if len(conditioning_output) == 0:
            raise EncodingFailedError("Conditioning output is an empty list/tuple")
        
        # Try to find tensor in the list
        for item in conditioning_output:
            if isinstance(item, torch.Tensor):
                return item
            elif isinstance(item, dict):
                # If it's a dict, try to extract tensor from it
                if "cond" in item:
                    tensor = item["cond"]
                    if isinstance(tensor, torch.Tensor):
                        return tensor
                # Try to find any tensor value in the dict
                for value in item.values():
                    if isinstance(value, torch.Tensor):
                        return value
            elif isinstance(item, (list, tuple)):
                # Recursively check nested lists
                try:
                    return extract_conditioning_tensor(item)
                except EncodingFailedError:
                    continue
        
        # If we get here, no tensor was found in the list
        raise EncodingFailedError(f"Could not find tensor in conditioning output list: {type(conditioning_output[0])}")
    
    # If it's a dict directly
    if isinstance(conditioning_output, dict):
        if "cond" in conditioning_output:
            tensor = conditioning_output["cond"]
            if isinstance(tensor, torch.Tensor):
                return tensor
            # If cond is not a tensor, try to extract from it
            return extract_conditioning_tensor(tensor)
        # Try to find any tensor value in the dict
        for value in conditioning_output.values():
            if isinstance(value, torch.Tensor):
                return value
            elif isinstance(value, (list, tuple, dict)):
                try:
                    return extract_conditioning_tensor(value)
                except EncodingFailedError:
                    continue
        raise EncodingFailedError(f"Could not find tensor in conditioning output dict")
    
    # If it's already a tensor
    if isinstance(conditioning_output, torch.Tensor):
        return conditioning_output
    
    raise EncodingFailedError(f"Could not extract tensor from conditioning output: {type(conditioning_output)}, value: {conditioning_output}")


def encode_text_and_images(
    image1_path: str,
    image2_path: str,
    prompt: str,
    negative_prompt: str = "",
    clip_model_name: str = None,
    vae_model_name: str = None,
    output_dir: str = None,
    upscale_method: str = "lanczos",
    megapixels: float = 1.0,
    request_id: str = None,
    save_tensor: bool = True
) -> dict:
    """
    Encode text prompts and images into conditioning tensors.
    
    Args:
        image1_path: Path to first image file (masked person - needs scaling)
        image2_path: Path to second image file (cloth image)
        prompt: Text prompt for positive conditioning
        negative_prompt: Text prompt for negative conditioning (default: "")
        clip_model_name: Name of CLIP model file (default: from config)
        vae_model_name: Name of VAE model file (default: from config)
        output_dir: Directory to save outputs (default: from config)
        upscale_method: Image scaling method (default: "lanczos")
        megapixels: Target megapixels for scaling (default: 1.0)
        request_id: Request identifier (auto-generated if not provided)
        save_tensor: Whether to save tensors to files (default: True)
    
    Returns:
        dict: {
            "status": "success" | "error",
            "request_id": str,
            "positive_encoding_file_path": str | None,
            "negative_encoding_file_path": str | None,
            "positive_encoding_shape": list | None,
            "negative_encoding_shape": list | None,
            "positive_encoding_tensor": torch.Tensor | None,
            "negative_encoding_tensor": torch.Tensor | None,
            "error_message": str | None,
            "metadata": dict
        }
    """
    start_time = time.time()
    
    if request_id is None:
        request_id = generate_request_id()
    
    if clip_model_name is None:
        clip_model_name = Config.clip_model_name
    
    if vae_model_name is None:
        vae_model_name = Config.vae_model_name
    
    if output_dir is None:
        output_dir = Config.output_dir
    
    try:
        # Validate and resolve image paths
        image1_path_obj = resolve_image_path(image1_path)
        image2_path_obj = resolve_image_path(image2_path)
        
        # Setup ComfyUI
        setup_comfyui()
        
        # Import ComfyUI nodes
        from nodes import CLIPLoader, VAELoader, LoadImage
        from nodes import NODE_CLASS_MAPPINGS
        
        # Load CLIP model
        clip_model_path = Config.get_clip_model_path()
        if not clip_model_path.exists():
            raise CLIPModelNotFoundError(f"CLIP model not found: {clip_model_path}")
        
        cliploader = CLIPLoader()
        clip_output = cliploader.load_clip(clip_name=clip_model_name)
        clip = get_value_at_index(clip_output, 0)
        
        # Load VAE model
        vae_model_path = Config.get_vae_model_path()
        if not vae_model_path.exists():
            raise VAEModelNotFoundError(f"VAE model not found: {vae_model_path}")
        
        vaeloader = VAELoader()
        vae_output = vaeloader.load_vae(vae_name=vae_model_name)
        vae = get_value_at_index(vae_output, 0)
        
        # Load image1 (masked person - needs scaling)
        loadimage = LoadImage()
        image1_output = loadimage.load_image(image=str(image1_path_obj))
        image1 = get_value_at_index(image1_output, 0)
        
        # Get original image1 shape
        image1_original_shape = list(image1.shape) if hasattr(image1, 'shape') else None
        
        # Scale image1
        if "ImageScaleToTotalPixels" not in NODE_CLASS_MAPPINGS:
            raise ScalingFailedError("ImageScaleToTotalPixels node not found in custom nodes")
        
        imagescaletototalpixels = NODE_CLASS_MAPPINGS["ImageScaleToTotalPixels"]()
        scaled_image1_output = imagescaletototalpixels.EXECUTE_NORMALIZED(
            upscale_method=upscale_method,
            megapixels=megapixels,
            image=image1,
        )
        scaled_image1 = get_value_at_index(scaled_image1_output, 0)
        
        # Load image2 (cloth - no scaling needed)
        image2_output = loadimage.load_image(image=str(image2_path_obj))
        image2 = get_value_at_index(image2_output, 0)
        
        # Get image2 shape
        image2_shape = list(image2.shape) if hasattr(image2, 'shape') else None
        
        # Encode prompts using TextEncodeQwenImageEditPlus
        if "TextEncodeQwenImageEditPlus" not in NODE_CLASS_MAPPINGS:
            raise EncodingFailedError("TextEncodeQwenImageEditPlus node not found in custom nodes")
        
        textencodeqwenimageeditplus = NODE_CLASS_MAPPINGS["TextEncodeQwenImageEditPlus"]()
        
        # Encode positive prompt
        positive_output = textencodeqwenimageeditplus.EXECUTE_NORMALIZED(
            prompt=prompt,
            clip=clip,
            vae=vae,
            image1=scaled_image1,
            image2=image2,
        )
        positive_conditioning_raw = get_value_at_index(positive_output, 0)
        
        # Encode negative prompt
        negative_output = textencodeqwenimageeditplus.EXECUTE_NORMALIZED(
            prompt=negative_prompt,
            clip=clip,
            vae=vae,
            image1=scaled_image1,
            image2=image2,
        )
        negative_conditioning_raw = get_value_at_index(negative_output, 0)
        
        # Extract tensors from conditioning outputs
        positive_tensor = extract_conditioning_tensor(positive_conditioning_raw)
        negative_tensor = extract_conditioning_tensor(negative_conditioning_raw)
        
        # Get tensor shapes
        positive_shape = list(positive_tensor.shape) if hasattr(positive_tensor, 'shape') else None
        negative_shape = list(negative_tensor.shape) if hasattr(negative_tensor, 'shape') else None
        
        # Save tensors if requested
        positive_file_path = None
        negative_file_path = None
        if save_tensor:
            output_dir_obj = ensure_directory_exists(Path(output_dir))
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            positive_filename = f"positive_encoding_{request_id}_{timestamp}.pt"
            negative_filename = f"negative_encoding_{request_id}_{timestamp}.pt"
            positive_file_path = output_dir_obj / positive_filename
            negative_file_path = output_dir_obj / negative_filename
            
            # Save tensors
            torch.save(positive_tensor, positive_file_path)
            torch.save(negative_tensor, negative_file_path)
            positive_file_path = str(positive_file_path)
            negative_file_path = str(negative_file_path)
        
        processing_time_ms = int((time.time() - start_time) * 1000)
        
        metadata = {
            "image1_original_shape": image1_original_shape,
            "image1_scaled_shape": list(scaled_image1.shape) if hasattr(scaled_image1, 'shape') else None,
            "image2_shape": image2_shape,
            "positive_encoding_shape": positive_shape,
            "negative_encoding_shape": negative_shape,
            "clip_model_name": clip_model_name,
            "vae_model_name": vae_model_name,
            "prompt": prompt,
            "negative_prompt": negative_prompt,
            "upscale_method": upscale_method,
            "megapixels": megapixels,
            "processing_time_ms": processing_time_ms,
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
        
        result = {
            "status": "success",
            "request_id": request_id,
            "positive_encoding_file_path": positive_file_path,
            "negative_encoding_file_path": negative_file_path,
            "positive_encoding_shape": positive_shape,
            "negative_encoding_shape": negative_shape,
            "metadata": metadata
        }
        
        # Always include tensors in result (for testing/comparison)
        result["positive_encoding_tensor"] = positive_tensor
        result["negative_encoding_tensor"] = negative_tensor
        
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

