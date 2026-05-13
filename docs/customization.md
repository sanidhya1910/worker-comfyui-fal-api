# Customization

This guide covers methods for extending the CPU-only `worker-comfyui` with custom nodes, models, and static input files.

> [!IMPORTANT]
>
> **Models are not included in the base image.** This is a CPU-only worker with no pre-downloaded models. You must:
> - Provide models via a **Network Volume** attached to your endpoint, or
> - Download models **at runtime** using custom nodes (e.g., `ComfyUI-fal-API` for remote model URLs)

---

There are two primary methods for customization:

1.  **Custom Dockerfile (recommended):** Create your own `Dockerfile` starting from the CPU base image. This allows you to add custom nodes and configure your environment reproducibly. **This method does not require forking the `worker-comfyui` repository.**
2.  **Network Volume:** Store models on a persistent network volume attached to your RunPod endpoint. This is useful for large models or when you frequently change models.

## Method 1: Custom Dockerfile

> [!NOTE]
>
> This method does NOT require forking the `worker-comfyui` repository.

This is the most flexible approach for creating reproducible, customized worker environments.

1.  **Create a `Dockerfile`:** In your own project directory, create a file named `Dockerfile`.
2.  **Start with a Base Image:** Begin your `Dockerfile` by referencing the CPU base image.
    ```Dockerfile
    # Start from the CPU-only base image
    FROM worker-comfyui:latest
    ```
3.  **Install Custom Nodes:** Use the `comfy-node-install` command to add custom nodes by their name or URL. See [Comfy Registry](https://registry.comfy.org) to find the correct name.
    ```Dockerfile
    # Install custom nodes (example)
    RUN comfy-node-install comfyui-kjnodes comfyui-ic-light
    ```
    
    **Pre-built custom nodes already included in the base image:**
    - `ComfyUI-fal-API`: Video/image upload via fal.ai; auto-configured from `FAL_KEY` environment variable.
    - `comfyui-art-venture`: Image loading from URLs (useful for Cloudflare R2 or remote model hosting).

4.  **Add Static Input Files (Optional):** If your workflows consistently require specific input images, masks, etc., you can copy them into the image:

   - Create an `input/` directory next to your `Dockerfile`.
   - Place your static files inside this `input/` directory.
   - Add a `COPY` command to your `Dockerfile`:

     ```Dockerfile
     # Copy local static input files into ComfyUI's input directory
     COPY input/ /comfyui/input/
     ```

   - These files can be referenced in your workflow using a "Load Image" node (e.g., `my_static_image.png`).
>
> Ensure you use the correct `--relative-path` corresponding to ComfyUI's model directory structure (starting with `models/<folder>`):
>
> checkpoints, clip, clip_vision, configs, controlnet, diffusers, embeddings, gligen, hypernetworks, loras, style_models, unet, upscale_models, vae, vae_approx, animatediff_models, animatediff_motion_lora, ipadapter, photomaker, sams, insightface, facerestore_models, facedetection, mmdets, instantid

5.  **Add Static Input Files (Optional):** If your workflows consistently require specific input images, masks, videos, etc., you can copy them directly into the image.

- Create an `input/` directory in the same folder as your `Dockerfile`.
- Place your static files inside this `input/` directory.
- Add a `COPY` command to your `Dockerfile`:

  ```Dockerfile
  # Copy local static input files into the ComfyUI input directory
  COPY input/ /comfyui/input/
  ```

- These files can then be referenced in your workflow using a "Load Image" (or similar) node pointing to the filename (e.g.,`my_static_image.png`).

Once you have created your custom `Dockerfile`, refer to the [Deployment Guide](deployment.md#deploying-custom-setups) for instructions on how to build, push, and deploy your custom image to RunPod.

### Example Custom `Dockerfile`

```Dockerfile
# Start from the CPU-only base image
FROM worker-comfyui:latest

# Install custom nodes
RUN comfy-node-install comfyui-kjnodes comfyui-ic-light

# Copy local static input files into ComfyUI's input directory
# (Optional - only if you have an 'input' folder next to your Dockerfile)
COPY input/ /comfyui/input/
```

## Method 2: Network Volume (for Models)

Since this is a **CPU-only worker with no pre-downloaded models**, the Network Volume method is the recommended way to provide models to your workflows.

1.  **Create a Network Volume**:
    - Follow the [RunPod Network Volumes guide](https://docs.runpod.io/pods/storage/create-network-volumes) to create a volume in the same region as your endpoint.

2.  **Populate the Volume with Models**:
    - Use one of the methods described in the RunPod guide (e.g., temporary Pod + `wget`, direct upload, or the S3-compatible API) to place your model files into the correct ComfyUI directory structure **within the volume**.
    - For **serverless endpoints**, the network volume is mounted at `/runpod-volume`, and ComfyUI expects models under `/runpod-volume/models/...`. See [Network Volumes & Model Paths](network-volumes.md) for the exact structure and debugging tips.
      ```bash
      # Example structure inside the Network Volume (serverless worker view):
      # /runpod-volume/models/checkpoints/your_model.safetensors
      # /runpod-volume/models/loras/your_lora.pt
      # /runpod-volume/models/vae/your_vae.safetensors
      ```
    - **Important:** Ensure models are placed in the correct subdirectories (e.g., checkpoints in `models/checkpoints`, LoRAs in `models/loras`). If models are not detected, enable `NETWORK_VOLUME_DEBUG=true` as described in [Network Volumes & Model Paths](network-volumes.md) and the [README Environment Variables](../README.md#logging--debugging).

3.  **Configure Your Endpoint**:
    - Use the Network Volume in your endpoint configuration:
      - When creating or updating your endpoint (see [Deployment Guide](deployment.md)), under `Advanced > Select Network Volume`, select your Network Volume.
      - ComfyUI will automatically detect models from the standard directories (`/runpod-volume/models/...`) within that volume.

> [!NOTE]
>
> - Network Volume is the ideal method for managing large models separately from your worker image. This avoids rebuilding the Docker image whenever you update models.
> - For directory mapping details and troubleshooting, see [Network Volumes & Model Paths](network-volumes.md).
