#!/bin/bash
# Script to build and push Docker image to registry
# Usage: ./push_image.sh [registry] [tag]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Default values
REGISTRY="${1:-}"
TAG="${2:-latest}"
IMAGE_NAME="vtryon-triton"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "Building and Pushing Docker Image"
echo "=========================================="
echo ""

# Check if registry is provided
if [ -z "$REGISTRY" ]; then
    echo -e "${YELLOW}⚠ No registry specified${NC}"
    echo ""
    echo "Usage: $0 <registry> [tag]"
    echo ""
    echo "Examples:"
    echo "  $0 docker.io/username v1.0"
    echo "  $0 ghcr.io/username/repo latest"
    echo "  $0 registry.hub.docker.com/username latest"
    echo ""
    read -p "Enter registry (or press Ctrl+C to cancel): " REGISTRY
    if [ -z "$REGISTRY" ]; then
        echo -e "${RED}✗ Registry required${NC}"
        exit 1
    fi
fi

FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}:${TAG}"

echo "Registry: $REGISTRY"
echo "Image: $IMAGE_NAME"
echo "Tag: $TAG"
echo "Full name: $FULL_IMAGE_NAME"
echo ""

# Confirm
read -p "Continue? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Build image
echo ""
echo "=========================================="
echo "Step 1: Building Docker Image"
echo "=========================================="
echo ""

if docker build -f Dockerfile.triton -t "$FULL_IMAGE_NAME" .; then
    echo -e "${GREEN}✓ Image built successfully${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

# Also tag as latest if different tag was used
if [ "$TAG" != "latest" ]; then
    LATEST_NAME="${REGISTRY}/${IMAGE_NAME}:latest"
    echo ""
    echo "Tagging as latest: $LATEST_NAME"
    docker tag "$FULL_IMAGE_NAME" "$LATEST_NAME"
fi

# Push image
echo ""
echo "=========================================="
echo "Step 2: Pushing Docker Image"
echo "=========================================="
echo ""

echo "Pushing $FULL_IMAGE_NAME..."
if docker push "$FULL_IMAGE_NAME"; then
    echo -e "${GREEN}✓ Image pushed successfully${NC}"
else
    echo -e "${RED}✗ Push failed${NC}"
    exit 1
fi

# Push latest tag if different
if [ "$TAG" != "latest" ]; then
    echo ""
    echo "Pushing latest tag: $LATEST_NAME"
    if docker push "$LATEST_NAME"; then
        echo -e "${GREEN}✓ Latest tag pushed successfully${NC}"
    else
        echo -e "${YELLOW}⚠ Failed to push latest tag (non-fatal)${NC}"
    fi
fi

echo ""
echo "=========================================="
echo "✓ Image Push Complete"
echo "=========================================="
echo ""
echo "Image: $FULL_IMAGE_NAME"
echo ""
echo "Next steps:"
echo "1. Create Vast AI instance with image: $FULL_IMAGE_NAME"
echo "2. Expose ports: 8000, 8001, 8002"
echo "3. Connect and test"
echo ""


