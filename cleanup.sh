#!/usr/bin/env bash
set -euo pipefail

log() {
  printf "[cleanup] %s\n" "$1"
}

resolve_docker_compose() {
  if docker compose version >/dev/null 2>&1; then
    echo "docker compose"
    return
  fi
  if command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
    return
  fi
  log "Missing required command: docker compose or docker-compose"
  exit 1
}

cleanup_docker_compose() {
  local compose_cmd
  compose_cmd="$(resolve_docker_compose)"

  log "Stopping docker-compose services..."
  ${compose_cmd} down --remove-orphans

  log "Cleanup complete."
}

cleanup_minikube() {
  if ! command -v minikube >/dev/null 2>&1; then
    log "minikube not found; nothing to clean."
    exit 0
  fi

  log "Stopping minikube..."
  minikube stop || true

  log "Deleting minikube cluster..."
  minikube delete || true

  log "Cleanup complete."
}

select_target() {
  printf "Select cleanup target:\n"
  printf "1. docker-compose\n"
  printf "2. minikube\n"
  printf "> "
  read -r choice

  case "$choice" in
    1|docker-compose|compose)
      target="docker-compose"
      ;;
    2|minikube|k8s)
      target="minikube"
      ;;
    *)
      log "Invalid selection: $choice"
      exit 1
      ;;
  esac
}

target=""
select_target

case "$target" in
  docker-compose)
    cleanup_docker_compose
    ;;
  minikube)
    cleanup_minikube
    ;;
  *)
    log "Unsupported cleanup target: $target"
    exit 1
    ;;
esac
