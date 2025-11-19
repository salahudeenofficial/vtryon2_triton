#!/bin/bash
# Startup script for Triton Inference Server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Triton Inference Server...${NC}"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Check if model repository exists
if [ ! -d "triton_model_repository" ]; then
    echo -e "${RED}Error: triton_model_repository directory not found!${NC}"
    echo "Please run from microservices/ directory"
    exit 1
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    exit 1
fi

# Check if NVIDIA Docker runtime is available
if ! docker info | grep -q "nvidia"; then
    echo -e "${YELLOW}Warning: NVIDIA Docker runtime not detected${NC}"
    echo "GPU access may not work. Continuing anyway..."
fi

# Check if Triton image is available
if ! docker images | grep -q "tritonserver"; then
    echo -e "${YELLOW}Triton image not found. Pulling...${NC}"
    docker pull nvcr.io/nvidia/tritonserver:25.10-py3
fi

# Check if container is already running
if docker ps | grep -q "triton-server"; then
    echo -e "${YELLOW}Triton server container already running!${NC}"
    echo "Stopping existing container..."
    docker stop triton-server
    docker rm triton-server
fi

# Start Triton server
echo -e "${GREEN}Starting Triton server container...${NC}"

docker run -d \
  --name triton-server \
  --gpus all \
  --shm-size=2g \
  -p 8000:8000 \
  -p 8001:8001 \
  -p 8002:8002 \
  -v "$(pwd)/triton_model_repository:/models" \
  nvcr.io/nvidia/tritonserver:25.10-py3 \
  tritonserver \
    --model-repository=/models \
    --log-verbose=1 \
    --strict-model-config=false

# Wait a bit for server to start
echo -e "${GREEN}Waiting for server to start...${NC}"
sleep 5

# Check if server is running
if docker ps | grep -q "triton-server"; then
    echo -e "${GREEN}✓ Triton server is running!${NC}"
    echo ""
    echo "Server endpoints:"
    echo "  - HTTP:  http://localhost:8000"
    echo "  - gRPC:  localhost:8001"
    echo "  - Metrics: http://localhost:8002/metrics"
    echo ""
    echo "View logs:"
    echo "  docker logs -f triton-server"
    echo ""
    echo "Stop server:"
    echo "  docker stop triton-server"
    echo ""
    
    # Test health endpoint
    echo -e "${GREEN}Testing server health...${NC}"
    sleep 3
    if curl -s http://localhost:8000/v2/health/ready | grep -q "ready"; then
        echo -e "${GREEN}✓ Server is ready!${NC}"
    else
        echo -e "${YELLOW}⚠ Server may still be starting. Check logs with: docker logs triton-server${NC}"
    fi
else
    echo -e "${RED}✗ Failed to start Triton server${NC}"
    echo "Check logs with: docker logs triton-server"
    exit 1
fi

