#!/bin/bash
# Build Triton Docker image for VastAI deployment

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Building Triton Docker Image${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Image configuration
IMAGE_NAME="${DOCKER_IMAGE_NAME:-vtryon-triton}"
IMAGE_TAG="${DOCKER_IMAGE_TAG:-latest}"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

# DockerHub username (set via environment variable)
DOCKERHUB_USER="${DOCKERHUB_USER:-your-username}"

echo "Image name: ${DOCKERHUB_USER}/${FULL_IMAGE_NAME}"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    exit 1
fi

# Check if model repository exists
if [ ! -d "triton_model_repository" ]; then
    echo "Error: triton_model_repository directory not found!"
    echo "Please run from microservices/ directory"
    exit 1
fi

# Build Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
docker build -f Dockerfile.triton -t "${FULL_IMAGE_NAME}" .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Image built successfully: ${FULL_IMAGE_NAME}${NC}"
    
    # Tag for DockerHub
    if [ -n "$DOCKERHUB_USER" ] && [ "$DOCKERHUB_USER" != "your-username" ]; then
        echo -e "${YELLOW}Tagging for DockerHub...${NC}"
        docker tag "${FULL_IMAGE_NAME}" "${DOCKERHUB_USER}/${FULL_IMAGE_NAME}"
        echo -e "${GREEN}✓ Tagged as: ${DOCKERHUB_USER}/${FULL_IMAGE_NAME}${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Build Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Test locally:"
    echo "   docker run --gpus all -p 8000:8000 ${FULL_IMAGE_NAME}"
    echo ""
    echo "2. Push to DockerHub:"
    echo "   docker login"
    echo "   docker push ${DOCKERHUB_USER}/${FULL_IMAGE_NAME}"
    echo ""
    echo "3. Use on VastAI:"
    echo "   See VASTAI_DEPLOYMENT.md"
    echo ""
else
    echo "Error: Build failed"
    exit 1
fi

# Build Triton Docker image for VastAI deployment

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Building Triton Docker Image${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Image configuration
IMAGE_NAME="${DOCKER_IMAGE_NAME:-vtryon-triton}"
IMAGE_TAG="${DOCKER_IMAGE_TAG:-latest}"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

# DockerHub username (set via environment variable)
DOCKERHUB_USER="${DOCKERHUB_USER:-your-username}"

echo "Image name: ${DOCKERHUB_USER}/${FULL_IMAGE_NAME}"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    exit 1
fi

# Check if model repository exists
if [ ! -d "triton_model_repository" ]; then
    echo "Error: triton_model_repository directory not found!"
    echo "Please run from microservices/ directory"
    exit 1
fi

# Build Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
docker build -f Dockerfile.triton -t "${FULL_IMAGE_NAME}" .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Image built successfully: ${FULL_IMAGE_NAME}${NC}"
    
    # Tag for DockerHub
    if [ -n "$DOCKERHUB_USER" ] && [ "$DOCKERHUB_USER" != "your-username" ]; then
        echo -e "${YELLOW}Tagging for DockerHub...${NC}"
        docker tag "${FULL_IMAGE_NAME}" "${DOCKERHUB_USER}/${FULL_IMAGE_NAME}"
        echo -e "${GREEN}✓ Tagged as: ${DOCKERHUB_USER}/${FULL_IMAGE_NAME}${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Build Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Test locally:"
    echo "   docker run --gpus all -p 8000:8000 ${FULL_IMAGE_NAME}"
    echo ""
    echo "2. Push to DockerHub:"
    echo "   docker login"
    echo "   docker push ${DOCKERHUB_USER}/${FULL_IMAGE_NAME}"
    echo ""
    echo "3. Use on VastAI:"
    echo "   See VASTAI_DEPLOYMENT.md"
    echo ""
else
    echo "Error: Build failed"
    exit 1
fi







