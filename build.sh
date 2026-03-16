#!/usr/bin/env bash
set -euo pipefail

log() {
  printf "[build] %s\n" "$1"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Missing required command: $1"
    exit 1
  fi
}

require_cmd docker

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${ROOT_DIR}/config.yaml}"

load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*:[[:space:]]*(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        val="${BASH_REMATCH[2]}"
        val="${val%\"}"; val="${val#\"}"
        val="${val%\'}"; val="${val#\'}"
        export "$key"="$val"
      fi
    done < "$CONFIG_FILE"
  fi
}

load_config

DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-}"
TAG="latest"
DOCKERHUB_TOKEN="${DOCKERHUB_TOKEN:-}"

if [[ -z "$DOCKERHUB_USERNAME" ]]; then
  log "Set DOCKERHUB_USERNAME to your Docker Hub username."
  exit 1
fi
log "Logging in to Docker Hub..."
if [[ -n "$DOCKERHUB_TOKEN" ]]; then
  printf "%s" "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
else
  log "DOCKERHUB_TOKEN not set, falling back to interactive login."
  docker login -u "$DOCKERHUB_USERNAME"
fi

SERVICES=(
  "hackathon-starter-backend"
  "hackathon-starter-frontend"
)

for svc in "${SERVICES[@]}"; do
  svc_dir="${ROOT_DIR}/services/${svc}"
  image="${DOCKERHUB_USERNAME}/${svc}:${TAG}"

  if [[ ! -d "$svc_dir" ]]; then
    log "Service directory not found: ${svc_dir}"
    exit 1
  fi

  log "Building ${image} from ${svc_dir}"
  docker build -t "$image" "$svc_dir"

  log "Pushing ${image}"
  docker push "$image"
done

log "Done."
