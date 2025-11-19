#!/bin/bash
# Comprehensive script to copy ALL ComfyUI files needed for Triton
# Run this if you're missing files after pulling from git

set -e

PROJECT_ROOT="${1:-/workspace/vtryon2_triton}"
MICROSERVICES_DIR="${PROJECT_ROOT}/microservices"
SHARED_COMFYUI="${MICROSERVICES_DIR}/triton_model_repository/shared_comfyui"

echo "=========================================="
echo "Copying ALL ComfyUI Files"
echo "=========================================="
echo "Project root: ${PROJECT_ROOT}"
echo "Target: ${SHARED_COMFYUI}"
echo ""

# Create directory if it doesn't exist
mkdir -p "$SHARED_COMFYUI"

# Copy all directories
echo "Copying directories..."
for dir in comfy comfy_api comfy_execution comfy_extras utils; do
    if [ -d "${PROJECT_ROOT}/${dir}" ]; then
        echo "  Copying ${dir}/..."
        cp -r "${PROJECT_ROOT}/${dir}" "$SHARED_COMFYUI/" 2>/dev/null || echo "    ⚠️  Failed to copy ${dir}"
    else
        echo "  ⚠️  ${dir}/ not found"
    fi
done

# Copy all core Python files
echo ""
echo "Copying core Python files..."
CORE_FILES=(
    "nodes.py"
    "folder_paths.py"
    "execution.py"
    "node_helpers.py"
    "comfyui_version.py"
    "protocol.py"
    "latent_preview.py"
    "main.py"
    "server.py"
    "new_updater.py"
)

for file in "${CORE_FILES[@]}"; do
    if [ -f "${PROJECT_ROOT}/${file}" ]; then
        cp "${PROJECT_ROOT}/${file}" "$SHARED_COMFYUI/" 2>/dev/null && echo "  ✓ Copied ${file}" || echo "  ⚠️  Failed to copy ${file}"
    else
        echo "  ⚠️  ${file} not found"
    fi
done

# Verify critical files exist
echo ""
echo "Verifying critical files..."
CRITICAL_FILES=("nodes.py" "folder_paths.py" "execution.py" "node_helpers.py" "protocol.py" "latent_preview.py")
ALL_PRESENT=true

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "${SHARED_COMFYUI}/${file}" ]; then
        echo "  ✓ ${file}"
    else
        echo "  ✗ ${file} MISSING"
        ALL_PRESENT=false
    fi
done

if [ "$ALL_PRESENT" = true ]; then
    echo ""
    echo "=========================================="
    echo "✓ All critical files present!"
    echo "=========================================="
else
    echo ""
    echo "=========================================="
    echo "⚠️  Some critical files are missing!"
    echo "=========================================="
    exit 1
fi

