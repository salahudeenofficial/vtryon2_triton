#!/bin/bash
# run_phase2_tests.sh - Run comprehensive tests for Phase 2 information extraction
# This script tests each service and extracts all information needed for Triton config

set -e

MICROSERVICES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_RESULTS_DIR="${MICROSERVICES_DIR}/test_results"
TEST_DATA_DIR="${MICROSERVICES_DIR}/test_data"

echo "=========================================="
echo "Phase 2: Comprehensive Service Testing"
echo "=========================================="
echo ""

# Create test results directory
mkdir -p "$TEST_RESULTS_DIR"

# Activate virtual environment if available
if [ -d "${MICROSERVICES_DIR}/../venv" ]; then
    source "${MICROSERVICES_DIR}/../venv/bin/activate"
    echo "✓ Virtual environment activated"
fi

# Function to extract tensor info from service output
extract_tensor_info() {
    local service_name="$1"
    local output_file="$2"
    
    echo "Extracting tensor information for $service_name..."
    # This will be enhanced based on actual service output
    # For now, create a template JSON structure
}

# Function to test a service
test_service() {
    local service_name="$1"
    local service_dir="${MICROSERVICES_DIR}/${service_name}"
    local results_dir="${TEST_RESULTS_DIR}/${service_name}"
    
    mkdir -p "$results_dir"
    
    echo ""
    echo "=========================================="
    echo "Testing: $service_name"
    echo "=========================================="
    
    cd "$service_dir"
    
    # Check if venv exists for this service
    if [ -d "venv" ]; then
        source venv/bin/activate
    fi
    
    # Run basic functionality test
    echo "Running basic functionality test..."
    # This will be customized per service
    
    cd "$MICROSERVICES_DIR"
}

# Test each service
echo "Starting comprehensive testing..."
echo ""

# Note: Actual test commands will be added based on service requirements
# For now, this is a template structure

echo "=========================================="
echo "Testing Complete"
echo "=========================================="
echo "Results saved to: $TEST_RESULTS_DIR"
echo ""
echo "Next: Review test results and create TRITON_CONFIG_DATA.json files"

# run_phase2_tests.sh - Run comprehensive tests for Phase 2 information extraction
# This script tests each service and extracts all information needed for Triton config

set -e

MICROSERVICES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_RESULTS_DIR="${MICROSERVICES_DIR}/test_results"
TEST_DATA_DIR="${MICROSERVICES_DIR}/test_data"

echo "=========================================="
echo "Phase 2: Comprehensive Service Testing"
echo "=========================================="
echo ""

# Create test results directory
mkdir -p "$TEST_RESULTS_DIR"

# Activate virtual environment if available
if [ -d "${MICROSERVICES_DIR}/../venv" ]; then
    source "${MICROSERVICES_DIR}/../venv/bin/activate"
    echo "✓ Virtual environment activated"
fi

# Function to extract tensor info from service output
extract_tensor_info() {
    local service_name="$1"
    local output_file="$2"
    
    echo "Extracting tensor information for $service_name..."
    # This will be enhanced based on actual service output
    # For now, create a template JSON structure
}

# Function to test a service
test_service() {
    local service_name="$1"
    local service_dir="${MICROSERVICES_DIR}/${service_name}"
    local results_dir="${TEST_RESULTS_DIR}/${service_name}"
    
    mkdir -p "$results_dir"
    
    echo ""
    echo "=========================================="
    echo "Testing: $service_name"
    echo "=========================================="
    
    cd "$service_dir"
    
    # Check if venv exists for this service
    if [ -d "venv" ]; then
        source venv/bin/activate
    fi
    
    # Run basic functionality test
    echo "Running basic functionality test..."
    # This will be customized per service
    
    cd "$MICROSERVICES_DIR"
}

# Test each service
echo "Starting comprehensive testing..."
echo ""

# Note: Actual test commands will be added based on service requirements
# For now, this is a template structure

echo "=========================================="
echo "Testing Complete"
echo "=========================================="
echo "Results saved to: $TEST_RESULTS_DIR"
echo ""
echo "Next: Review test results and create TRITON_CONFIG_DATA.json files"







