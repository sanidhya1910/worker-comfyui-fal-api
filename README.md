# worker-comfyui

> [ComfyUI](https://github.com/comfyanonymous/ComfyUI) as a serverless API on [RunPod](https://www.runpod.io/)

<p align="center">
  <img src="assets/worker_sitting_in_comfy_chair.jpg" title="Worker sitting in comfy chair" />
</p>

[![RunPod](https://api.runpod.io/badge/runpod-workers/worker-comfyui)](https://www.runpod.io/console/hub/runpod-workers/worker-comfyui)

---

This project allows you to run ComfyUI workflows as a serverless API endpoint on the RunPod platform. Submit custom ComfyUI API-format workflows via API calls and receive generated images/videos as base64 strings or S3-compatible bucket URLs (AWS S3, Cloudflare R2, etc.).

## Table of Contents

- [Quickstart](#quickstart)
- [Docker Image](#docker-image)
- [API Specification](#api-specification)
- [Usage](#usage)
- [Environment Variables](#environment-variables)
- [Getting the Workflow JSON](#getting-the-workflow-json)
- [Further Documentation](#further-documentation)

---

## Quickstart

1.  🐳 Deploy the [CPU-only ComfyUI worker image](#docker-image) to your RunPod endpoint.
2.  📄 Follow the [Deployment Guide](docs/deployment.md) to set up your RunPod template and endpoint.
3.  ⚙️ Optionally configure the worker (e.g., for bucket uploads, FAL API, custom nodes) using [environment variables](#environment-variables).
4.  🧪 Pick an example workflow from [`test_resources/workflows/`](./test_resources/workflows/) or [create your own](#getting-the-workflow-json).
5.  🚀 Follow the [Usage](#usage) steps below to interact with your deployed endpoint.

## Docker Image

This project provides a **CPU-only** ComfyUI worker image. No GPU or CUDA is required.

- **`worker-comfyui:latest`**: CPU-only ComfyUI with no pre-downloaded models. Models must be provided via network volume or downloaded at runtime via custom nodes.

For details on customizing or building your own image, see the [Customization Guide](docs/customization.md).

## API Specification

The worker exposes standard RunPod serverless endpoints (`/run`, `/runsync`, `/health`). By default, images/videos are returned as base64 strings. You can configure the worker to upload outputs to an S3-compatible bucket (AWS S3, Cloudflare R2, etc.) and manage other behaviors via environment variables (see [Environment Variables](#environment-variables) below or the full [Configuration Guide](docs/configuration.md)).

Use the `/runsync` endpoint for synchronous requests that wait for the job to complete and return the result directly. Use the `/run` endpoint for asynchronous requests that return immediately with a job ID; you'll need to poll the `/status` endpoint separately to get the result.

### Input

```json
{
  "input": {
    "user_id": "alice",
    "workflow": {
      "6": {
        "inputs": {
          "text": "a ball on the table",
          "clip": ["30", 1]
        },
        "class_type": "CLIPTextEncode",
        "_meta": {
          "title": "CLIP Text Encode (Positive Prompt)"
        }
      }
    },
    "images": [
      {
        "name": "input_image_1.png",
        "image": "data:image/png;base64,iVBOR..."
      }
    ],
    "videos": [
      {
        "name": "input_video_1.mp4",
        "video": "data:video/mp4;base64,AAAA..."
      }
    ]
  }
}
```

The following tables describe the fields within the `input` object:

| Field Path                | Type   | Required | Description                                                                                                                                |
| ------------------------- | ------ | -------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `input`                   | Object | Yes      | Top-level object containing request data.                                                                                                  |
| `input.user_id`           | String | Yes      | Unique identifier for the user submitting the job. Used for organizing outputs in the bucket as `users/{user_id}/jobs/{job_id}/...`.      |
| `input.workflow`          | Object | Yes      | The ComfyUI workflow exported in the [required format](#getting-the-workflow-json).                                                        |
| `input.images`            | Array  | No       | Optional array of input images. Each image is uploaded to ComfyUI and can be referenced by its `name` in the workflow.                     |
| `input.videos`            | Array  | No       | Optional array of input videos. Each video is placed into ComfyUI's input directory and can be referenced by its `name` in the workflow.    |
| `input.comfy_org_api_key` | String | No       | Optional per-request Comfy.org API key for API Nodes. Overrides the `COMFY_ORG_API_KEY` environment variable if both are set.               |

#### `input.images` Object

Each object within the `input.images` array must contain:

| Field Name | Type   | Required | Description                                                                                                                       |
| ---------- | ------ | -------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `name`     | String | Yes      | Filename used to reference the image in the workflow (e.g., via a "Load Image" node). Must be unique within the array.             |
| `image`    | String | Yes      | Base64 encoded string of the image. A data URI prefix (e.g., `data:image/png;base64,`) is optional and will be handled correctly.  |

#### `input.videos` Object

Each object within the `input.videos` array must contain:

| Field Name | Type   | Required | Description                                                                                                                      |
| ---------- | ------ | -------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `name`     | String | Yes      | Filename used to reference the video in the workflow (e.g., via a "Load Video" node). Must be unique within the array.       |
| `video`    | String | Yes      | Base64 encoded string of the video. A data URI prefix (e.g., `data:video/mp4;base64,`) is optional and will be handled correctly. |

> [!NOTE]
>
> **Size Limits:** RunPod endpoints have request size limits (e.g., 10MB for `/run`, 20MB for `/runsync`). Large base64 input images can exceed these limits. See [RunPod Docs](https://docs.runpod.io/docs/serverless-endpoint-urls).

## Environment Variables

Configure the worker behavior using environment variables. For comprehensive details, see the [Configuration Guide](docs/configuration.md).

### General Configuration

| Variable | Description | Default |
| -------- | ----------- | ------- |
| `REFRESH_WORKER` | When `true`, worker stops after each job for a clean state. See [RunPod docs](https://docs.runpod.io/docs/handler-additional-controls#refresh-worker). | `false` |
| `SERVE_API_LOCALLY` | When `true`, enables local HTTP server simulating RunPod environment for development/testing. | `false` |
| `COMFY_ORG_API_KEY` | Comfy.org API key for ComfyUI API Nodes. Clients can override per-request via `input.comfy_org_api_key`. | – |

### FAL API Integration

| Variable | Description | Default |
| -------- | ----------- | ------- |
| `FAL_KEY` | fal.ai API key for `ComfyUI-fal-API` custom node. Auto-writes to node config on container start. | – |
| `FAL_API_KEY` | Alias for `FAL_KEY` (use only if `FAL_KEY` not set). | – |

### Bucket Upload (S3-Compatible)

Enable direct upload of generated outputs to AWS S3, Cloudflare R2, or other S3-compatible storage.

| Variable | Description | Example |
| -------- | ----------- | ------- |
| `BUCKET_ENDPOINT_URL` | S3-compatible endpoint URL. **Must be set to enable uploads.** | `https://<accountid>.r2.cloudflarestorage.com` (R2) or `https://s3.<region>.amazonaws.com` (AWS) |
| `BUCKET_NAME` | Bucket name to upload to. Required if `BUCKET_ENDPOINT_URL` is set. | `my-bucket` |
| `BUCKET_ACCESS_KEY_ID` | Access key ID for bucket. Required if `BUCKET_ENDPOINT_URL` is set. | `AKIAIOSFODNN7EXAMPLE` |
| `BUCKET_SECRET_ACCESS_KEY` | Secret access key for bucket. Required if `BUCKET_ENDPOINT_URL` is set. | `wJalrXUtnFEMI/K7MDENG/...` |

**Output Structure:** Files are stored as `users/{user_id}/jobs/{job_id}/output_{n}.{ext}` where `{n}` is a sequential counter. See [Configuration Guide](docs/configuration.md#output-file-structure) for details.

### Logging & Debugging

| Variable | Description | Default |
| -------- | ----------- | ------- |
| `COMFY_LOG_LEVEL` | ComfyUI logging level: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`. | `DEBUG` |
| `NETWORK_VOLUME_DEBUG` | Enable detailed network volume diagnostics. Useful for debugging model paths. | `false` |
| `WEBSOCKET_RECONNECT_ATTEMPTS` | WebSocket reconnection attempts if connection drops. | `5` |
| `WEBSOCKET_RECONNECT_DELAY_S` | Delay (seconds) between reconnection attempts. | `3` |
| `WEBSOCKET_TRACE` | Enable low-level WebSocket frame tracing (protocol debugging only). | `false` |

### Output

> [!WARNING]
>
> **Breaking Change in Output Format (5.0.0+)**
>
> Versions `< 5.0.0` returned the primary image data (S3 URL or base64 string) directly within an `output.message` field.
> Starting with `5.0.0`, the output format has changed significantly, see below

```json
{
  "id": "sync-uuid-string",
  "status": "COMPLETED",
  "output": {
    "images": [
      {
        "filename": "ComfyUI_00001_.png",
        "type": "base64",
        "data": "iVBORw0KGgoAAAANSUhEUg..."
      }
    ],
    "videos": [
      {
        "filename": "ComfyUI_00001_.mp4",
        "type": "base64",
        "data": "AAAAIGZ0eXBpc29t..."
      }
    ]
  },
  "delayTime": 123,
  "executionTime": 4567
}
```

| Field Path      | Type             | Required | Description                                                                                                 |
| --------------- | ---------------- | -------- | ----------------------------------------------------------------------------------------------------------- |
| `output`        | Object           | Yes      | Top-level object containing the results of the job execution.                                                |
| `output.images` | Array of Objects | No       | Present if the workflow generated images. Contains a list of objects, each representing one output image.    |
| `output.videos` | Array of Objects | No       | Present if the workflow generated videos. Contains a list of objects, each representing one output video.    |
| `output.errors` | Array of Strings | No       | Present if non-fatal errors or warnings occurred during processing (e.g., S3 upload failure, missing data).  |

#### `output.images`

Each object in the `output.images` array has the following structure:

| Field Name | Type   | Description                                                                                     |
| ---------- | ------ | ----------------------------------------------------------------------------------------------- |
| `filename` | String | The original filename assigned by ComfyUI during generation.                                    |
| `type`     | String | Indicates the format of the data. Either `"base64"` or `"s3_url"` (if bucket upload is configured). |
| `data`     | String | Contains either the base64 encoded image string or the bucket URL for the uploaded image file.      |

> [!NOTE]
> The `output.images` field provides a list of all generated images (excluding temporary ones).
>
> - If bucket upload is **not** configured (default), `type` will be `"base64"` and `data` will contain the base64 encoded image string.
> - If bucket upload **is** configured (S3, Cloudflare R2, etc.), `type` will be `"s3_url"` and `data` will contain the bucket URL. Files are stored at `users/{user_id}/jobs/{job_id}/output_{n}.{ext}`. See the [Configuration Guide](docs/configuration.md#output-file-structure) for details.

## Usage

To interact with your deployed RunPod endpoint:

1.  **Get API Key:** Generate a key in RunPod [User Settings](https://www.runpod.io/console/serverless/user/settings) (`API Keys` section).
2.  **Get Endpoint ID:** Find your endpoint ID on the [Serverless Endpoints](https://www.runpod.io/console/serverless/user/endpoints) page or on the `Overview` page of your endpoint.

### Generate Image (Sync Example)

Send a workflow to the `/runsync` endpoint (waits for completion). Replace `<api_key>` and `<endpoint_id>`. The `-d` value should contain the [JSON input described above](#input).

```bash
curl -X POST \
  -H "Authorization: Bearer <api_key>" \
  -H "Content-Type: application/json" \
  -d '{"input":{"user_id":"alice","workflow":{... your workflow JSON ...}}}' \
  https://api.runpod.ai/v2/<endpoint_id>/runsync
```

You can also use the `/run` endpoint for asynchronous jobs and then poll the `/status` to see when the job is done. Or you [add a `webhook` into your request](https://docs.runpod.io/serverless/endpoints/send-requests#webhook-notifications) to be notified when the job is done.

Refer to [`test_input.json`](./test_input.json) for a complete input example.

## Getting the Workflow JSON

To get the correct `workflow` JSON for the API:

1.  Open ComfyUI in your browser.
2.  In the top navigation, select `Workflow > Export (API)`
3.  A `workflow.json` file will be downloaded. Use the content of this file as the value for the `input.workflow` field in your API requests.

## SSH Access

To enable SSH access to the worker, set the `PUBLIC_KEY` environment variable to your SSH public key. The worker will start an SSH server automatically. Make sure to expose **port 22** in your RunPod template so you can connect.

## Further Documentation

- **[Deployment Guide](docs/deployment.md):** Detailed steps for deploying on RunPod.
- **[Configuration Guide](docs/configuration.md):** Full list of environment variables (including S3 setup).
- **[Customization Guide](docs/customization.md):** Adding custom models and nodes (Network Volumes, Docker builds).
- **[Development Guide](docs/development.md):** Setting up a local environment for development & testing
- **[CI/CD Guide](docs/ci-cd.md):** Information about the automated Docker build and publish workflows.
- **[Acknowledgments](docs/acknowledgments.md):** Credits and thanks
