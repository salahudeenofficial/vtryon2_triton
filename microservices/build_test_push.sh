#!/bin/bash
# Build, test, and push Triton image with verification

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Triton Image: Build, Test & Push${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Configuration
IMAGE_NAME="${DOCKER_IMAGE_NAME:-vtryon-triton}"
IMAGE_TAG="${DOCKER_IMAGE_TAG:-latest}"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
DOCKERHUB_USER="${DOCKERHUB_USER:-}"

# Step 1: Syntax Check
echo -e "${YELLOW}[1/5] Checking Python syntax...${NC}"
python3 -m py_compile triton_model_repository/latent_encoder/1/model.py \
    triton_model_repository/text_encoder/1/model.py \
    triton_model_repository/sampling/1/model.py \
    triton_model_repository/decoding/1/model.py 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Python syntax check passed${NC}"
else
    echo -e "${RED}✗ Python syntax check failed${NC}"
    exit 1
fi

# Step 2: Check imports (basic validation)
echo -e "${YELLOW}[2/5] Validating imports...${NC}"
for model in latent_encoder text_encoder sampling decoding; do
    if ! grep -q "import triton_python_backend_utils" "triton_model_repository/$model/1/model.py"; then
        echo -e "${RED}✗ Missing triton_python_backend_utils import in $model${NC}"
        exit 1
    fi
    if ! grep -q "import comfy.model_management" "triton_model_repository/$model/1/model.py"; then
        echo -e "${RED}✗ Missing comfy.model_management import in $model${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ Import validation passed${NC}"

# Step 3: Check config files
echo -e "${YELLOW}[3/5] Validating config files...${NC}"
for model in latent_encoder text_encoder sampling decoding vtryon_pipeline; do
    if [ ! -f "triton_model_repository/$model/config.pbtxt" ]; then
        echo -e "${RED}✗ Missing config.pbtxt for $model${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ Config files validated${NC}"

# Step 4: Build Docker image
echo -e "${YELLOW}[4/5] Building Docker image...${NC}"
if [ ! -f "Dockerfile.triton" ]; then
    echo -e "${RED}✗ Dockerfile.triton not found${NC}"
    exit 1
fi

docker build -f Dockerfile.triton -t "${FULL_IMAGE_NAME}" . 2>&1 | tee /tmp/docker_build.log

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Docker image built successfully: ${FULL_IMAGE_NAME}${NC}"
else
    echo -e "${RED}✗ Docker build failed${NC}"
    echo "Check /tmp/docker_build.log for details"
    exit 1
fi

# Step 5: Quick validation (check image structure)
echo -e "${YELLOW}[5/5] Validating image structure...${NC}"
docker run --rm "${FULL_IMAGE_NAME}" ls -la /models/ 2>&1 | grep -q "latent_encoder" || {
    echo -e "${RED}✗ Image validation failed - models not found${NC}"
    exit 1
}
echo -e "${GREEN}✓ Image structure validated${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Ask about pushing
if [ -z "$DOCKERHUB_USER" ]; then
    echo -e "${YELLOW}DOCKERHUB_USER not set. Skipping push.${NC}"
    echo "To push, set DOCKERHUB_USER environment variable:"
    echo "  export DOCKERHUB_USER=your-username"
    echo "  docker login"
    echo "  docker tag ${FULL_IMAGE_NAME} ${DOCKERHUB_USER}/${FULL_IMAGE_NAME}"
    echo "  docker push ${DOCKERHUB_USER}/${FULL_IMAGE_NAME}"
else
    read -p "Push to DockerHub? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Pushing to DockerHub...${NC}"
        docker tag "${FULL_IMAGE_NAME}" "${DOCKERHUB_USER}/${FULL_IMAGE_NAME}"
        docker push "${DOCKERHUB_USER}/${FULL_IMAGE_NAME}"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Image pushed successfully: ${DOCKERHUB_USER}/${FULL_IMAGE_NAME}${NC}"
        else
            echo -e "${RED}✗ Push failed${NC}"
            exit 1
        fi
    fi
fi

# Ask about git push
read -p "Push code to git? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Pushing to git...${NC}"
    git add -A
    git status
    read -p "Commit message (or press Enter for default): " commit_msg
    if [ -z "$commit_msg" ]; then
        commit_msg="Update Triton models with GPU memory offloading and monitoring"
    fi
    git commit -m "$commit_msg" || echo "No changes to commit"
    git push
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Code pushed successfully${NC}"
    else
        echo -e "${RED}✗ Git push failed${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}All done!${NC}"

