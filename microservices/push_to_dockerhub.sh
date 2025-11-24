#!/bin/bash
# Script to tag and push Triton image to DockerHub

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
IMAGE_NAME="vtryon-triton"
IMAGE_TAG="latest"
LOCAL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

# Get DockerHub username
if [ -z "$DOCKERHUB_USER" ]; then
    echo -e "${YELLOW}DockerHub username not set.${NC}"
    echo "Please set it with: export DOCKERHUB_USER=your-username"
    echo ""
    read -p "Enter your DockerHub username: " DOCKERHUB_USER
    if [ -z "$DOCKERHUB_USER" ]; then
        echo -e "${RED}Error: DockerHub username is required${NC}"
        exit 1
    fi
fi

REMOTE_IMAGE="${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Push Triton Image to DockerHub${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Local image:  ${LOCAL_IMAGE}"
echo "Remote image: ${REMOTE_IMAGE}"
echo ""

# Check if local image exists
if ! docker images | grep -q "^${IMAGE_NAME}"; then
    echo -e "${RED}Error: Image ${LOCAL_IMAGE} not found${NC}"
    echo "Please build the image first: ./build_triton_image.sh"
    exit 1
fi

# Login to DockerHub
echo -e "${YELLOW}Logging in to DockerHub...${NC}"
if ! docker login; then
    echo -e "${RED}Error: DockerHub login failed${NC}"
    exit 1
fi

# Tag image
echo -e "${YELLOW}Tagging image...${NC}"
docker tag "${LOCAL_IMAGE}" "${REMOTE_IMAGE}"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Image tagged: ${REMOTE_IMAGE}${NC}"
else
    echo -e "${RED}Error: Failed to tag image${NC}"
    exit 1
fi

# Push image
echo ""
echo -e "${YELLOW}Pushing image to DockerHub...${NC}"
echo "This may take several minutes (image is ~18GB)..."
echo ""

docker push "${REMOTE_IMAGE}"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ Image pushed successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Image available at: ${REMOTE_IMAGE}"
    echo ""
    echo "Next steps for VastAI:"
    echo "1. Create a VastAI instance with GPU"
    echo "2. Use Docker image: ${REMOTE_IMAGE}"
    echo "3. Expose ports: 8000, 8001, 8002"
    echo "4. Download models inside container or mount volume"
    echo ""
else
    echo -e "${RED}Error: Failed to push image${NC}"
    exit 1
fi



