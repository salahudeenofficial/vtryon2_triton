#!/bin/bash
# Commands to check and start Triton in container
# Run these commands INSIDE the container

echo "=========================================="
echo "Triton Server Status & Startup"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 1. Check if already running
echo "1. Checking if Triton is already running:"
if pgrep -f tritonserver > /dev/null; then
    echo -e "   ${GREEN}✓ Triton is already running${NC}"
    ps aux | grep tritonserver | grep -v grep
    echo ""
    echo "Health check:"
    curl -s http://localhost:8000/v2/health/live && echo " ✓" || echo " ✗"
    exit 0
else
    echo -e "   ${RED}✗ Triton is NOT running${NC}"
fi
echo ""

# 2. Check prerequisites
echo "2. Checking prerequisites:"
echo "   Models directory:"
ls -lh /workspace/shared_models/*/ 2>/dev/null | head -5 || echo "   ✗ Models not found"

echo ""
echo "   Entrypoint script:"
if [ -f /workspace/entrypoint.sh ]; then
    echo -e "   ${GREEN}✓ /workspace/entrypoint.sh exists${NC}"
    ls -lh /workspace/entrypoint.sh
else
    echo -e "   ${RED}✗ /workspace/entrypoint.sh NOT found${NC}"
fi

echo ""
echo "   Model repository:"
if [ -d /models ]; then
    echo -e "   ${GREEN}✓ /models directory exists${NC}"
    ls -la /models/ | head -10
else
    echo -e "   ${RED}✗ /models directory NOT found${NC}"
fi
echo ""

# 3. Check for errors in logs
echo "3. Checking for recent errors:"
if [ -f /var/log/tritonserver.log ]; then
    echo "   Last errors from log:"
    grep -i error /var/log/tritonserver.log | tail -10 || echo "   No errors found in log"
else
    echo "   Log file not found at /var/log/tritonserver.log"
fi
echo ""

# 4. Try to start Triton
echo "4. Attempting to start Triton:"
echo "   (This will run in background - check with: ps aux | grep tritonserver)"
echo ""

# Check if we can run entrypoint
if [ -f /workspace/entrypoint.sh ]; then
    echo "   Starting via entrypoint.sh..."
    echo "   Note: This will block the terminal. Press Ctrl+C to stop."
    echo ""
    echo "   To run in background instead, use:"
    echo "     nohup /workspace/entrypoint.sh > /tmp/triton.log 2>&1 &"
    echo ""
    read -p "   Start Triton now? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        /workspace/entrypoint.sh
    else
        echo "   Skipped. Run manually: /workspace/entrypoint.sh"
    fi
else
    echo -e "   ${RED}✗ Cannot start - entrypoint.sh not found${NC}"
    echo ""
    echo "   Try starting manually:"
    echo "     tritonserver --model-repository=/models --log-verbose=1"
fi


