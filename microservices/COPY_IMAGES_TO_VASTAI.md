# Copy Images to Vast AI Container

## Overview
This guide shows how to copy test images from your local machine to the Vast AI container using SCP and docker cp.

---

## 📋 Prerequisites

1. **Vast AI IP address** (e.g., `123.45.67.89`)
2. **Container name** (usually `vtryon-triton` or check with `docker ps`)
3. **SSH access** to Vast AI instance
4. **Local images** at `/home/fashionx/vtryon2/input/` or your preferred location

---

## 🚀 Method 1: Two-Step Copy (Recommended)

### Step 1: SCP to Vast AI Instance

From your **local machine**:

```bash
# Set variables
VAST_AI_IP="<your-vast-ai-ip>"  # e.g., "123.45.67.89"
CONTAINER_NAME="<container-name>"  # e.g., "vtryon-triton"

# Copy images to Vast AI instance
scp /home/fashionx/vtryon2/input/masked_person.png root@${VAST_AI_IP}:/tmp/
scp /home/fashionx/vtryon2/input/cloth.png root@${VAST_AI_IP}:/tmp/

# Or copy both at once
scp /home/fashionx/vtryon2/input/*.png root@${VAST_AI_IP}:/tmp/
```

### Step 2: Copy from Instance to Container

From your **local machine** (via SSH):

```bash
# Create directory in container
ssh root@${VAST_AI_IP} "docker exec ${CONTAINER_NAME} mkdir -p /workspace/test_images"

# Copy images into container
ssh root@${VAST_AI_IP} "docker cp /tmp/masked_person.png ${CONTAINER_NAME}:/workspace/test_images/"
ssh root@${VAST_AI_IP} "docker cp /tmp/cloth.png ${CONTAINER_NAME}:/workspace/test_images/"

# Verify files are in container
ssh root@${VAST_AI_IP} "docker exec ${CONTAINER_NAME} ls -lh /workspace/test_images/"

# Clean up temp files on instance
ssh root@${VAST_AI_IP} "rm /tmp/masked_person.png /tmp/cloth.png"
```

---

## 🚀 Method 2: All-in-One Script

Create a script on your local machine:

```bash
#!/bin/bash
# copy_images_to_vastai.sh

VAST_AI_IP="${1:-}"
CONTAINER_NAME="${2:-vtryon-triton}"
LOCAL_IMAGE_DIR="${3:-/home/fashionx/vtryon2/input}"

if [ -z "$VAST_AI_IP" ]; then
    echo "Usage: $0 <vast-ai-ip> [container-name] [local-image-dir]"
    echo "Example: $0 123.45.67.89 vtryon-triton /home/fashionx/vtryon2/input"
    exit 1
fi

echo "Copying images to Vast AI container..."
echo "IP: $VAST_AI_IP"
echo "Container: $CONTAINER_NAME"
echo "Local dir: $LOCAL_IMAGE_DIR"
echo ""

# Step 1: Copy to instance
echo "Step 1: Copying to Vast AI instance..."
scp ${LOCAL_IMAGE_DIR}/masked_person.png root@${VAST_AI_IP}:/tmp/ && echo "✓ masked_person.png"
scp ${LOCAL_IMAGE_DIR}/cloth.png root@${VAST_AI_IP}:/tmp/ && echo "✓ cloth.png"

# Step 2: Create directory in container
echo ""
echo "Step 2: Creating directory in container..."
ssh root@${VAST_AI_IP} "docker exec ${CONTAINER_NAME} mkdir -p /workspace/test_images"

# Step 3: Copy to container
echo ""
echo "Step 3: Copying to container..."
ssh root@${VAST_AI_IP} "docker cp /tmp/masked_person.png ${CONTAINER_NAME}:/workspace/test_images/" && echo "✓ masked_person.png"
ssh root@${VAST_AI_IP} "docker cp /tmp/cloth.png ${CONTAINER_NAME}:/workspace/test_images/" && echo "✓ cloth.png"

# Step 4: Verify
echo ""
echo "Step 4: Verifying files..."
ssh root@${VAST_AI_IP} "docker exec ${CONTAINER_NAME} ls -lh /workspace/test_images/"

# Step 5: Cleanup
echo ""
echo "Step 5: Cleaning up temp files..."
ssh root@${VAST_AI_IP} "rm -f /tmp/masked_person.png /tmp/cloth.png"

echo ""
echo "✅ Done! Images are now in /workspace/test_images/ inside the container"
```

**Usage:**

```bash
chmod +x copy_images_to_vastai.sh
./copy_images_to_vastai.sh <vast-ai-ip> [container-name] [local-image-dir]
```

