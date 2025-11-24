#!/bin/bash
# Commands to check if Triton is running inside container
# Run these commands INSIDE the container

echo "=========================================="
echo "Checking Triton Server Status"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 1. Check if tritonserver process is running
echo "1. Checking tritonserver process:"
if pgrep -f tritonserver > /dev/null; then
    echo -e "   ${GREEN}✓ Triton server process is running${NC}"
    echo "   Process details:"
    ps aux | grep tritonserver | grep -v grep
else
    echo -e "   ${RED}✗ Triton server process NOT found${NC}"
fi
echo ""

# 2. Check if port 8000 is listening
echo "2. Checking if port 8000 is listening:"
if netstat -tuln 2>/dev/null | grep -q ":8000 " || ss -tuln 2>/dev/null | grep -q ":8000 "; then
    echo -e "   ${GREEN}✓ Port 8000 is listening${NC}"
    netstat -tuln 2>/dev/null | grep ":8000 " || ss -tuln 2>/dev/null | grep ":8000 "
else
    echo -e "   ${RED}✗ Port 8000 is NOT listening${NC}"
fi
echo ""

# 3. Check health endpoint
echo "3. Checking health endpoint (http://localhost:8000/v2/health/live):"
HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/v2/health/live 2>/dev/null || echo "000")
if [ "$HEALTH_RESPONSE" = "200" ]; then
    echo -e "   ${GREEN}✓ Health endpoint returned 200${NC}"
elif [ "$HEALTH_RESPONSE" = "000" ]; then
    echo -e "   ${RED}✗ Cannot connect to health endpoint${NC}"
else
    echo -e "   ${YELLOW}⚠ Health endpoint returned: $HEALTH_RESPONSE${NC}"
fi
echo ""

# 4. Check ready endpoint
echo "4. Checking ready endpoint (http://localhost:8000/v2/health/ready):"
READY_RESPONSE=$(curl -s http://localhost:8000/v2/health/ready 2>/dev/null || echo "ERROR")
if [ "$READY_RESPONSE" = "OK" ] || [ "$READY_RESPONSE" = "" ]; then
    echo -e "   ${GREEN}✓ Ready endpoint responded${NC}"
    echo "   Response: '$READY_RESPONSE'"
else
    echo -e "   ${YELLOW}⚠ Ready endpoint response: '$READY_RESPONSE'${NC}"
fi
echo ""

# 5. Check models endpoint
echo "5. Checking models endpoint (http://localhost:8000/v2/models):"
MODELS_RESPONSE=$(curl -s http://localhost:8000/v2/models 2>/dev/null || echo "ERROR")
if echo "$MODELS_RESPONSE" | grep -q "models" || echo "$MODELS_RESPONSE" | python3 -m json.tool > /dev/null 2>&1; then
    echo -e "   ${GREEN}✓ Models endpoint responded${NC}"
    echo "   Response:"
    echo "$MODELS_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$MODELS_RESPONSE" | head -20
else
    echo -e "   ${RED}✗ Models endpoint error or empty${NC}"
    echo "   Response: '$MODELS_RESPONSE'"
fi
echo ""

# 6. Check server info
echo "6. Checking server info (http://localhost:8000/v2):"
SERVER_INFO=$(curl -s http://localhost:8000/v2 2>/dev/null || echo "ERROR")
if echo "$SERVER_INFO" | grep -q "version" || echo "$SERVER_INFO" | python3 -m json.tool > /dev/null 2>&1; then
    echo -e "   ${GREEN}✓ Server info endpoint responded${NC}"
    echo "$SERVER_INFO" | python3 -m json.tool 2>/dev/null | head -10 || echo "$SERVER_INFO" | head -10
else
    echo -e "   ${RED}✗ Server info endpoint error${NC}"
fi
echo ""

# 7. Check Triton logs (last 20 lines)
echo "7. Last 20 lines of Triton logs:"
if [ -f /var/log/tritonserver.log ] || docker logs $(hostname) 2>&1 | tail -20 > /tmp/triton_logs.txt 2>/dev/null; then
    if [ -f /var/log/tritonserver.log ]; then
        tail -20 /var/log/tritonserver.log
    elif [ -f /tmp/triton_logs.txt ]; then
        cat /tmp/triton_logs.txt
    else
        echo "   (Logs not accessible via standard methods)"
    fi
else
    echo "   (Cannot access logs - may need to check container logs externally)"
fi
echo ""

# Summary
echo "=========================================="
echo "Summary:"
echo "=========================================="

TRITON_RUNNING=false
if pgrep -f tritonserver > /dev/null; then
    echo -e "${GREEN}✓ Triton process: RUNNING${NC}"
    TRITON_RUNNING=true
else
    echo -e "${RED}✗ Triton process: NOT RUNNING${NC}"
fi

PORT_LISTENING=false
if netstat -tuln 2>/dev/null | grep -q ":8000 " || ss -tuln 2>/dev/null | grep -q ":8000 "; then
    echo -e "${GREEN}✓ Port 8000: LISTENING${NC}"
    PORT_LISTENING=true
else
    echo -e "${RED}✗ Port 8000: NOT LISTENING${NC}"
fi

HEALTH_OK=false
if [ "$HEALTH_RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓ Health endpoint: OK${NC}"
    HEALTH_OK=true
else
    echo -e "${RED}✗ Health endpoint: NOT OK${NC}"
fi

if [ "$TRITON_RUNNING" = true ] && [ "$PORT_LISTENING" = true ] && [ "$HEALTH_OK" = true ]; then
    echo ""
    echo -e "${GREEN}✅ Triton server is RUNNING and HEALTHY${NC}"
else
    echo ""
    echo -e "${YELLOW}⚠ Triton server may not be fully operational${NC}"
    echo ""
    echo "To start Triton (if not running):"
    echo "  /workspace/entrypoint.sh"
    echo ""
    echo "Or check container logs:"
    echo "  docker logs <container-name>"
fi
echo ""


