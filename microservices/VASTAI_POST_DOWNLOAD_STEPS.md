# Post-Download Steps: Starting Triton Server

## Current Status

✅ **Triton server is already running** - it starts automatically when the Docker container starts.

However, **you need to restart it** after downloading models so it can detect and load them.

---

## Why Restart is Needed

Triton server:
- ✅ Starts automatically when container starts
- ✅ Scans `/models` directory on startup
- ❌ Does NOT automatically detect new files added after startup
- ✅ Needs restart to scan and load new models

---

## Step-by-Step: After Model Download Completes

### Step 1: Verify All Models Downloaded

```bash
# Check all models are present
du -sh /models/shared_models/*

# Should show:
# - vae: ~500 MB
# - clip: ~7 GB
# - diffusion_models: ~3 GB
# - loras: ~100 MB

# List files
ls -lh /models/shared_models/vae/
ls -lh /models/shared_models/clip/
ls -lh /models/shared_models/diffusion_models/
ls -lh /models/shared_models/loras/
```

### Step 2: Restart Container

```bash
# Find container ID/name
docker ps

# Restart container (this restarts Triton server)
docker restart $(docker ps -q)

# Or if you know the name
docker restart <container-name>
```

### Step 3: Wait for Triton to Load Models

```bash
# Watch logs to see models loading
docker logs -f $(docker ps -q)

# Look for messages like:
# - "Loading model: latent_encoder"
# - "Loading model: text_encoder"  
# - "Loading model: sampling"
# - "Loading model: decoding"
# - "Loading model: vtryon_pipeline"
# - "Server is ready"
```

**Wait time**: 1-3 minutes for all models to load

### Step 4: Verify Server is Ready

```bash
# Check health
curl http://localhost:8000/v2/health/ready

# Should return: {"status":"ready"}

# List all loaded models
curl http://localhost:8000/v2/models

# Should show all 5 models:
# - latent_encoder
# - text_encoder
# - sampling
# - decoding
# - vtryon_pipeline (ensemble)
```

### Step 5: Test External Access

Get your VastAI public IP and port from the dashboard:

```bash
# From your local machine
curl http://<vastai-ip>:<port>/v2/health/ready
curl http://<vastai-ip>:<port>/v2/models
```

---

## Quick Commands Summary

```bash
# 1. Verify models downloaded
du -sh /models/shared_models/*

# 2. Restart container
docker restart $(docker ps -q)

# 3. Watch logs (wait 1-3 minutes)
docker logs -f $(docker ps -q)

# 4. Test server
curl http://localhost:8000/v2/health/ready
curl http://localhost:8000/v2/models
```

---

## What Happens During Restart

1. **Container stops** → Triton server stops
2. **Container starts** → Triton server starts
3. **Triton scans** `/models` directory
4. **Triton loads** all models it finds:
   - Checks each model directory
   - Validates `config.pbtxt`
   - Loads model files
   - Initializes model instances
5. **Triton becomes ready** → All models available

---

## Troubleshooting

### Server Not Ready After Restart

```bash
# Check logs for errors
docker logs $(docker ps -q) | tail -100

# Common issues:
# - Missing model files
# - Invalid config.pbtxt
# - GPU memory issues
# - Model loading errors
```

### Models Not Showing Up

```bash
# Verify models exist
ls -lh /models/shared_models/*/

# Check Triton can see them
docker exec $(docker ps -q) ls -la /models/

# Check model repository structure
docker exec $(docker ps -q) find /models -name "config.pbtxt"
```

### Server Takes Too Long

Large models take time to load:
- CLIP model (~7 GB): 30-60 seconds
- UNET model (~3 GB): 20-40 seconds
- Total: 1-3 minutes is normal

Be patient and watch the logs.

---

## Expected Timeline

1. **Download models**: 10-30 minutes
2. **Restart container**: 10 seconds
3. **Triton loads models**: 1-3 minutes
4. **Server ready**: Total ~15-35 minutes

---

## Success Indicators

✅ Container restarted successfully  
✅ Logs show "Loading model: ..." for each model  
✅ `curl http://localhost:8000/v2/health/ready` returns `{"status":"ready"}`  
✅ `curl http://localhost:8000/v2/models` shows all 5 models  
✅ No error messages in logs

---

## Next Steps After Server is Ready

1. ✅ Test inference with sample requests
2. ✅ Monitor GPU usage: `docker exec $(docker ps -q) nvidia-smi`
3. ✅ Test from your local machine using VastAI IP
4. ✅ Integrate with your application

