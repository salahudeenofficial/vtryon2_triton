# VastAI Access Guide

## Your Instance Details

- **Public IP**: `54.211.121.23`
- **External Port**: `8484` (maps to internal port 8000)
- **Internal Port**: `8000` (inside container)

---

## Accessing Triton Server

### From Inside VastAI Instance (SSH)

```bash
# Test health
curl http://localhost:8000/v2/health/ready

# List models
curl http://localhost:8000/v2/models

# Get model info
curl http://localhost:8000/v2/models/vtryon_pipeline
```

### From Your Local Machine

```bash
# Test health
curl http://54.211.121.23:8484/v2/health/ready

# List models
curl http://54.211.121.23:8484/v2/models

# Get model info
curl http://54.211.121.23:8484/v2/models/vtryon_pipeline
```

### From Browser

Open in your browser:
```
http://54.211.121.23:8484/v2/health/ready
http://54.211.121.23:8484/v2/models
```

---

## Port Mapping

VastAI maps ports as follows:

| Internal Port | External Port | Service |
|--------------|---------------|---------|
| 8000 | 8484 | HTTP API |
| 8001 | (check VastAI dashboard) | gRPC API |
| 8002 | (check VastAI dashboard) | Metrics |

**Note**: Check VastAI dashboard for gRPC (8001) and Metrics (8002) external ports.

---

## Testing Steps

### Step 1: Test from Inside VastAI

```bash
# SSH into VastAI instance
# Then test:
curl http://localhost:8000/v2/health/ready
```

**Expected**: `{"status":"ready"}` or connection error if not running

### Step 2: Test from Your Local Machine

```bash
# From your local machine
curl http://54.211.121.23:8484/v2/health/ready
```

**Expected**: `{"status":"ready"}` or connection error if not accessible

### Step 3: If Connection Refused

Check container status:
```bash
# On VastAI instance
docker ps
docker logs $(docker ps -q)
```

---

## Troubleshooting

### Connection Refused from Local Machine

**Possible causes**:
1. Container not running
2. VastAI firewall blocking port
3. Port mapping incorrect

**Solutions**:
```bash
# On VastAI instance, check container
docker ps

# Check if port 8000 is listening
netstat -tlnp | grep 8000

# Check VastAI dashboard for port mapping
# Ensure port 8484 is correctly mapped to 8000
```

### Connection Works Inside But Not Outside

**Check**:
1. VastAI firewall settings
2. Port mapping in VastAI dashboard
3. Security groups/network rules

### Container Not Running

```bash
# Start container
docker start $(docker ps -aq | head -1)

# Or create new one
docker run -d \
  --name vtryon-triton \
  --gpus all \
  --shm-size=4g \
  --restart unless-stopped \
  -p 8000:8000 \
  -p 8001:8001 \
  -p 8002:8002 \
  salafashionx/vtryon-triton:latest
```

---

## Complete API Endpoints

### Health Check
```bash
# Internal
curl http://localhost:8000/v2/health/ready

# External
curl http://54.211.121.23:8484/v2/health/ready
```

### List Models
```bash
# Internal
curl http://localhost:8000/v2/models

# External
curl http://54.211.121.23:8484/v2/models
```

### Model Info
```bash
# Internal
curl http://localhost:8000/v2/models/vtryon_pipeline

# External
curl http://54.211.121.23:8484/v2/models/vtryon_pipeline
```

### Inference (Example)
```bash
# Internal
curl -X POST http://localhost:8000/v2/models/vtryon_pipeline/infer \
  -H "Content-Type: application/json" \
  -d '{...}'

# External
curl -X POST http://54.211.121.23:8484/v2/models/vtryon_pipeline/infer \
  -H "Content-Type: application/json" \
  -d '{...}'
```

---

## Quick Test Commands

### From VastAI Instance:
```bash
# 1. Check container
docker ps

# 2. Test internal
curl http://localhost:8000/v2/health/ready

# 3. Check logs
docker logs $(docker ps -q) | tail -20
```

### From Your Local Machine:
```bash
# 1. Test external access
curl http://54.211.121.23:8484/v2/health/ready

# 2. List models
curl http://54.211.121.23:8484/v2/models

# 3. Test with timeout
curl --connect-timeout 10 http://54.211.121.23:8484/v2/health/ready
```

---

## Security Notes

⚠️ **Important**: Your Triton server is accessible from the internet.

Consider:
- Adding authentication (if Triton supports it)
- Using HTTPS (if available)
- Restricting access by IP (VastAI firewall)
- Using VPN or SSH tunnel for production

---

## Next Steps

1. ✅ Test from inside VastAI: `curl http://localhost:8000/v2/health/ready`
2. ✅ Test from local machine: `curl http://54.211.121.23:8484/v2/health/ready`
3. ✅ Verify models loaded: `curl http://54.211.121.23:8484/v2/models`
4. ✅ Test inference with your API

