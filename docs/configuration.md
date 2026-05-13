# Configuration

This document outlines the environment variables available for configuring the `worker-comfyui`.

## General Configuration

| Environment Variable | Description                                                                                                                                                                                                                  | Default |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| `REFRESH_WORKER`     | When `true`, the worker pod will stop after each completed job to ensure a clean state for the next job. See the [RunPod documentation](https://docs.runpod.io/docs/handler-additional-controls#refresh-worker) for details. | `false` |
| `SERVE_API_LOCALLY`  | When `true`, enables a local HTTP server simulating the RunPod environment for development and testing. See the [Development Guide](development.md#local-api) for more details.                                              | `false` |
| `COMFY_ORG_API_KEY`  | Comfy.org API key to enable ComfyUI API Nodes. If set, it is sent with each workflow; clients can override per request via `input.api_key_comfy_org`.                                                                        | –       |
| `FAL_KEY`            | fal.ai API key used by the `ComfyUI-fal-API` custom node. On container start, the worker writes this value to the node's `config.ini` (`[API]` / `FAL_KEY`) and also exports it as an environment variable.                | –       |
| `FAL_API_KEY`        | Alias for `FAL_KEY`. Use this only if `FAL_KEY` is not set.                                                                                                                             | –       |

## Logging Configuration

| Environment Variable   | Description                                                                                                                                                      | Default |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| `COMFY_LOG_LEVEL`      | Controls ComfyUI's internal logging verbosity. Options: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`. Use `DEBUG` for troubleshooting, `INFO` for production. | `DEBUG` |
| `NETWORK_VOLUME_DEBUG` | Enable detailed network volume diagnostics in worker logs. Useful for debugging model path issues. See [Network Volumes & Model Paths](network-volumes.md).      | `false` |

## Debugging Configuration

| Environment Variable           | Description                                                                                                            | Default |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------- | ------- |
| `WEBSOCKET_RECONNECT_ATTEMPTS` | Number of websocket reconnection attempts when connection drops during job execution.                                  | `5`     |
| `WEBSOCKET_RECONNECT_DELAY_S`  | Delay in seconds between websocket reconnection attempts.                                                              | `3`     |
| `WEBSOCKET_TRACE`              | Enable low-level websocket frame tracing for protocol debugging. Set to `true` only when diagnosing connection issues. | `false` |

## AWS S3 Upload Configuration

Configure these variables **only** if you want the worker to upload generated images/videos directly to an S3-compatible bucket (AWS S3, Cloudflare R2, or other S3-compatible providers). If these are not set, images/videos will be returned as base64-encoded strings in the API response.

- **Prerequisites:**
  - An AWS S3 bucket in your desired region.
  - An AWS IAM user with programmatic access (Access Key ID and Secret Access Key).
  - Permissions attached to the IAM user allowing `s3:PutObject` (and potentially `s3:PutObjectAcl` if you need specific ACLs) on the target bucket.

| Environment Variable       | Description                                                                                                                             | Example                                                    |
| -------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| `BUCKET_ENDPOINT_URL`      | The full endpoint URL of your S3 bucket. **Must be set to enable S3 upload.**                                                           | `https://<your-bucket-name>.s3.<aws-region>.amazonaws.com` |
| `BUCKET_ACCESS_KEY_ID`     | Your AWS access key ID associated with the IAM user that has write permissions to the bucket. Required if `BUCKET_ENDPOINT_URL` is set. | `AKIAIOSFODNN7EXAMPLE`                                     |
| `BUCKET_SECRET_ACCESS_KEY` | Your AWS secret access key associated with the IAM user. Required if `BUCKET_ENDPOINT_URL` is set.                                      | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`                 |
| `BUCKET_NAME`              | The bucket name to upload to (for S3-compatible endpoints). Required when `BUCKET_ENDPOINT_URL` is set.                                | `my-bucket`                                                |

**Note:** Upload uses the `runpod` Python library helper `rp_upload.upload_image`, which handles creating a unique path within the bucket based on the `job_id`.

When using Cloudflare R2 (or other S3-compatible storage), set `BUCKET_ENDPOINT_URL` to your provider's endpoint (for R2: `https://<accountid>.r2.cloudflarestorage.com`) and set `BUCKET_NAME` to your R2 bucket.

If you want to control the final filename used when uploading (for example to use the pattern `<userID><reqID>.<ext>`), include `output_filename` and/or `user_id` in the job `input` JSON. Examples:

- `output_filename`: A string; may include placeholders `{user_id}` and `{req_id}` which will be replaced with the provided `user_id` and the worker `job.id` respectively. If the template does not include a file extension, the worker will append the detected file extension.
- `user_id`: A short identifier supplied by the client which can be used in `output_filename` or as part of the generated filename when `output_filename` is not provided.

Examples:

- `"output_filename": "{user_id}{req_id}.png"` → results in `alice12345abcd.png` if `user_id` is `alice` and `job.id` is `12345abcd`.
- `"user_id": "alice"` plus no `output_filename` → results in a filename like `alice12345abcd.png`.


### Example S3 Response

If the S3 environment variables (`BUCKET_ENDPOINT_URL`, `BUCKET_ACCESS_KEY_ID`, `BUCKET_SECRET_ACCESS_KEY`) are correctly configured, a successful job response will look similar to this:

```json
{
  "id": "sync-uuid-string",
  "status": "COMPLETED",
  "output": {
    "images": [
      {
        "filename": "ComfyUI_00001_.png",
        "type": "s3_url",
        "data": "https://your-bucket-name.s3.your-region.amazonaws.com/sync-uuid-string/ComfyUI_00001_.png"
      }
      // Additional images generated by the workflow would appear here
    ]
    // The "errors" key might be present here if non-fatal issues occurred
  },
  "delayTime": 123,
  "executionTime": 4567
}
```

The `data` field contains the presigned URL to the uploaded image file in your S3 bucket. The path usually includes the job ID.
