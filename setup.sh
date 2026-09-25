#!/bin/bash
set -e # Exit immediately if any command fails

echo "1. Installing system build tools..."
sudo apt-get update
sudo apt-get install -y cmake build-essential

echo "2. Detecting local CUDA version..."
# Ensure we can find nvcc (AWS AMIs usually put it here if not in PATH)
NVCC_PATH=$(which nvcc || echo "/usr/local/cuda/bin/nvcc")

# Extract the  version from the nvcc output and save as CUDA_VERSION
CUDA_VERSION=$($NVCC_PATH --version | grep "release" | awk '{print $5}' | sed 's/,//')
echo "   -> Detected CUDA $CUDA_VERSION"

echo "3. Matching NCCL library to CUDA $CUDA_VERSION..."
# Search the apt cache for the exact package string containing cuda version
NCCL_VER=$(apt-cache madison libnccl-dev | grep "cuda${CUDA_VERSION}" | awk '{print $3}' | head -n 1)

if [ -z "$NCCL_VER" ]; then
    echo "Error: Could not find an NCCL package matching CUDA ${CUDA_VERSION}."
    echo "Check available versions with: apt-cache madison libnccl-dev"
    exit 1
fi

echo "   -> Installing NCCL version: $NCCL_VER"
sudo apt-get install -y --allow-downgrades libnccl2=$NCCL_VER libnccl-dev=$NCCL_VER

echo "4. Syncing Python environment and building LightGBM natively..."
uv sync

echo "Setup complete! Activate your environment with: source .venv/bin/activate"