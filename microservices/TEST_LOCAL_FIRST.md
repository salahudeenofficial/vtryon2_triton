# Test Ensemble Locally First

## Strategy

Before building Docker image, we'll:
1. ✅ Set up local Python environment
2. ✅ Test each service individually
3. ✅ Test complete ensemble pipeline
4. ✅ Fix any issues
5. ✅ Update Dockerfile with correct requirements
6. ✅ Build Docker image

---

## Step 1: Setup Local Environment

```bash
cd /home/fashionx/vtryon2/microservices

# Setup Python environment
chmod +x setup_local_env.sh
./setup_local_env.sh

# Activate environment
source venv/bin/activate
```

---

## Step 2: Test Individual Services

### Test Latent Encoder

```bash
python test_latent_encoder.py
```

### Test Text Encoder

```bash
python test_text_encoder.py
```

### Test Sampling

```bash
python test_sampling.py
```

### Test Decoding

```bash
python test_decoding.py
```

---

## Step 3: Test Complete Ensemble

```bash
# Make sure you have test images
# input/person.jpg and input/cloth.jpg

python test_ensemble_local.py
```

This will:
- Call each service in sequence
- Verify tensor shapes match
- Check for import errors
- Test complete pipeline

---

## Step 4: Fix Issues

If any service fails:

1. **Check imports**: Make sure all Python packages are installed
2. **Check paths**: Verify ComfyUI and model paths are correct
3. **Check dependencies**: Install missing packages
4. **Update requirements**: Add any missing packages to requirements.txt

---

## Step 5: Update Dockerfile

Once ensemble works locally:

1. **Document all installed packages**:
   ```bash
   pip freeze > requirements_all.txt
   ```

2. **Update Dockerfile.triton** with all requirements

3. **Rebuild Docker image**

---

## Common Issues

### Import Errors

```bash
# Check what's missing
python -c "import torch; import numpy; import PIL"

# Install missing packages
pip install <package-name>
```

### Path Errors

```bash
# Check ComfyUI path
ls -la triton_model_repository/shared_comfyui/comfy/

# Check model paths
ls -la triton_model_repository/shared_models/
```

### CUDA/GPU Issues

```bash
# Check CUDA
python -c "import torch; print(torch.cuda.is_available())"

# Check GPU
nvidia-smi
```

---

## Next Steps After Local Test Passes

1. ✅ All services work locally
2. ✅ Ensemble pipeline works
3. ✅ Update Dockerfile with all requirements
4. ✅ Build Docker image
5. ✅ Push to DockerHub
6. ✅ Deploy on VastAI

---

## Quick Test Command

```bash
# One command to test everything
source venv/bin/activate && \
python test_latent_encoder.py && \
python test_text_encoder.py && \
python test_sampling.py && \
python test_decoding.py && \
python test_ensemble_local.py && \
echo "✓ All tests passed!"
```

