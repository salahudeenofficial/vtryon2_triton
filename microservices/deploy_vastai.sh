#!/bin/bash
# Complete deployment script for VastAI
# This script pulls the Docker image and runs it on VastAI

set -e

# Configuration
IMAGE_NAME="${DOCKER_IMAGE_NAME:-your-username/vtryon-triton:latest}"
CONTAINER_NAME="vtryon-triton"
SHM_SIZE="${SHM_SIZE:-4g}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Deploying VTryon Triton Server on VastAI${NC}"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Check if image name is set
if [ "$IMAGE_NAME" = "your-username/vtryon-triton:latest" ]; then
    echo -e "${YELLOW}Warning: Using default image name${NC}"
    echo "Set DOCKER_IMAGE_NAME environment variable to use your image"
    echo "Example: export DOCKER_IMAGE_NAME=myusername/vtryon-triton:latest"
    echo ""
fi

# Pull image
echo -e "${YELLOW}Pulling Docker image: ${IMAGE_NAME}${NC}"
docker pull "$IMAGE_NAME" || {
    echo -e "${RED}Error: Failed to pull image${NC}"
    echo "Make sure:"
    echo "1. Image exists on DockerHub"
    echo "2. You're logged in: docker login"
    exit 1
}

# Stop existing container if running
if docker ps -a | grep -q "$CONTAINER_NAME"; then
    echo -e "${YELLOW}Stopping existing container...${NC}"
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
fi

# Get current directory for volume mounts
CURRENT_DIR=$(pwd)
MODELS_DIR="${CURRENT_DIR}/triton_model_repository/shared_models"
COMFYUI_DIR="${CURRENT_DIR}/triton_model_repository/shared_comfyui"

# Check if models directory exists (optional - models can be in image or mounted)
VOLUME_ARGS=""
if [ -d "$MODELS_DIR" ]; then
    echo -e "${GREEN}Found models directory, mounting as volume${NC}"
    VOLUME_ARGS="-v ${MODELS_DIR}:/models/shared_models:ro"
fi

if [ -d "$COMFYUI_DIR" ]; then
    echo -e "${GREEN}Found ComfyUI directory, mounting as volume${NC}"
    VOLUME_ARGS="${VOLUME_ARGS} -v ${COMFYUI_DIR}:/models/shared_comfyui:ro"
fi

# Run container
echo -e "${YELLOW}Starting Triton server container...${NC}"
docker run -d \
  --name "$CONTAINER_NAME" \
  --gpus all \
  --shm-size="$SHM_SIZE" \
  --restart unless-stopped \
  -p 8000:8000 \
  -p 8001:8001 \
  -p 8002:8002 \
  $VOLUME_ARGS \
  "$IMAGE_NAME"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Container started successfully${NC}"
    echo ""
    echo "Waiting for server to initialize..."
    sleep 10
    
    # Check server status
    echo -e "${YELLOW}Checking server health...${NC}"
    if curl -s http://localhost:8000/v2/health/ready | grep -q "ready"; then
        echo -e "${GREEN}✓ Server is ready!${NC}"
    else
        echo -e "${YELLOW}⚠ Server may still be starting${NC}"
        echo "Check logs with: docker logs $CONTAINER_NAME"
    fi
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Deployment Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Server endpoints:"
    echo "  - HTTP:    http://localhost:8000"
    echo "  - gRPC:    localhost:8001"
    echo "  - Metrics: http://localhost:8002/metrics"
    echo ""
    echo "Useful commands:"
    echo "  - View logs:    docker logs -f $CONTAINER_NAME"
    echo "  - Stop server:  docker stop $CONTAINER_NAME"
    echo "  - Restart:      docker restart $CONTAINER_NAME"
    echo "  - Shell access: docker exec -it $CONTAINER_NAME bash"
    echo ""
else
    echo -e "${RED}Error: Failed to start container${NC}"
    echo "Check logs with: docker logs $CONTAINER_NAME"
    exit 1
