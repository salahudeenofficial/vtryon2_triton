#!/bin/bash
# Setup local environment for testing ensemble pipeline

set -e

echo "=========================================="
echo "Setting up Local Test Environment"
echo "=========================================="
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )"
cd "$SCRIPT_DIR"

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 not found"
    exit 1
fi

echo "Python version: $(python3 --version)"
echo ""

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install requirements from all services
echo ""
echo "Installing requirements..."

# Core ML packages
pip install torch>=2.0.0 torchvision>=0.15.0 numpy>=1.24.0 Pillow>=9.0.0

# Additional packages
pip install python-dotenv>=1.0.0 pydantic>=2.0.0

# Install from service requirements
if [ -f "latent_encoder/requirements.txt" ]; then
    pip install -r latent_encoder/requirements.txt
fi

if [ -f "text_encoder/requirements.txt" ]; then
    pip install -r text_encoder/requirements.txt
fi

if [ -f "sampling/requirements.txt" ]; then
    pip install -r sampling/requirements.txt
fi

if [ -f "decoding/requirements.txt" ]; then
    pip install -r decoding/requirements.txt
fi

echo ""
echo "=========================================="
echo "✓ Environment setup complete!"
echo "=========================================="
echo ""
echo "To activate environment:"
echo "  source venv/bin/activate"
echo ""
echo "To test ensemble:"
echo "  python test_ensemble_local.py"
echo ""

# Setup local environment for testing ensemble pipeline

set -e

echo "=========================================="
echo "Setting up Local Test Environment"
echo "=========================================="
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )"
cd "$SCRIPT_DIR"

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 not found"
    exit 1
fi

echo "Python version: $(python3 --version)"
echo ""

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install requirements from all services
echo ""
echo "Installing requirements..."

# Core ML packages
pip install torch>=2.0.0 torchvision>=0.15.0 numpy>=1.24.0 Pillow>=9.0.0

# Additional packages
pip install python-dotenv>=1.0.0 pydantic>=2.0.0

# Install from service requirements
if [ -f "latent_encoder/requirements.txt" ]; then
    pip install -r latent_encoder/requirements.txt
fi

if [ -f "text_encoder/requirements.txt" ]; then
    pip install -r text_encoder/requirements.txt
fi

if [ -f "sampling/requirements.txt" ]; then
    pip install -r sampling/requirements.txt
fi

if [ -f "decoding/requirements.txt" ]; then
    pip install -r decoding/requirements.txt
fi

echo ""
echo "=========================================="
echo "✓ Environment setup complete!"
echo "=========================================="
echo ""
echo "To activate environment:"
echo "  source venv/bin/activate"
echo ""
echo "To test ensemble:"
echo "  python test_ensemble_local.py"
echo ""







