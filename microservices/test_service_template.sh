#!/bin/bash
# Template script for comprehensive service testing
# Usage: ./test_service_template.sh <service_name>

set -e

SERVICE_NAME="$1"
if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: $0 <service_name>"
    echo "Example: $0 latent_encoder"
    exit 1
fi

SERVICE_DIR="microservices/$SERVICE_NAME"
TEST_RESULTS_DIR="test_results/$SERVICE_NAME"
TEST_DATA_DIR="test_data"

# Create test results directory
mkdir -p "$TEST_RESULTS_DIR"

echo "=========================================="
echo "Testing $SERVICE_NAME"
echo "=========================================="

# Activate virtual environment
cd "$SERVICE_DIR"
source venv/bin/activate

# Test 1: Basic functionality
echo "Test 1: Basic Functionality Test"
python main.py --mode standalone \
  --image_path "../../$TEST_DATA_DIR/images/person.jpg" \
  --output_dir "../../$TEST_RESULTS_DIR" \
  --no-save > "../../$TEST_RESULTS_DIR/basic_test.log" 2>&1

# Extract tensor information from output
# (This would need to be customized per service)

# Test 2: Resource profiling
echo "Test 2: Resource Profiling"
# Use nvidia-smi or Python profiling tools
# Monitor GPU memory, CPU usage during inference

# Test 3: Batch processing (if supported)
echo "Test 3: Batch Processing Test"
# Test with different batch sizes

# Test 4: Concurrency test
echo "Test 4: Concurrency Test"
# Test with multiple simultaneous requests

# Generate summary
echo "Generating test summary..."
# Create TRITON_CONFIG_DATA.json from test results

echo "=========================================="
echo "Testing complete. Results in: $TEST_RESULTS_DIR"
echo "=========================================="

# Template script for comprehensive service testing
# Usage: ./test_service_template.sh <service_name>

set -e

SERVICE_NAME="$1"
if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: $0 <service_name>"
    echo "Example: $0 latent_encoder"
    exit 1
fi

SERVICE_DIR="microservices/$SERVICE_NAME"
TEST_RESULTS_DIR="test_results/$SERVICE_NAME"
TEST_DATA_DIR="test_data"

# Create test results directory
mkdir -p "$TEST_RESULTS_DIR"

echo "=========================================="
echo "Testing $SERVICE_NAME"
echo "=========================================="

# Activate virtual environment
cd "$SERVICE_DIR"
source venv/bin/activate

# Test 1: Basic functionality
echo "Test 1: Basic Functionality Test"
python main.py --mode standalone \
  --image_path "../../$TEST_DATA_DIR/images/person.jpg" \
  --output_dir "../../$TEST_RESULTS_DIR" \
  --no-save > "../../$TEST_RESULTS_DIR/basic_test.log" 2>&1

# Extract tensor information from output
# (This would need to be customized per service)

# Test 2: Resource profiling
echo "Test 2: Resource Profiling"
# Use nvidia-smi or Python profiling tools
# Monitor GPU memory, CPU usage during inference

# Test 3: Batch processing (if supported)
echo "Test 3: Batch Processing Test"
# Test with different batch sizes

# Test 4: Concurrency test
echo "Test 4: Concurrency Test"
# Test with multiple simultaneous requests

# Generate summary
echo "Generating test summary..."
# Create TRITON_CONFIG_DATA.json from test results

echo "=========================================="
echo "Testing complete. Results in: $TEST_RESULTS_DIR"
echo "=========================================="