---

## 🚀 Method 3: Direct Copy (If You Have Container Access)

If you're already SSH'd into the Vast AI instance:

```bash
# On Vast AI instance
CONTAINER_NAME="vtryon-triton"

# Create directory
docker exec ${CONTAINER_NAME} mkdir -p /workspace/test_images

# Copy from local (if you have direct access)
# This requires the container to be accessible from your local machine
docker cp /tmp/masked_person.png ${CONTAINER_NAME}:/workspace/test_images/
docker cp /tmp/cloth.png ${CONTAINER_NAME}:/workspace/test_images/

# Verify
docker exec ${CONTAINER_NAME} ls -lh /workspace/test_images/
```

---

## 🔍 Verification

After copying, verify images are accessible:

```bash
# From local machine
ssh root@${VAST_AI_IP} "docker exec ${CONTAINER_NAME} ls -lh /workspace/test_images/"

# Check file types
ssh root@${VAST_AI_IP} "docker exec ${CONTAINER_NAME} file /workspace/test_images/masked_person.png"
ssh root@${VAST_AI_IP} "docker exec ${CONTAINER_NAME} file /workspace/test_images/cloth.png"

# Check file sizes
ssh root@${VAST_AI_IP} "docker exec ${CONTAINER_NAME} du -h /workspace/test_images/*"
```

---

## 📝 Quick Reference

```bash
# Set variables
export VAST_AI_IP="123.45.67.89"
export CONTAINER_NAME="vtryon-triton"

# Copy images (Method 1)
scp /home/fashionx/vtryon2/input/*.png root@${VAST_AI_IP}:/tmp/
ssh root@${VAST_AI_IP} "docker exec ${CONTAINER_NAME} mkdir -p /workspace/test_images"
ssh root@${VAST_AI_IP} "docker cp /tmp/masked_person.png ${CONTAINER_NAME}:/workspace/test_images/"
ssh root@${VAST_AI_IP} "docker cp /tmp/cloth.png ${CONTAINER_NAME}:/workspace/test_images/"
ssh root@${VAST_AI_IP} "docker exec ${CONTAINER_NAME} ls -lh /workspace/test_images/"
ssh root@${VAST_AI_IP} "rm /tmp/*.png"
```

---

## 🚨 Troubleshooting

### SSH Connection Issues

```bash
# Test SSH connection
ssh -v root@${VAST_AI_IP}

# Check SSH key
ssh-add -l
```

### Container Not Found

```bash
# List containers on Vast AI
ssh root@${VAST_AI_IP} "docker ps -a"

# Get container name
ssh root@${VAST_AI_IP} "docker ps --format '{{.Names}}'"
```

### Files Not Appearing in Container

```bash
# Check if directory exists
ssh root@${VAST_AI_IP} "docker exec ${CONTAINER_NAME} ls -la /workspace/"

# Check permissions
ssh root@${VAST_AI_IP} "docker exec ${CONTAINER_NAME} ls -la /workspace/test_images/"

# Try copying again with verbose output
ssh root@${VAST_AI_IP} "docker cp -v /tmp/masked_person.png ${CONTAINER_NAME}:/workspace/test_images/"
```

### Permission Denied

```bash
# Check container user
ssh root@${VAST_AI_IP} "docker exec ${CONTAINER_NAME} whoami"

# If needed, change ownership
ssh root@${VAST_AI_IP} "docker exec ${CONTAINER_NAME} chown -R root:root /workspace/test_images"
```

---

## ✅ After Copying

Once images are in place, you can use this JSON in Postman:

```json
{
  "inputs": [
    {
      "name": "image1_path",
      "shape": [1, 1],
      "datatype": "BYTES",
      "data": [["/workspace/test_images/masked_person.png"]]
    },
    {
      "name": "image2_path",
      "shape": [1, 1],
      "datatype": "BYTES",
      "data": [["/workspace/test_images/cloth.png"]]
    },
    {
      "name": "prompt",
      "shape": [1, 1],
      "datatype": "BYTES",
      "data": [["by using the green masked area, try on the cloth"]]
    },
    {
      "name": "seed",
      "shape": [1, 1],
      "datatype": "INT64",
      "data": [[42]]
    }
  ],
  "outputs": [{"name": "output_image"}]
}
```

---

## Summary

The workflow is:
1. **SCP** images from local → Vast AI instance (`/tmp/`)
2. **docker cp** images from instance → container (`/workspace/test_images/`)
3. **Verify** files are in place
4. **Clean up** temp files on instance
5. **Test** with Postman using the JSON above


