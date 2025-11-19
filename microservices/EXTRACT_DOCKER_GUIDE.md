# Extracting Triton from Docker Image - Complete Guide

## Overview

Since your VastAI instance is a container and Docker daemon isn't available, we have several methods to extract the Triton server from Docker images.

## Method 1: Podman (Recommended for Docker Images)

**Script:** `extract_from_docker_image.sh`

```bash
cd /workspace/vtryon2_triton/microservices
chmod +x extract_from_docker_image.sh
./extract_from_docker_image.sh
```

**If you get permission errors:**

```bash
# Try with sudo
sudo podman pull nvcr.io/nvidia/tritonserver:25.10-py3
sudo podman create nvcr.io/nvidia/tritonserver:25.10-py3 /bin/true
# Get container ID from output, then:
CONTAINER_ID=<container-id>
sudo podman cp ${CONTAINER_ID}:/opt/tritonserver/bin/tritonserver ./tritonserver/bin/tritonserver
sudo podman rm ${CONTAINER_ID}
```

## Method 2: Skopeo (Alternative, No Daemon Needed)

**Script:** `extract_from_docker_skopeo.sh`

```bash
cd /workspace/vtryon2_triton/microservices
chmod +x extract_from_docker_skopeo.sh
./extract_from_docker_skopeo.sh
```

**What it does:**
- Uses `skopeo` to copy Docker image to OCI format
- Extracts files without needing a container runtime
- Works in restricted environments

**Install skopeo if needed:**
```bash
sudo apt-get update
sudo apt-get install -y skopeo
```

## Method 3: Manual Extraction with Podman

If the script fails, try manual steps:

```bash
# 1. Pull image
sudo podman pull nvcr.io/nvidia/tritonserver:25.10-py3

# 2. Create container
CONTAINER_ID=$(sudo podman create nvcr.io/nvidia/tritonserver:25.10-py3 /bin/true)

# 3. Extract binary
mkdir -p tritonserver/bin
sudo podman cp ${CONTAINER_ID}:/opt/tritonserver/bin/tritonserver tritonserver/bin/tritonserver

# 4. Extract libraries (optional)
sudo podman cp ${CONTAINER_ID}:/opt/tritonserver/lib tritonserver/

# 5. Cleanup
sudo podman rm ${CONTAINER_ID}

# 6. Make executable
chmod +x tritonserver/bin/tritonserver

# 7. Verify
./tritonserver/bin/tritonserver --version
```

## Method 4: Download Server Binary Directly (Simplest)

If Docker extraction is problematic, just download the binary:

```bash
cd /workspace/vtryon2_triton/microservices
chmod +x download_triton_server.sh
./download_triton_server.sh
```

This downloads the Triton server binary from GitHub releases (no Docker needed).

## Troubleshooting

### "cannot clone: Operation not permitted"

This means podman can't create namespaces. Solutions:

1. **Use sudo:**
   ```bash
   sudo podman pull nvcr.io/nvidia/tritonserver:25.10-py3
   ```

2. **Use skopeo instead:**
   ```bash
   ./extract_from_docker_skopeo.sh
   ```

3. **Download binary directly:**
   ```bash
   ./download_triton_server.sh
   ```

### "failed to connect to docker API"

This is expected - you're in a container without Docker daemon. Use podman or skopeo instead.

### "Permission denied" when copying files

Use sudo for podman commands:
```bash
sudo podman cp <container-id>:/opt/tritonserver/bin/tritonserver ./tritonserver/bin/tritonserver
```

## Recommended Approach

For your containerized VastAI environment:

1. **First try:** `extract_from_docker_image.sh` (with sudo if needed)
2. **If that fails:** `extract_from_docker_skopeo.sh`
3. **If both fail:** `download_triton_server.sh` (simplest, no Docker)

## After Extraction

Once you have the binary:

```bash
# Verify
./tritonserver/bin/tritonserver --version

# Start Triton
./start_triton_direct.sh
```

