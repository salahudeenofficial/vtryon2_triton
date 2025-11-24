#!/bin/bash
# Build and push Docker image with all fixes
# Usage: ./build_and_push.sh [registry] [tag]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

REGISTRY="${1:-}"
TAG="${2:-latest}"
IMAGE_NAME="vtryon-triton"

echo "=========================================="
echo "Building and Pushing Docker Image"
echo "=========================================="
echo ""

# Step 1: Build
echo "Step 1: Building image..."
if docker build -f Dockerfile.triton -t "${IMAGE_NAME}:${TAG}" .; then
    echo "✓ Image built successfully"
else
    echo "✗ Build failed"
    exit 1
fi

# Step 2: Tag and push (if registry provided)
if [ -n "$REGISTRY" ]; then
    FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}:${TAG}"
    echo ""
    echo "Step 2: Tagging image..."
    docker tag "${IMAGE_NAME}:${TAG}" "$FULL_IMAGE_NAME"
    echo "✓ Tagged as $FULL_IMAGE_NAME"
    
    echo ""
    echo "Step 3: Pushing image..."
    if docker push "$FULL_IMAGE_NAME"; then
        echo "✓ Image pushed successfully"
        echo ""
        echo "Image: $FULL_IMAGE_NAME"
    else
        echo "✗ Push failed"
        exit 1
    fi
else
    echo ""
    echo "⚠ No registry specified - image built but not pushed"
    echo ""
    echo "To push, run:"
    echo "  docker tag ${IMAGE_NAME}:${TAG} <registry>/${IMAGE_NAME}:${TAG}"
    echo "  docker push <registry>/${IMAGE_NAME}:${TAG}"
    echo ""
    echo "Or run this script with registry:"
    echo "  ./build_and_push.sh <registry> [tag]"
fi

echo ""
echo "=========================================="
echo "✓ Complete"
echo "=========================================="