fi

# Complete deployment script for VastAI
# This script pulls the Docker image and runs it on VastAI

set -e

# Configuration
IMAGE_NAME="${DOCKER_IMAGE_NAME:-your-username/vtryon-triton:latest}"
CONTAINER_NAME="vtryon-triton"
SHM_SIZE="${SHM_SIZE:-4g}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Deploying VTryon Triton Server on VastAI${NC}"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Check if image name is set
if [ "$IMAGE_NAME" = "your-username/vtryon-triton:latest" ]; then
    echo -e "${YELLOW}Warning: Using default image name${NC}"
    echo "Set DOCKER_IMAGE_NAME environment variable to use your image"
    echo "Example: export DOCKER_IMAGE_NAME=myusername/vtryon-triton:latest"
    echo ""
fi

# Pull image
echo -e "${YELLOW}Pulling Docker image: ${IMAGE_NAME}${NC}"
docker pull "$IMAGE_NAME" || {
    echo -e "${RED}Error: Failed to pull image${NC}"
    echo "Make sure:"
    echo "1. Image exists on DockerHub"
    echo "2. You're logged in: docker login"
    exit 1
}

# Stop existing container if running
if docker ps -a | grep -q "$CONTAINER_NAME"; then
    echo -e "${YELLOW}Stopping existing container...${NC}"
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
fi

# Get current directory for volume mounts
CURRENT_DIR=$(pwd)
MODELS_DIR="${CURRENT_DIR}/triton_model_repository/shared_models"
COMFYUI_DIR="${CURRENT_DIR}/triton_model_repository/shared_comfyui"

# Check if models directory exists (optional - models can be in image or mounted)
VOLUME_ARGS=""
if [ -d "$MODELS_DIR" ]; then
    echo -e "${GREEN}Found models directory, mounting as volume${NC}"
    VOLUME_ARGS="-v ${MODELS_DIR}:/models/shared_models:ro"
fi

if [ -d "$COMFYUI_DIR" ]; then
    echo -e "${GREEN}Found ComfyUI directory, mounting as volume${NC}"
    VOLUME_ARGS="${VOLUME_ARGS} -v ${COMFYUI_DIR}:/models/shared_comfyui:ro"
fi

# Run container
echo -e "${YELLOW}Starting Triton server container...${NC}"
docker run -d \
  --name "$CONTAINER_NAME" \
  --gpus all \
  --shm-size="$SHM_SIZE" \
  --restart unless-stopped \
  -p 8000:8000 \
  -p 8001:8001 \
  -p 8002:8002 \
  $VOLUME_ARGS \
  "$IMAGE_NAME"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Container started successfully${NC}"
    echo ""
    echo "Waiting for server to initialize..."
    sleep 10
    
    # Check server status
    echo -e "${YELLOW}Checking server health...${NC}"
    if curl -s http://localhost:8000/v2/health/ready | grep -q "ready"; then
        echo -e "${GREEN}✓ Server is ready!${NC}"
    else
        echo -e "${YELLOW}⚠ Server may still be starting${NC}"
        echo "Check logs with: docker logs $CONTAINER_NAME"
    fi
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Deployment Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Server endpoints:"
    echo "  - HTTP:    http://localhost:8000"
    echo "  - gRPC:    localhost:8001"
    echo "  - Metrics: http://localhost:8002/metrics"
    echo ""
    echo "Useful commands:"
    echo "  - View logs:    docker logs -f $CONTAINER_NAME"
    echo "  - Stop server:  docker stop $CONTAINER_NAME"
    echo "  - Restart:      docker restart $CONTAINER_NAME"
    echo "  - Shell access: docker exec -it $CONTAINER_NAME bash"
    echo ""
else
    echo -e "${RED}Error: Failed to start container${NC}"
    echo "Check logs with: docker logs $CONTAINER_NAME"
    exit 1
fi







