#!/usr/bin/env bash
# comfy-node-install: install custom ComfyUI nodes and fail with non-zero
# exit code if any of them cannot be installed.
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: comfy-node-install <node1> [<node2> …]" >&2
  exit 64  # EX_USAGE
fi

log=$(mktemp)

# run installation
set +e
comfy node install --mode=remote "$@" 2>&1 | tee "$log"
cli_status=$?
set -e

# Extract number of successfully installed nodes
installed_count=$(grep -c "\[INSTALLED\]" "$log" || true)

if [[ "$installed_count" -ne $# ]]; then
  echo "" >&2
  echo "ERROR: Expected $# nodes to be installed, but only found $installed_count successful installations." >&2
  echo "Comfy node installation failed!" >&2
  exit 1
fi

echo "✅ All $# nodes installed successfully!"
exit 0
 