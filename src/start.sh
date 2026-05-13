#!/usr/bin/env bash

# Start SSH server if PUBLIC_KEY is set (enables remote access and dev-sync.sh)
if [ -n "$PUBLIC_KEY" ]; then
    mkdir -p ~/.ssh
    echo "$PUBLIC_KEY" > ~/.ssh/authorized_keys
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/authorized_keys

    # Generate host keys if they don't exist (removed during image build for security)
    for key_type in rsa ecdsa ed25519; do
        key_file="/etc/ssh/ssh_host_${key_type}_key"
        if [ ! -f "$key_file" ]; then
            ssh-keygen -t "$key_type" -f "$key_file" -q -N ''
        fi
    done

    service ssh start && echo "worker-comfyui: SSH server started" || echo "worker-comfyui: SSH server could not be started" >&2
fi

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

echo "worker-comfyui: Running in CPU-only mode"

# Configure ComfyUI-fal-API key if provided through environment variables.
# Preferred variable is FAL_KEY, with FAL_API_KEY as a fallback alias.
if [ -n "${FAL_KEY:-}" ] || [ -n "${FAL_API_KEY:-}" ]; then
    effective_fal_key="${FAL_KEY:-${FAL_API_KEY}}"
    export FAL_KEY="${effective_fal_key}"

    fal_node_dir=""
    if [ -d "/comfyui/custom_nodes/ComfyUI-fal-API" ]; then
        fal_node_dir="/comfyui/custom_nodes/ComfyUI-fal-API"
    else
        fal_node_dir="$(find /comfyui/custom_nodes -maxdepth 2 -type d -iname '*fal*api*' | head -n 1 || true)"
    fi

    if [ -n "${fal_node_dir}" ]; then
        fal_config_file="${fal_node_dir}/config.ini"
        printf '[API]\nFAL_KEY = %s\n' "${effective_fal_key}" > "${fal_config_file}"
        chmod 600 "${fal_config_file}" || true
        echo "worker-comfyui: Wrote fal config to ${fal_config_file}"
    else
        echo "worker-comfyui: FAL key provided but ComfyUI-fal-API directory was not found; relying on FAL_KEY environment variable"
    fi
fi

# Ensure ComfyUI-Manager runs in offline network mode inside the container
comfy-manager-set-mode offline || echo "worker-comfyui - Could not set ComfyUI-Manager network_mode" >&2

echo "worker-comfyui: Starting ComfyUI"

# Allow operators to tweak verbosity; default is DEBUG.
: "${COMFY_LOG_LEVEL:=DEBUG}"

# PID file used by the handler to detect if ComfyUI is still running
COMFY_PID_FILE="/tmp/comfyui.pid"

# Serve the API and don't shutdown the container
if [ "$SERVE_API_LOCALLY" == "true" ]; then
    python -u /comfyui/main.py --cpu --disable-auto-launch --disable-metadata --listen --verbose "${COMFY_LOG_LEVEL}" --log-stdout &
    echo $! > "$COMFY_PID_FILE"

    echo "worker-comfyui: Starting RunPod Handler"
    python -u /handler.py --rp_serve_api --rp_api_host=0.0.0.0
else
    python -u /comfyui/main.py --cpu --disable-auto-launch --disable-metadata --verbose "${COMFY_LOG_LEVEL}" --log-stdout &
    echo $! > "$COMFY_PID_FILE"

    echo "worker-comfyui: Starting RunPod Handler"
    python -u /handler.py
fi