#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "This script must run as root (or via sudo)." >&2
    exit 1
  fi
}

check_cmd() {
  command -v "$1" >/dev/null 2>&1
}

detect_pkg_mgr() {
  if check_cmd apt-get; then echo apt; return; fi
  if check_cmd dnf; then echo dnf; return; fi
  if check_cmd yum; then echo yum; return; fi
  if check_cmd pacman; then echo pacman; return; fi
  echo unknown
}

install_prereqs() {
  local mgr
  mgr=$(detect_pkg_mgr)
  case "$mgr" in
    apt)
      apt-get update -y
      apt-get install -y curl ca-certificates snapd jq
      ;;
    dnf)
      dnf install -y curl ca-certificates snapd jq
      systemctl enable --now snapd.socket || true
      ln -sf /var/lib/snapd/snap /snap || true
      ;;
    yum)
      yum install -y curl ca-certificates snapd jq
      systemctl enable --now snapd.socket || true
      ln -sf /var/lib/snapd/snap /snap || true
      ;;
    pacman)
      pacman -Sy --noconfirm curl ca-certificates snapd jq
      systemctl enable --now snapd.socket || true
      ln -sf /var/lib/snapd/snap /snap || true
      ;;
    *)
      echo "Warning: Unknown package manager. Ensure curl, jq, and snapd are installed." >&2
      ;;
  esac
}

install_runtime() {
  # Docker
  if ! check_cmd docker; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
  fi
  # docker compose plugin
  if ! docker compose version >/dev/null 2>&1; then
    echo "Installing Docker Compose plugin (via Docker convenience script)..."
    # Usually installed with docker; fallback to apt if needed
    if check_cmd apt-get; then apt-get install -y docker-compose-plugin || true; fi
  fi

  # sing-box (beta as used in compose)
  if ! check_cmd sing-box; then
    echo "Installing sing-box..."
    curl -fsSL https://sing-box.app/install.sh | sh -s -- --beta
  fi

  # certbot via snap
  if ! check_cmd certbot; then
    echo "Installing certbot (snap)..."
    snap install core || true
    snap refresh core || true
    snap install --classic certbot || true
    ln -sf /snap/bin/certbot /usr/bin/certbot || true
  fi

  # enable TUN if needed
  if [[ -e /dev/net/tun ]]; then
    echo "/dev/net/tun found."
  else
    echo "Creating /dev/net/tun..."
    mkdir -p /dev/net
    mknod /dev/net/tun c 10 200 || true
    chmod 0666 /dev/net/tun || true
  fi
}

prepare_dirs() {
  mkdir -p "$SCRIPT_DIR/config" "$SCRIPT_DIR/cert" "$SCRIPT_DIR/logs"
}

generate_env_and_configs() {
  echo "Generating .env (you will be prompted)..."
  sudo -u "${SUDO_USER:-$(whoami)}" bash -c "'$SCRIPT_DIR/gen_env.sh'"

  echo "Obtaining TLS certificate (standalone certbot)..."
  bash "$SCRIPT_DIR/get_cert.sh"

  # Copy certs to project ./cert expected by compose
  local DOMAIN
  DOMAIN=$(grep '^SERVER_NAME=' .env | cut -d= -f2)
  if [[ -n "$DOMAIN" && -d "/etc/letsencrypt/live/$DOMAIN" ]]; then
    cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$SCRIPT_DIR/cert/fullchain.pem"
    cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$SCRIPT_DIR/cert/privkey.pem"
    echo "Copied certs to ./cert"
  else
    echo "Warning: Couldn't find /etc/letsencrypt/live/$DOMAIN; ensure certs exist." >&2
  fi

  echo "Generating sing-box and Snell configs..."
  bash "$SCRIPT_DIR/gen_conf.sh"
}

bring_up_services() {
  echo "Starting services with Docker Compose..."
  docker compose pull || true
  docker compose build subscription || true
  docker compose up -d sing-box subscription snell netbird
}

print_summary() {
  local SERVER_NAME SUBSCRIPTION_TOKEN
  SERVER_NAME=$(grep '^SERVER_NAME=' .env | cut -d= -f2)
  SUBSCRIPTION_TOKEN=$(grep '^SUBSCRIPTION_TOKEN=' .env | cut -d= -f2)
  echo ""
  echo "Setup complete. Key info:"
  if [[ -n "${SUBSCRIPTION_TOKEN:-}" ]]; then
    echo "- Subscription URL: https://$SERVER_NAME/subscribe?token=$SUBSCRIPTION_TOKEN"
  else
    echo "- Subscription URL: https://$SERVER_NAME/subscribe"
  fi
  echo "- Configs: $SCRIPT_DIR/config/config.json, $SCRIPT_DIR/snell.conf"
  echo "- Certs mounted from: $SCRIPT_DIR/cert"
}

main() {
  require_root
  prepare_dirs
  install_prereqs
  install_runtime
  generate_env_and_configs
  bring_up_services
  print_summary
}

main "$@"


