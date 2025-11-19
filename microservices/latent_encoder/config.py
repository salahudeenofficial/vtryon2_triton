"""Configuration management for latent encoder service."""
import os
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()


class Config:
    """Configuration class for latent encoder service."""
    
    # Service mode: standalone (for testing before Triton integration)
    mode = os.getenv("MODE", "standalone")
    
    # Model Configuration
    # Try shared models first (for VastAI/Phase 2), then fall back to local
    _current_dir = Path(__file__).parent.resolve()
    _shared_models = _current_dir.parent.parent / "triton_model_repository" / "shared_models"
    if _shared_models.exists():
        model_dir = os.getenv("MODEL_DIR", str(_shared_models))
    else:
        model_dir = os.getenv("MODEL_DIR", "./models")
    vae_model_name = os.getenv("VAE_MODEL_NAME", "qwen_image_vae.safetensors")
    
    # Output Configuration
    output_dir = os.getenv("OUTPUT_DIR", "./output")
    
    # ComfyUI Configuration
    comfyui_path = os.getenv("COMFYUI_PATH", None)
    if comfyui_path is None:
        # Try to find ComfyUI in multiple locations
        current_dir = Path(__file__).parent.resolve()
        potential_paths = [
            # Shared ComfyUI (for VastAI/Phase 2)
            current_dir.parent.parent / "triton_model_repository" / "shared_comfyui",
            # Local comfyui (development)
            current_dir / "comfyui",
            # Parent ComfyUI (project root)
            current_dir.parent.parent / "ComfyUI",
            current_dir.parent.parent / "comfyui",
        ]
        for potential_path in potential_paths:
            if potential_path.exists() and (potential_path / "comfy").exists():
                comfyui_path = potential_path
                break
    
    # Processing Options
    upscale_method = os.getenv("UPSCALE_METHOD", "lanczos")
    megapixels = float(os.getenv("MEGAPIXELS", "1.0"))
    
    # Logging
    log_level = os.getenv("LOG_LEVEL", "INFO")
    log_format = os.getenv("LOG_FORMAT", "json")
    
    @classmethod
    def get_vae_model_path(cls) -> Path:
        """Get full path to VAE model."""
        return Path(cls.model_dir) / "vae" / cls.vae_model_name
    
    @classmethod
    def get_output_dir(cls) -> Path:
        """Get output directory path."""
        output_path = Path(cls.output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        return output_path
    
    @classmethod
    def validate(cls) -> None:
        """Validate configuration."""
        if cls.mode not in ["standalone"]:
            raise ValueError(f"Invalid mode: {cls.mode}. Must be 'standalone'")
        
        if not Path(cls.model_dir).exists():
            raise ValueError(f"Model directory does not exist: {cls.model_dir}")
        
        vae_path = cls.get_vae_model_path()
        if not vae_path.exists():
            raise ValueError(f"VAE model not found: {vae_path}")

