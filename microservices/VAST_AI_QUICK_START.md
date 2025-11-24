# Vast AI Quick Start Guide

## 🚀 Quick Deployment

### Step 1: Push Image

```bash
# Tag and push
docker tag vtryon-triton:latest <registry>/vtryon-triton:latest
docker push <registry>/vtryon-triton:latest
```

### Step 2: Deploy on Vast AI

1. Create instance with your Docker image
2. Expose ports: 8000, 8001, 8002
3. Connect via SSH

### Step 3: Initial Health Check

```bash
# On Vast AI instance
curl http://localhost:8000/v2/health/ready
curl http://localhost:8000/v2/models | python3 -m json.tool
```

---

## 🐛 Quick Debugging

### Check Status
```bash
docker ps
docker logs <container-name> -f
```

### Test Individual Model
```bash
curl -X POST http://localhost:8000/v2/models/latent_encoder/infer \
  -H "Content-Type: application/json" \
  -d '{"inputs": [...], "outputs": [...]}'
```

### Copy Fixes Back
```bash
# From local machine (if you have SSH access)
docker cp <container>:/models/latent_encoder/1/model.py ./triton_model_repository/latent_encoder/1/model.py
```

---

## 📋 Testing Checklist

- [ ] Container starts
- [ ] Triton server becomes ready
- [ ] All 5 models load (latent_encoder, text_encoder, sampling, decoding, vtryon_pipeline)
- [ ] Health endpoints respond
- [ ] Model metadata accessible
- [ ] Inference request reaches models (even if fails due to missing files)

---

## 🔧 Common Issues

### Models not loading
→ Check logs: `docker logs <container> | grep -i error`

### OOM errors
→ Monitor: `watch -n 1 nvidia-smi`

### Import errors
→ Test: `docker exec <container> python3 -c "import sys; sys.path.insert(0, '/workspace/shared_comfyui'); import comfy"`

---

## 📞 Need Help?

See full guide: `VAST_AI_TESTING_DEBUGGING_PLAN.md`


