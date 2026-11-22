#!/usr/bin/env bash

# Stop immediately if an image is missing or the import fails.
set -euo pipefail

# Resolve the repository root so Compose reads the catalog from any working
# directory.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Use the requested kind cluster, defaulting to the cluster created by the guide.
CLUSTER="${1:-railshack}"

# Read image names from Compose instead of maintaining a second list of 52 tags.
IMAGE_LIST="$(docker compose config --images)"
if [ -z "$IMAGE_LIST" ]; then
  echo "No images found in the Compose configuration" >&2
  exit 1
fi

# Keep the image names as an array so docker save receives one argument per image.
mapfile -t IMAGES <<< "$IMAGE_LIST"

# Export only the host platform; multi-platform indexes caused missing-digest
# errors during kind import.
PLATFORM="$(docker image inspect "${IMAGES[0]}" --format '{{.Os}}/{{.Architecture}}')"

# Kind nodes use containerd, separate from Docker's image store. Save an archive
# and load it into the node so Kubernetes can start these local images.
ARCHIVE="$(mktemp)"
# Remove the potentially large archive on both success and failure.
trap 'rm -f "$ARCHIVE"' EXIT

echo "Saving ${#IMAGES[@]} images for $PLATFORM..."
docker image save --platform "$PLATFORM" --output "$ARCHIVE" "${IMAGES[@]}"
kind load image-archive "$ARCHIVE" --name "$CLUSTER"
