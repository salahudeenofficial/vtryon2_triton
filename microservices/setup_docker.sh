#!/bin/bash
# Setup Docker on VastAI instance

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Setting up Docker on VastAI instance...${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker not found. Installing...${NC}"
    apt-get update
    apt-get install -y docker.io
    echo -e "${GREEN}✓ Docker installed${NC}"
else
    echo -e "${GREEN}✓ Docker is already installed${NC}"
    docker --version
fi

# Start Docker service
echo -e "${YELLOW}Starting Docker service...${NC}"
systemctl start docker
systemctl enable docker

# Wait a moment for service to start
sleep 2

# Verify Docker is running
if systemctl is-active --quiet docker; then
    echo -e "${GREEN}✓ Docker service is running${NC}"
else
    echo -e "${RED}✗ Failed to start Docker service${NC}"
    echo "Trying alternative method..."
    service docker start
    sleep 2
fi

# Test Docker
echo -e "${YELLOW}Testing Docker...${NC}"
if docker ps &> /dev/null; then
    echo -e "${GREEN}✓ Docker is working!${NC}"
    docker ps
else
    echo -e "${RED}✗ Docker is not responding${NC}"
    echo "Checking Docker status..."
    systemctl status docker
    exit 1
fi

# Check for NVIDIA Container Toolkit (for GPU support)
echo -e "${YELLOW}Checking GPU support...${NC}"
if docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi &> /dev/null; then
    echo -e "${GREEN}✓ GPU support is available${NC}"
else
    echo -e "${YELLOW}⚠ GPU support may not be available${NC}"
    echo "Installing NVIDIA Container Toolkit..."
    
    # Install NVIDIA Container Toolkit
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add - 2>/dev/null || true
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list
    
    apt-get update
    apt-get install -y nvidia-container-toolkit
    
    systemctl restart docker
    
    # Test again
    if docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi &> /dev/null; then
        echo -e "${GREEN}✓ GPU support is now available${NC}"
    else
        echo -e "${YELLOW}⚠ GPU support may require manual configuration${NC}"
    fi
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Docker setup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "You can now start Triton server:"
echo "  cd /workspace/vtryon2_triton/microservices"
echo "  ./start_triton.sh"
echo ""

