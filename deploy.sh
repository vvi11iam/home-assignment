#!/usr/bin/env bash
set -euo pipefail

log() {
  printf "[deploy] %s\n" "$1"
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${ROOT_DIR}/config.yaml}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Missing required command: $1"
    exit 1
  fi
}

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

ensure_namespace() {
  local namespace="$1"

  if kubectl get namespace "$namespace" >/dev/null 2>&1; then
    log "Namespace ${namespace} already exists."
    return
  fi

  log "Creating namespace ${namespace}..."
  kubectl create namespace "$namespace" >/dev/null
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

start_minikube() {
  require_cmd minikube
  local k8s_version
  k8s_version="${K8S_VERSION:-1.35.0}"
  log "Starting minikube with Kubernetes v${k8s_version}..."
  minikube start --kubernetes-version="v${k8s_version}"
}

deploy_docker_compose() {
  local compose_cmd
  compose_cmd="$(resolve_docker_compose)"

  log "Deploying with docker-compose..."
  ${compose_cmd} up -d --build

  log "Deploy complete."
  log "Open http://localhost:3000"
}

deploy_minikube() {
  local hostname hosts_file os driver host_ip ingress_url ingress_port
  local db_namespace app_namespace

  require_cmd helm
  require_cmd kubectl

  start_minikube

  log "Enabling ingress addon..."
  minikube addons enable ingress >/dev/null

  hostname="kickstarter.local"
  hosts_file="/etc/hosts"
  db_namespace="db"
  app_namespace="app"
  os="$(uname -s)"
  driver="$(
    minikube profile list -o json 2>/dev/null \
      | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("valid","")[0].get("Config",{}).get("Driver",""))' \
      2>/dev/null || true
  )"
  host_ip="127.0.0.1"

  if [[ "$os" != "Darwin" || "$driver" != "docker" ]]; then
    host_ip="$(minikube ip)"
  fi

  log "Configuring hosts entry for ${hostname}..."
  if grep -qE "[[:space:]]${hostname}(\\s|$)" "$hosts_file"; then
    log "${hostname} already present in ${hosts_file}. Updating to ${host_ip} if needed."
    tmp_hosts="$(mktemp)"
    awk -v host="$hostname" -v ip="$host_ip" '{
      if ($0 ~ ("[[:space:]]" host "([[:space:]]|$)")) {
        print ip "\t" host
      } else {
        print $0
      }
    }' "$hosts_file" > "$tmp_hosts"
    sudo tee "$hosts_file" >/dev/null < "$tmp_hosts"
    rm -f "$tmp_hosts"
  else
    log "Adding ${hostname} -> ${host_ip} to ${hosts_file} (sudo required)..."
    printf "%s\t%s\n" "$host_ip" "$hostname" | sudo tee -a "$hosts_file" >/dev/null
  fi

  log "Adding/updating Bitnami repo..."
  helm repo add bitnami https://charts.bitnami.com/bitnami --force-update >/dev/null
  helm repo update >/dev/null

  ensure_namespace "$db_namespace"
  ensure_namespace "$app_namespace"

  log "Installing/upgrading MongoDB..."
  helm upgrade --install mongodb bitnami/mongodb --namespace "$db_namespace" --set auth.enabled=false

  log "Installing/upgrading backend..."
  helm upgrade --install backend k8s/helm --namespace "$app_namespace" -f k8s/values-backend.yaml

  log "Installing/upgrading frontend..."
  helm upgrade --install frontend k8s/helm --namespace "$app_namespace" -f k8s/values-frontend.yaml

  log "Waiting for frontend to be ready..."
  kubectl wait --for=condition=available deployment \
    -l app.kubernetes.io/instance=frontend \
    --namespace "$app_namespace" \
    --timeout=180s

  log "Deploy complete."
  log "Discovering ingress URL..."
  if [[ "$os" == "Darwin" ]]; then
    log "On macOS, run this in a separate terminal:"
    printf "minikube service ingress-nginx-controller -n ingress-nginx --url\n"
    log "Then open http://${hostname}:<port-shown>"
  else
    ingress_url="$(minikube service ingress-nginx-controller -n ingress-nginx --url | head -n 1 || true)"
    if [[ -n "$ingress_url" ]]; then
      ingress_port="${ingress_url##*:}"
      log "Open http://${hostname}:${ingress_port}"
    else
      log "Unable to determine ingress URL."
      log "To access the frontend via port-forward, run:"
      printf "kubectl port-forward svc/frontend 3000:3000\n"
      log "Then open http://localhost:3000"
    fi
  fi
}

select_target() {
  printf "Select deployment target:\n"
  printf "1. docker-compose|compose\n"
  printf "2. minikube|k8s\n"
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
    deploy_docker_compose
    ;;
  minikube)
    deploy_minikube
    ;;
  *)
    log "Unsupported deployment target: $target"
    exit 1
    ;;
esac
