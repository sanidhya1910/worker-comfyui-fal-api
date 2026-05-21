# Build argument for base image selection
ARG BASE_IMAGE=ubuntu:24.04

# Stage 1: Base image with common dependencies
FROM ${BASE_IMAGE} AS base

# Build arguments for this stage with sensible defaults for standalone builds
ARG COMFYUI_VERSION=latest
ARG FAL_API_NODE_REPO=https://github.com/gokayfem/ComfyUI-fal-API
ARG ART_VENTURE_NODE_REPO=https://github.com/sipherxyz/comfyui-art-venture
ARG RMBG_NODE_REPO=https://github.com/1038lab/ComfyUI-RMBG
ARG KJ_NODES_REPO=https://github.com/kijai/ComfyUI-KJNodes

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

# Install uv using the official docker image
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Add local bin to PATH so uv tools work
ENV PATH="/root/.local/bin:${PATH}"

# Install comfy-cli cleanly as an isolated tool
RUN uv tool install comfy-cli && rm -rf /root/.cache/uv

# Install ComfyUI in CPU-only mode.
# This will natively clone the github repo and create /comfyui/.venv
RUN /usr/bin/yes | comfy --workspace /comfyui install --version "${COMFYUI_VERSION}" --cpu \
    && rm -rf /root/.cache/uv /root/.cache/pip

# Force all subsequent uv pip and python commands to strictly use the ComfyUI virtual env
ENV VIRTUAL_ENV="/comfyui/.venv"
ENV PATH="/comfyui/.venv/bin:${PATH}"

# Change working directory to ComfyUI
WORKDIR /comfyui

# Support for the network volume
ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# Install Python runtime dependencies for the handler and ComfyUI startup
ADD requirements.txt ./
RUN uv pip install --no-cache boto3 \
    && uv pip install --no-cache -r requirements.txt --extra-index-url https://download.pytorch.org/whl/cpu \
    && rm -rf /root/.cache/uv /root/.cache/pip

# Add application code and scripts
ADD src/start.sh src/network_volume.py handler.py test_input.json ./
RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh

# Add script to install custom nodes
COPY scripts/comfy-node-install.sh /usr/local/bin/comfy-node-install
RUN sed -i 's/\r$//' /usr/local/bin/comfy-node-install && chmod +x /usr/local/bin/comfy-node-install

# Install ComfyUI custom nodes required for fal API integration and art-venture
RUN comfy-node-install "${FAL_API_NODE_REPO}" "${ART_VENTURE_NODE_REPO}" \
    "${RMBG_NODE_REPO}" "${KJ_NODES_REPO}" \
    && rm -rf /root/.cache/uv /root/.cache/pip /comfyui/.venv/cache

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
