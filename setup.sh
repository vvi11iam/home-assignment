#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${ROOT_DIR}/config.yaml}"

OS="$(uname -s)"
ARCH="$(uname -m)"

log() {
  printf "[setup] %s\n" "$1"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    return 1
  fi
}

ensure_sudo() {
  if ! command -v sudo >/dev/null 2>&1; then
    log "sudo is required but not found."
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

linux_arch() {
  case "$ARCH" in
    x86_64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *)
      log "Unsupported architecture: $ARCH"
      exit 1
      ;;
  esac
}

install_docker_macos() {
  if require_cmd docker; then
    log "Docker already installed."
    return
  fi
  if ! require_cmd brew; then
    log "Homebrew not found. Install it first: https://brew.sh/"
    exit 1
  fi
  log "Installing Docker Desktop (macOS)..."
  brew install --cask docker
  log "Docker Desktop installed. Open the Docker app to finish setup."
}

install_docker_linux() {
  if require_cmd docker; then
    log "Docker already installed."
    return
  fi
  ensure_sudo
  log "Installing Docker Engine (Linux)..."
  curl -fsSL https://get.docker.com | sudo sh
  if command -v usermod >/dev/null 2>&1; then
    sudo usermod -aG docker "$USER" || true
  fi
  log "Docker installed. You may need to log out/in to use it without sudo."
}

install_minikube_linux() {
  if require_cmd minikube; then
    log "minikube already installed."
    return
  fi
  ensure_sudo
  local arch
  arch="$(linux_arch)"
  log "Installing minikube (Linux)..."
  curl -LO "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${arch}"
  sudo install minikube-linux-${arch} /usr/local/bin/minikube
  rm -f "minikube-linux-${arch}"
}

install_kubectl_linux() {
  if require_cmd kubectl; then
    log "kubectl already installed."
    return
  fi
  ensure_sudo
  local arch
  arch="$(linux_arch)"
  log "Installing kubectl (Linux)..."
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${arch}/kubectl"
  sudo install kubectl /usr/local/bin/kubectl
  rm -f kubectl
}

install_helm_linux() {
  if require_cmd helm; then
    log "helm already installed."
    return
  fi
  ensure_sudo
  log "Installing helm (Linux)..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | sudo bash
}

install_terraform_linux() {
  if require_cmd terraform; then
    log "terraform already installed."
    return
  fi
  ensure_sudo
  local arch
  arch="$(linux_arch)"
  local version
  version="${TERRAFORM_VERSION:-1.14.3}"
  log "Installing terraform ${version} (Linux)..."
  tmpdir="$(mktemp -d)"
  curl -fsSL -o "${tmpdir}/terraform.zip" \
    "https://releases.hashicorp.com/terraform/${version}/terraform_${version}_linux_${arch}.zip"
  (cd "$tmpdir" && unzip terraform.zip)
  sudo install "${tmpdir}/terraform" /usr/local/bin/terraform
  rm -rf "$tmpdir"
}

install_brew_pkg() {
  local name="$1"
  if require_cmd "$name"; then
    log "${name} already installed."
    return
  fi
  if ! require_cmd brew; then
    log "Homebrew not found. Install it first: https://brew.sh/"
    exit 1
  fi
  log "Installing ${name} (macOS)..."
  brew install "$name"
}

install_macos_tools() {
  install_docker_macos
  install_brew_pkg minikube
  install_brew_pkg kubectl
  install_brew_pkg helm
  install_brew_pkg terraform
}

install_linux_tools() {
  install_docker_linux
  install_minikube_linux
  install_kubectl_linux
  install_helm_linux
  install_terraform_linux
}

case "$OS" in
  Darwin)
    install_macos_tools
    ;;
  Linux)
    install_linux_tools
    ;;
  *)
    log "Unsupported OS: $OS"
    exit 1
    ;;
esac

log "All done."
