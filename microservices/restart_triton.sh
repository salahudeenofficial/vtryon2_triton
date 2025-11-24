#!/bin/bash
# Restart Triton server
# Run this inside the container

echo "=========================================="
echo "Restarting Triton Server"
echo "=========================================="
echo ""

# Stop Triton
echo "Step 1: Stopping Triton..."
if pgrep -f tritonserver > /dev/null; then
    pkill -f tritonserver
    echo "✓ Sent stop signal"
    sleep 3
    
    # Verify it's stopped
    if pgrep -f tritonserver > /dev/null; then
        echo "⚠ Process still running, force killing..."
        pkill -9 -f tritonserver
        sleep 2
    fi
    echo "✓ Triton stopped"
else
    echo "✓ Triton was not running"
fi

echo ""

# Start Triton
echo "Step 2: Starting Triton..."
nohup /workspace/entrypoint.sh > /tmp/triton.log 2>&1 &
TRITON_PID=$!
echo "✓ Started (PID: $TRITON_PID)"
echo ""

# Wait a bit for startup
echo "Step 3: Waiting for startup..."
sleep 5

# Check if process is running
if pgrep -f tritonserver > /dev/null; then
    echo "✓ Triton process is running"
else
    echo "✗ Triton process not found - check logs:"
    tail -30 /tmp/triton.log
    exit 1
fi

echo ""

# Check health
echo "Step 4: Checking health..."
for i in {1..15}; do
    if curl -s http://localhost:8000/v2/health/live > /dev/null 2>&1; then
        echo "✓ Triton is ready and healthy!"
        break
    fi
    if [ $i -eq 15 ]; then
        echo "⚠ Health check timeout - server may still be starting"
        echo "Check logs: tail -f /tmp/triton.log"
    else
        echo "  Waiting for health check... ($i/15)"
        sleep 2
    fi
done

echo ""
echo "=========================================="
echo "Triton Restart Complete"
echo "=========================================="
echo ""
echo "Process status:"
ps aux | grep tritonserver | grep -v grep
echo ""
echo "Recent logs:"
tail -10 /tmp/triton.log
echo ""
echo "Monitor logs: tail -f /tmp/triton.log"
echo "Check health: curl http://localhost:8000/v2/health/live"


