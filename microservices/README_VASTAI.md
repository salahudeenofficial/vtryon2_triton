# VastAI Setup & Testing Guide

## Quick Start

### 1. Clone Repository on VastAI Instance

```bash
git clone https://github.com/salahudeenofficial/vtryon2_triton.git
cd vtryon2_triton
```

### 2. Run Setup Script

```bash
cd microservices
chmod +x setup_vastai.sh
./setup_vastai.sh
```

This will:
- Install system dependencies
- Create Python virtual environment
- Install PyTorch with CUDA
- Setup ComfyUI modules
- Download all required models
- Create test directories

### 3. Activate Environment

```bash
source ../venv/bin/activate
```

### 4. Run Phase 2 Tests

```bash
cd microservices
python test_latent_encoder.py
# Repeat for other services
```

## What Gets Set Up

### Models Downloaded
- VAE Model: `qwen_image_vae.safetensors` → `triton_model_repository/shared_models/vae/`
- CLIP Model: `qwen_2.5_vl_7b_fp8_scaled.safetensors` → `triton_model_repository/shared_models/clip/`
- UNET Model: `qwen_image_edit_2509_fp8_e4m3fn.safetensors` → `triton_model_repository/shared_models/diffusion_models/`
- LoRA Model: `Qwen-Image-Lightning-4steps-V2.0.safetensors` → `triton_model_repository/shared_models/loras/`

### Directory Structure
```
vtryon2_triton/
├── venv/                    # Python virtual environment
├── microservices/
│   ├── triton_model_repository/
│   │   ├── shared_models/   # All models here
│   │   ├── shared_comfyui/  # ComfyUI modules
│   │   └── [service]/1/     # Service code
│   ├── test_data/           # Test images
│   └── test_results/        # Test outputs
└── ...
```

## Testing Each Service

### Latent Encoder
```bash
cd microservices
python test_latent_encoder.py
```

### Text Encoder
```bash
python test_text_encoder.py  # (to be created)
```

### Sampling
```bash
python test_sampling.py  # (to be created)
```

### Decoding
```bash
python test_decoding.py  # (to be created)
```

## Output Files

Each test generates:
- `test_results/[service]/test_results.json` - Detailed test results
- `test_results/[service]/TRITON_CONFIG_DATA.json` - Triton configuration data

## Troubleshooting

### Models Not Downloading
- Check internet connection
- Verify Hugging Face URLs are accessible
- Models are large (GBs) - be patient

### Import Errors
- Ensure virtual environment is activated
- Run `./validate_imports.sh` to check imports

### GPU Not Detected
- Check `nvidia-smi` output
- Verify CUDA is installed
- Check PyTorch CUDA installation: `python -c "import torch; print(torch.cuda.is_available())"`

## Next Steps After Testing

1. Review `test_results/*/TRITON_CONFIG_DATA.json` files
2. Compile master config: `test_results/TRITON_MASTER_CONFIG.json`
3. Proceed to Phase 3: Create Triton config.pbtxt files
4. Proceed to Phase 4: Implement full Python backend models


## Quick Start

### 1. Clone Repository on VastAI Instance

```bash
git clone https://github.com/salahudeenofficial/vtryon2_triton.git
cd vtryon2_triton
```

### 2. Run Setup Script

```bash
cd microservices
chmod +x setup_vastai.sh
./setup_vastai.sh
```

This will:
- Install system dependencies
- Create Python virtual environment
- Install PyTorch with CUDA
- Setup ComfyUI modules
- Download all required models
- Create test directories

### 3. Activate Environment

```bash
source ../venv/bin/activate
```

### 4. Run Phase 2 Tests

```bash
cd microservices
python test_latent_encoder.py
# Repeat for other services
```

## What Gets Set Up

### Models Downloaded
- VAE Model: `qwen_image_vae.safetensors` → `triton_model_repository/shared_models/vae/`
- CLIP Model: `qwen_2.5_vl_7b_fp8_scaled.safetensors` → `triton_model_repository/shared_models/clip/`
- UNET Model: `qwen_image_edit_2509_fp8_e4m3fn.safetensors` → `triton_model_repository/shared_models/diffusion_models/`
- LoRA Model: `Qwen-Image-Lightning-4steps-V2.0.safetensors` → `triton_model_repository/shared_models/loras/`

### Directory Structure
```
vtryon2_triton/
├── venv/                    # Python virtual environment
├── microservices/
│   ├── triton_model_repository/
│   │   ├── shared_models/   # All models here
│   │   ├── shared_comfyui/  # ComfyUI modules
│   │   └── [service]/1/     # Service code
│   ├── test_data/           # Test images
│   └── test_results/        # Test outputs
└── ...
```

## Testing Each Service

### Latent Encoder
```bash
cd microservices
python test_latent_encoder.py
```

### Text Encoder
```bash
python test_text_encoder.py  # (to be created)
```

### Sampling
```bash
python test_sampling.py  # (to be created)
```

### Decoding
```bash
python test_decoding.py  # (to be created)
```

## Output Files

Each test generates:
- `test_results/[service]/test_results.json` - Detailed test results
- `test_results/[service]/TRITON_CONFIG_DATA.json` - Triton configuration data

## Troubleshooting

### Models Not Downloading
- Check internet connection
- Verify Hugging Face URLs are accessible
- Models are large (GBs) - be patient

### Import Errors
- Ensure virtual environment is activated
- Run `./validate_imports.sh` to check imports

### GPU Not Detected
- Check `nvidia-smi` output
- Verify CUDA is installed
- Check PyTorch CUDA installation: `python -c "import torch; print(torch.cuda.is_available())"`

## Next Steps After Testing

1. Review `test_results/*/TRITON_CONFIG_DATA.json` files
2. Compile master config: `test_results/TRITON_MASTER_CONFIG.json`
3. Proceed to Phase 3: Create Triton config.pbtxt files
4. Proceed to Phase 4: Implement full Python backend models







