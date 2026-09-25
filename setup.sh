#!/bin/bash
set -e # Exit immediately if any command fails

echo "1. Installing system build tools..."
sudo apt-get update
sudo apt-get install -y \
    cmake \
    build-essential \
    opencl-headers \
    ocl-icd-opencl-dev \
    libboost-dev \
    libboost-system-dev \
    libboost-filesystem-dev

echo "Checking for uv package manager..."
if ! command -v uv &> /dev/null; then
    echo "   -> uv not found. Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Add uv to the current script's PATH so it can be used immediately below
    export PATH="$HOME/.local/bin:$PATH"
fi

echo "Syncing Python environment and building LightGBM natively..."
uv sync

echo "Setup complete! Activate your environment with: source .venv/bin/activate"