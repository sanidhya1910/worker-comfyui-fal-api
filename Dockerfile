# Build argument for base image selection
ARG BASE_IMAGE=ubuntu:24.04

# Stage 1: Base image with common dependencies
FROM ${BASE_IMAGE} AS base

# Build arguments for this stage with sensible defaults for standalone builds
ARG COMFYUI_VERSION=latest
ARG FAL_API_NODE_REPO=https://github.com/gokayfem/ComfyUI-fal-API
ARG ART_VENTURE_NODE_REPO=https://github.com/sipherxyz/comfyui-art-venture

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1
# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
    python3.12 \
    python3.12-venv \
    git \
    wget \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    ffmpeg \
    openssh-server \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install uv (latest) using official installer and create isolated venv
RUN wget -qO- https://astral.sh/uv/install.sh | sh \
    && ln -s /root/.local/bin/uv /usr/local/bin/uv \
    && ln -s /root/.local/bin/uvx /usr/local/bin/uvx \
    && uv venv /opt/venv

# Use the virtual environment for all subsequent commands
ENV PATH="/opt/venv/bin:${PATH}"

# Install comfy-cli + dependencies needed by it to install ComfyUI
RUN uv pip install comfy-cli pip setuptools wheel

# Install ComfyUI in CPU-only mode
RUN /usr/bin/yes | comfy --workspace /comfyui install --version "${COMFYUI_VERSION}" --cpu

# Change working directory to ComfyUI
WORKDIR /comfyui

# Support for the network volume
ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# Install Python runtime dependencies for the handler
RUN uv pip install runpod requests websocket-client boto3

# Add application code and scripts
ADD src/start.sh src/network_volume.py handler.py test_input.json ./
RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh

# Add script to install custom nodes
COPY scripts/comfy-node-install.sh /usr/local/bin/comfy-node-install
RUN sed -i 's/\r$//' /usr/local/bin/comfy-node-install && chmod +x /usr/local/bin/comfy-node-install

# Install ComfyUI custom nodes required for fal API integration and art-venture
RUN comfy-node-install "${FAL_API_NODE_REPO}" "${ART_VENTURE_NODE_REPO}"

# Prevent pip from asking for confirmation during uninstall steps in custom nodes
ENV PIP_NO_INPUT=1

# Copy helper script to switch Manager network mode at container start
COPY scripts/comfy-manager-set-mode.sh /usr/local/bin/comfy-manager-set-mode
RUN sed -i 's/\r$//' /usr/local/bin/comfy-manager-set-mode && chmod +x /usr/local/bin/comfy-manager-set-mode

# Force CPU execution at runtime even if a GPU is attached to the host.
ENV CUDA_VISIBLE_DEVICES=""
ENV NVIDIA_VISIBLE_DEVICES="void"

# Set the default command to run when starting the container
CMD ["/start.sh"]

# Stage 3: Final image
FROM base AS final
