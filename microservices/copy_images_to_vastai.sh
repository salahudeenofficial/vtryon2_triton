#!/bin/bash
# Script to copy test images from local machine to Vast AI container
# Usage: ./copy_images_to_vastai.sh <vast-ai-ip> [container-name] [local-image-dir]

set -e

VAST_AI_IP="${1:-}"
CONTAINER_NAME="${2:-vtryon-triton}"
LOCAL_IMAGE_DIR="${3:-/home/fashionx/vtryon2/input}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ -z "$VAST_AI_IP" ]; then
    echo -e "${RED}✗ Vast AI IP required${NC}"
    echo ""
    echo "Usage: $0 <vast-ai-ip> [container-name] [local-image-dir]"
    echo ""
    echo "Example:"
    echo "  $0 123.45.67.89"
    echo "  $0 123.45.67.89 vtryon-triton /home/fashionx/vtryon2/input"
    exit 1
fi

echo "=========================================="
echo "Copying Images to Vast AI Container"
echo "=========================================="
echo ""
echo "Vast AI IP: $VAST_AI_IP"
echo "Container: $CONTAINER_NAME"
echo "Local dir: $LOCAL_IMAGE_DIR"
echo ""

# Test SSH connection
echo "Testing SSH connection..."
if ! ssh -o ConnectTimeout=5 "root@${VAST_AI_IP}" "echo 'Connected'" > /dev/null 2>&1; then
    echo -e "${RED}✗ Cannot connect to Vast AI instance${NC}"
    echo ""
    echo "Make sure:"
    echo "1. SSH key is set up"
    echo "2. IP address is correct"
    echo "3. Instance is running"
    exit 1
fi
echo -e "${GREEN}✓ Connected${NC}"
echo ""

# Check if container exists
echo "Checking container..."
if ! ssh "root@${VAST_AI_IP}" "docker ps --format '{{.Names}}' | grep -q '^${CONTAINER_NAME}$'"; then
    echo -e "${YELLOW}⚠ Container '$CONTAINER_NAME' not found${NC}"
    echo ""
    echo "Available containers:"
    ssh "root@${VAST_AI_IP}" "docker ps --format '{{.Names}}'"
    echo ""
    read -p "Enter container name: " CONTAINER_NAME
    if [ -z "$CONTAINER_NAME" ]; then
        echo -e "${RED}✗ Container name required${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✓ Container found${NC}"
echo ""

# Check if local images exist
echo "Checking local images..."
MISSING_IMAGES=0
if [ ! -f "${LOCAL_IMAGE_DIR}/masked_person.png" ]; then
    echo -e "${YELLOW}⚠ masked_person.png not found in ${LOCAL_IMAGE_DIR}${NC}"
    MISSING_IMAGES=1
else
    echo -e "${GREEN}✓ masked_person.png found${NC}"
fi

if [ ! -f "${LOCAL_IMAGE_DIR}/cloth.png" ]; then
    echo -e "${YELLOW}⚠ cloth.png not found in ${LOCAL_IMAGE_DIR}${NC}"
    MISSING_IMAGES=1
else
    echo -e "${GREEN}✓ cloth.png found${NC}"
fi

if [ $MISSING_IMAGES -eq 1 ]; then
    echo ""
    echo "Available images in ${LOCAL_IMAGE_DIR}:"
    ls -lh "${LOCAL_IMAGE_DIR}"/*.png 2>/dev/null || echo "No PNG files found"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo ""

# Step 1: Copy to instance
echo "=========================================="
echo "Step 1: Copying to Vast AI instance"
echo "=========================================="
echo ""

if [ -f "${LOCAL_IMAGE_DIR}/masked_person.png" ]; then
    echo -e "${BLUE}Copying masked_person.png...${NC}"
    if scp "${LOCAL_IMAGE_DIR}/masked_person.png" "root@${VAST_AI_IP}:/tmp/" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ masked_person.png copied${NC}"
    else
        echo -e "${RED}✗ Failed to copy masked_person.png${NC}"
        exit 1
    fi
fi

if [ -f "${LOCAL_IMAGE_DIR}/cloth.png" ]; then
    echo -e "${BLUE}Copying cloth.png...${NC}"
    if scp "${LOCAL_IMAGE_DIR}/cloth.png" "root@${VAST_AI_IP}:/tmp/" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ cloth.png copied${NC}"
    else
        echo -e "${RED}✗ Failed to copy cloth.png${NC}"
        exit 1
    fi
fi

# Step 2: Create directory in container
echo ""
echo "=========================================="
echo "Step 2: Creating directory in container"
echo "=========================================="
echo ""

if ssh "root@${VAST_AI_IP}" "docker exec ${CONTAINER_NAME} mkdir -p /workspace/test_images" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Directory created${NC}"
else
    echo -e "${RED}✗ Failed to create directory${NC}"
    exit 1
fi

# Step 3: Copy to container
echo ""
echo "=========================================="
echo "Step 3: Copying to container"
echo "=========================================="
echo ""

if [ -f "${LOCAL_IMAGE_DIR}/masked_person.png" ]; then
    echo -e "${BLUE}Copying masked_person.png to container...${NC}"
    if ssh "root@${VAST_AI_IP}" "docker cp /tmp/masked_person.png ${CONTAINER_NAME}:/workspace/test_images/" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ masked_person.png in container${NC}"
    else
        echo -e "${RED}✗ Failed to copy to container${NC}"
        exit 1
    fi
fi

if [ -f "${LOCAL_IMAGE_DIR}/cloth.png" ]; then
    echo -e "${BLUE}Copying cloth.png to container...${NC}"
    if ssh "root@${VAST_AI_IP}" "docker cp /tmp/cloth.png ${CONTAINER_NAME}:/workspace/test_images/" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ cloth.png in container${NC}"
    else
        echo -e "${RED}✗ Failed to copy to container${NC}"
        exit 1
    fi
fi

# Step 4: Verify
echo ""
echo "=========================================="
echo "Step 4: Verifying files"
echo "=========================================="
echo ""

echo "Files in /workspace/test_images/:"
ssh "root@${VAST_AI_IP}" "docker exec ${CONTAINER_NAME} ls -lh /workspace/test_images/" || true

echo ""
echo "File types:"
if ssh "root@${VAST_AI_IP}" "docker exec ${CONTAINER_NAME} test -f /workspace/test_images/masked_person.png" > /dev/null 2>&1; then
    ssh "root@${VAST_AI_IP}" "docker exec ${CONTAINER_NAME} file /workspace/test_images/masked_person.png" || true
fi
if ssh "root@${VAST_AI_IP}" "docker exec ${CONTAINER_NAME} test -f /workspace/test_images/cloth.png" > /dev/null 2>&1; then
    ssh "root@${VAST_AI_IP}" "docker exec ${CONTAINER_NAME} file /workspace/test_images/cloth.png" || true
fi

# Step 5: Cleanup
echo ""
echo "=========================================="
echo "Step 5: Cleaning up temp files"
echo "=========================================="
echo ""

ssh "root@${VAST_AI_IP}" "rm -f /tmp/masked_person.png /tmp/cloth.png" > /dev/null 2>&1 || true
echo -e "${GREEN}✓ Temp files cleaned up${NC}"

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Done! Images are now in /workspace/test_images/ inside the container${NC}"
echo "=========================================="
echo ""
echo "You can now use this JSON in Postman:"
echo ""
cat << 'JSON'
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
JSON


