#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

echo "worker-comfyui: Starting ComfyUI"

# Allow operators to tweak verbosity; default is DEBUG.
: "${COMFY_LOG_LEVEL:=DEBUG}"

# Serve the API and don't shutdown the container
if [ "$SERVE_API_LOCALLY" == "true" ]; then
    python -u /comfyui/main.py --disable-auto-launch --disable-metadata --listen --verbose "${COMFY_LOG_LEVEL}" --log-stdout &

    # Start Jupyter Lab only if token is provided
    if [ -n "$JUPYTER_TOKEN" ]; then
        echo "worker-comfyui: Starting Jupyter Lab"
        echo "worker-comfyui: Jupyter Lab will be available at http://localhost:8888 with token: $JUPYTER_TOKEN"
        jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token="$JUPYTER_TOKEN" --notebook-dir=/ &
    else
        echo "runpod-worker-comfy: Jupyter Lab not started (JUPYTER_TOKEN not provided)"
    fi

    echo "worker-comfyui: Starting RunPod Handler"
    python -u /handler.py --rp_serve_api --rp_api_host=0.0.0.0

else
    # Ensure ComfyUI-Manager runs in offline network mode inside the container
    comfy-manager-set-mode offline || echo "worker-comfyui - Could not set ComfyUI-Manager network_mode" >&2

    echo "worker-comfyui: Starting ComfyUI"
    python -u /comfyui/main.py --disable-auto-launch --disable-metadata --verbose "${COMFY_LOG_LEVEL}" --log-stdout &

    echo "worker-comfyui: Starting RunPod Handler"
    python -u /handler.py
fi